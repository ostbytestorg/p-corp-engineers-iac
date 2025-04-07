#!/bin/bash
# Script to set up ArgoCD repository connection with GitHub App using ServiceAccount

set -e  # Exit on any error

echo "Step 1: Create a Kubernetes ServiceAccount in the ArgoCD namespace"
kubectl create serviceaccount argocd-automation -n argocd

echo "Step 2: Create required RBAC for the ServiceAccount"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-repo-admin
rules:
- apiGroups: ["argoproj.io"]
  resources: ["repositories"]
  verbs: ["get", "create", "update", "delete", "list"]
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-automation-repo-admin
subjects:
- kind: ServiceAccount
  name: argocd-automation
  namespace: argocd
roleRef:
  kind: ClusterRole
  name: argocd-repo-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Step 3: Create a ServiceAccount token"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-automation-token
  namespace: argocd
  annotations:
    kubernetes.io/service-account.name: argocd-automation
type: kubernetes.io/service-account-token
EOF

echo "Step 4: Wait for the token to be generated"
sleep 5

echo "Step 5: Get the ServiceAccount token"
SA_TOKEN=$(kubectl get secret argocd-automation-token -n argocd -o jsonpath='{.data.token}' | base64 -d)
echo "ServiceAccount Token retrieved"
echo $SA_TOKEN > sa-token.txt
echo "Token saved to sa-token.txt"

# Variables for GitHub App
read -p "Enter the path to your GitHub App private key (.pem file): " PRIVATE_KEY_PATH
read -p "Enter your GitHub App ID: " GITHUB_APP_ID
read -p "Enter your GitHub App Installation ID: " GITHUB_INSTALLATION_ID
read -p "Enter the repository URL (e.g., https://github.com/your-org/your-repo.git): " REPO_URL

echo "Step 6: Format the private key for JSON"
FORMATTED_KEY=$(cat "$PRIVATE_KEY_PATH" | sed 's/$/\\n/' | tr -d '\n')

echo step 7: Enable ARGOCD API
cat <<EOF > /tmp/argocd-cm-api-patch.json
{
  "data": {
    "accounts.argocd-automation": "apiKey",
    "accounts.argocd-automation.enabled": "true"
  }
}
EOF
kubectl patch configmap argocd-cm -n argocd --patch-file /tmp/argocd-cm-api-patch.json
rm -f /tmp/argocd-cm-api-patch.json

echo "Step 8: Create the repository connection using the API"
curl -X POST \
  https://argocd.middagsklubben.beer/api/v1/repositories \
  -H "Authorization: Bearer $ARGOCD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "repo": "'"$REPO_URL"'",
    "type": "git",
    "name": "p-engineers-apps",
    "githubAppId": '$GITHUB_APP_ID',
    "githubAppInstallationId": '$GITHUB_INSTALLATION_ID',
    "githubAppPrivateKey": "'"$FORMATTED_KEY"'"
  }'

echo "Step 9: Verify the repository connection was created successfully"
curl -X GET \
  https://argocd.middagsklubben.beer/api/v1/repositories \
  -H "Authorization: Bearer $SA_TOKEN" | grep -A 10 "$REPO_URL"

echo "Process completed!"