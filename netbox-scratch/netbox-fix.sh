# Uninstall the current installation first
helm uninstall netbox -n default

# Make sure all resources are cleaned up
kubectl delete pvc -l app.kubernetes.io/instance=netbox -n default

# Find available versions
helm search repo netbox/netbox --versions

# Install a specific version before 5.0.48
# For example, let's use 5.0.47 (adjust as needed based on the available versions)
helm install netbox netbox/netbox --version 5.0.0 -n default