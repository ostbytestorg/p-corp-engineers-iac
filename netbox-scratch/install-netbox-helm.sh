#!/bin/bash
set -e

# Check if NetBox repo already exists
if ! helm repo list | grep -q "netbox"; then
  echo "Adding NetBox Helm repo..."
  helm repo add netbox https://netbox-community.github.io/helm-charts/
else
  echo "NetBox Helm repo already exists, skipping add..."
fi

# Always update the repo to get latest charts
echo "Updating Helm repos..."
helm repo update

# Check if NetBox is already installed
if helm list -n netbox 2>/dev/null | grep -q "netbox"; then
  echo "NetBox is already installed. Use helm upgrade or uninstall first."
  exit 1
fi

# Install NetBox with configuration including ingress
echo "Installing NetBox..."
helm install netbox netbox/netbox --namespace netbox --create-namespace \
  --set resources.limits.memory=512Mi \
  --set resources.requests.memory=256Mi \
  --set postgresql.resources.limits.memory=256Mi \
  --set postgresql.resources.requests.memory=128Mi \
  --set redis.master.resources.limits.memory=128Mi \
  --set redis.master.resources.requests.memory=64Mi \
  --set redis.replica.replicaCount=1 \
  --set ingress.enabled=true \
  --set ingress.annotations."kubernetes\.io/ingress\.class"=nginx \
  --set 'ingress.hosts[0].host=' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=Prefix' \
  --set 'ingress.hosts[0].paths[0].backend.service.name=netbox' \
  --set 'ingress.hosts[0].paths[0].backend.service.port.number=80'

echo "NetBox installation complete. Use 'kubectl get pods -n netbox' to check status."

# Wait a bit for pods to start 
echo "Waiting for pods to initialize (30 seconds)..."
sleep 30

# Check the status of NetBox pods
echo "Checking pod status..."
kubectl get pods -n netbox

# Check if worker pod is having issues and restart it if needed
echo "Checking if worker pod needs restart..."
WORKER_POD=$(kubectl get pods -n netbox -l app.kubernetes.io/component=worker -o jsonpath='{.items[0].metadata.name}')
WORKER_STATUS=$(kubectl get pod $WORKER_POD -n netbox -o jsonpath='{.status.phase}')
WORKER_READY=$(kubectl get pod $WORKER_POD -n netbox -o jsonpath='{.status.containerStatuses[0].ready}')

if [ "$WORKER_STATUS" = "Running" ] && [ "$WORKER_READY" = "false" ]; then
  echo "Worker pod is running but not ready. Restarting worker pod: $WORKER_POD"
  kubectl delete pod $WORKER_POD -n netbox
  echo "Worker pod restart initiated. It may take a minute to become ready."
fi

# Get the ingress controller IP to display access URL
echo "Checking ingress status..."
sleep 5  # Brief pause to let ingress resource create
kubectl get ingress -n netbox

# Attempt to find the external IP of the ingress
INGRESS_IP=$(kubectl get ingress -n netbox -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$INGRESS_IP" ]; then
  echo "NetBox should be accessible at: http://$INGRESS_IP"
else
  echo "Ingress IP not yet available. Use 'kubectl get ingress -n netbox' to check later."
fi

echo "Installation complete."