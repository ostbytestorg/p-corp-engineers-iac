#!/bin/bash
set -e

# Function to display status messages
status() {
  echo -e "\033[1;34m>> $1\033[0m"
}

# Check if NetBox repo already exists
if ! helm repo list | grep -q "netbox"; then
  status "Adding NetBox Helm repo..."
  helm repo add netbox https://netbox-community.github.io/helm-charts/
else
  status "NetBox Helm repo already exists, skipping add..."
fi

# Always update the repo to get latest charts
status "Updating Helm repos..."
helm repo update

# Check if NetBox is already installed
if helm list -n netbox 2>/dev/null | grep -q "netbox"; then
  status "NetBox is already installed. Use helm upgrade or uninstall first."
  exit 1
fi

# Install NetBox with Redis limited to 1 replica
status "Installing NetBox with Redis configured for exactly one replica..."
helm install netbox netbox/netbox --namespace netbox --create-namespace 

status "NetBox installation initiated. Pods will be starting shortly."
status "To check pod status, run: kubectl get pods -n netbox"
status "For details on any failing pods, run: kubectl describe pod <pod-name> -n netbox"
status "To access NetBox, set up port forwarding: kubectl port-forward svc/netbox 8000:80 -n netbox"