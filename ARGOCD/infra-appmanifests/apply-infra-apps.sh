#!/bin/bash
set -e  # Exit on error

# Directory containing app manifests (current directory)
APPS_DIR="$(dirname "$0")"

# Count number of YAML files
YAML_COUNT=$(find "$APPS_DIR" -maxdepth 1 -name "*.yaml" -o -name "*.yml" | wc -l)
if [ "$YAML_COUNT" -eq 0 ]; then
  echo "Warning: No YAML files found in $APPS_DIR"
  exit 0
fi

echo "Found $YAML_COUNT application manifests to apply"

# Process each YAML file
for yaml_file in "$APPS_DIR"/*.y*ml; do
  # Skip processing if the file doesn't exist
  # (This can happen if there are no yaml/yml files)
  [ -e "$yaml_file" ] || continue
  
  echo "----------------------------------------"
  echo "Applying manifest: $yaml_file"
  
  # Extract app name from the file for logging
  APP_NAME=$(basename "$yaml_file" | sed 's/\.yaml$//' | sed 's/\.yml$//')
  echo "Application: $APP_NAME"
  
  # Apply the manifest
  kubectl apply -f "$yaml_file"
  
  echo "Application $APP_NAME manifest applied successfully"
done

# Update DNS if ARGOCD_SERVER_URL is set
if [ ! -z "$ARGOCD_SERVER_URL" ]; then
  echo "----------------------------------------"
  echo "Updating DNS for ArgoCD..."
  
  # Extract hostname from ARGOCD_SERVER_URL
  HOSTNAME=$(echo "$ARGOCD_SERVER_URL" | sed -e 's|^https://||' -e 's|^http://||' -e 's|/.*$||')
  DNS_RECORD_NAME=$(echo "$HOSTNAME" | cut -d'.' -f1)
  DNS_ZONE="middagsklubben.beer"
  RESOURCE_GROUP="rg-tf-dns"
  
  echo "Hostname: $HOSTNAME"
  echo "DNS Record Name: $DNS_RECORD_NAME"
  
  # Wait for and get the ingress IP address
  echo "Waiting for nginx ingress controller to have an external IP..."
  external_ip=""
  while [ -z "$external_ip" ]; do
    echo "Checking for external IP..."
    external_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$external_ip" ]; then
      echo "IP not found yet, waiting 10 seconds..."
      sleep 10
    fi
  done
  
  echo "Ingress Controller IP: $external_ip"
  
  # Check if the A record exists
  echo "Checking for existing DNS record..."
  record_exists=$(az network dns record-set a list \
    --resource-group $RESOURCE_GROUP \
    --zone-name $DNS_ZONE \
    --query "[?name=='$DNS_RECORD_NAME']" \
    --output tsv)
    
  if [ -z "$record_exists" ]; then
    echo "Creating new DNS A record for $DNS_RECORD_NAME.$DNS_ZONE..."
    az network dns record-set a add-record \
      --resource-group $RESOURCE_GROUP \
      --zone-name $DNS_ZONE \
      --record-set-name $DNS_RECORD_NAME \
      --ipv4-address "$external_ip"
  else
    echo "Updating existing DNS A record for $DNS_RECORD_NAME.$DNS_ZONE..."
    az network dns record-set a update \
      --resource-group $RESOURCE_GROUP \
      --zone-name $DNS_ZONE \
      --name $DNS_RECORD_NAME \
      --set "aRecords[0].ipv4Address=$external_ip"
  fi
  
  echo "DNS record for $HOSTNAME now points to $external_ip"
else
  echo "Skipping DNS update - ARGOCD_SERVER_URL not set"
fi

# Configure SSO if env variables are set
if [ ! -z "$ARGOCD_SERVER_URL" ] && [ ! -z "$ARGO_CLIENT_ID" ] && [ ! -z "$ARGO_CLIENT_SECRET" ] && [ ! -z "$ARGO_TENANT_ID" ]; then
  echo "----------------------------------------"
  echo "Configuring ArgoCD SSO..."
  
  # Create patch for argocd-cm
  cat <<EOF > /tmp/argocd-cm-patch.json
{
  "data": {
    "url": "${ARGOCD_SERVER_URL}",
    "dex.config": "connectors:\n- type: microsoft\n  id: microsoft\n  name: Your Company GmbH\n  config:\n    clientID: \"${ARGO_CLIENT_ID}\"\n    clientSecret: \"${ARGO_CLIENT_SECRET}\"\n    redirectURI: \"${ARGOCD_SERVER_URL}/api/dex/callback\"\n    tenant: \"${ARGO_TENANT_ID}\"\n"
  }
}
EOF

  # Apply the patch
  kubectl patch configmap argocd-cm -n argocd --patch-file /tmp/argocd-cm-patch.json
  rm -f /tmp/argocd-cm-patch.json
  
  echo "ArgoCD SSO configuration applied successfully"
else
  echo "Skipping ArgoCD SSO configuration - required environment variables not set"
fi

# Configure RBAC if admin group is set
if [ ! -z "$ARGO_ADMIN_GROUP_ID" ]; then
  echo "----------------------------------------"
  echo "Configuring ArgoCD RBAC..."
  
  # Create patch for argocd-rbac-cm
  cat <<EOF > /tmp/argocd-rbac-cm-patch.json
{
  "data": {
    "policy.csv": "g, ${ARGO_ADMIN_GROUP_ID}, role:admin",
    "policy.default": "role:readonly",
    "scopes": "[groups, email]"
  }
}
EOF

  # Apply the patch
  kubectl patch configmap argocd-rbac-cm -n argocd --patch-file /tmp/argocd-rbac-cm-patch.json
  rm -f /tmp/argocd-rbac-cm-patch.json
  
  echo "ArgoCD RBAC configuration applied successfully"
else
  echo "Skipping ArgoCD RBAC configuration - admin group ID not provided"
fi

echo "----------------------------------------"
echo "All infrastructure application manifests and configurations applied successfully"