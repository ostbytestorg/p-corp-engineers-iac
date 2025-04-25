#!/bin/bash
set -e

# Function to display status messages
status() {
  echo -e "\033[1;34m>> $1\033[0m"
}

# Check if NetBox is installed
if ! helm list -n netbox 2>/dev/null | grep -q "netbox"; then
  status "NetBox is not installed. Nothing to uninstall."
  
  # Check if namespace exists anyway
  if kubectl get namespace netbox &>/dev/null; then
    status "NetBox namespace exists but no Helm release found."
    
    # Ask if user wants to delete the namespace
    read -p "Do you want to delete the netbox namespace? (y/n): " delete_ns
    if [[ "$delete_ns" =~ ^[Yy]$ ]]; then
      status "Deleting netbox namespace..."
      kubectl delete namespace netbox
      status "Namespace deleted."
    else
      status "Namespace not deleted. You may need to clean up manually."
    fi
  fi
  
  exit 0
fi

# Start the uninstallation
status "Uninstalling NetBox Helm release..."
helm uninstall netbox -n netbox

# Wait for resources to be deleted
status "Waiting for resources to be cleaned up..."

# Check if namespace still exists
if kubectl get namespace netbox &>/dev/null; then
  status "Waiting for namespace to be deleted..."
  
  # Try to wait up to 30 seconds for namespace deletion
  TIMEOUT=30
  for i in $(seq 1 $TIMEOUT); do
    if ! kubectl get namespace netbox &>/dev/null; then
      status "Namespace deleted successfully."
      break
    fi
    
    echo -n "."
    sleep 1
    
    # If reached timeout, ask user if they want to force delete
    if [ $i -eq $TIMEOUT ]; then
      echo ""
      status "Namespace still exists after $TIMEOUT seconds."
      read -p "Do you want to force delete the namespace? (y/n): " force_delete
      
      if [[ "$force_delete" =~ ^[Yy]$ ]]; then
        status "Force deleting namespace..."
        kubectl delete namespace netbox --force --grace-period=0
        status "Force delete initiated. Resources may still be terminating."
      else
        status "Namespace not force deleted. You may need to clean up manually."
      fi
    fi
  done
else
  status "Namespace already deleted."
fi

status "Checking for any persistent volumes or claims..."
PVS=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace == "netbox") | .metadata.name')

if [ -n "$PVS" ]; then
  status "Found persistent volumes associated with netbox namespace:"
  for pv in $PVS; do
    echo "- $pv"
  done
  
  read -p "Do you want to delete these persistent volumes? (y/n): " delete_pvs
  if [[ "$delete_pvs" =~ ^[Yy]$ ]]; then
    for pv in $PVS; do
      status "Deleting PV $pv..."
      kubectl delete pv $pv
    done
    status "Persistent volumes deleted."
  else
    status "Persistent volumes not deleted."
  fi
else
  status "No persistent volumes found for netbox namespace."
fi

status "NetBox uninstallation complete."