#!/bin/bash
set -e

echo "====================== NETBOX STATUS CHECK ======================"

# Check if the netbox namespace exists
if ! kubectl get namespace netbox &>/dev/null; then
  echo "❌ NetBox namespace does not exist. NetBox is not installed."
  echo
else
  echo "✅ NetBox namespace found."
  
  # Check all pods are running
  echo -e "\n📊 NetBox Pod Status:"
  echo "----------------------------------------"
  kubectl get pods -n netbox
  
  # Count ready vs total pods using kubectl jsonpath instead of jq
  TOTAL_PODS=$(kubectl get pods -n netbox --no-headers | wc -l)
  READY_PODS=$(kubectl get pods -n netbox --no-headers | grep "Running" | grep -v "0/1\|0/2" | wc -l)
  
  echo -e "\n🔍 Pod Readiness: $READY_PODS/$TOTAL_PODS ready"
  
  if [ "$READY_PODS" -ne "$TOTAL_PODS" ]; then
    echo "⚠️  Not all pods are ready. Checking problematic pods..."
    NOT_READY=$(kubectl get pods -n netbox --no-headers | grep -v "Running\|Completed" | awk '{print $1}')
    if [ -n "$NOT_READY" ]; then
      for pod in $NOT_READY; do
        echo -e "\n🔍 Details for pod $pod:"
        kubectl describe pod $pod -n netbox | grep -A 10 "Events:"
      done
    fi
    
    RUNNING_NOT_READY=$(kubectl get pods -n netbox --no-headers | grep "Running" | grep "0/1\|0/2" | awk '{print $1}')
    if [ -n "$RUNNING_NOT_READY" ]; then
      for pod in $RUNNING_NOT_READY; do
        echo -e "\n🔍 Details for pod $pod (running but not ready):"
        kubectl describe pod $pod -n netbox | grep -A 10 "Events:"
      done
    fi
  fi
fi

echo -e "\n📊 Resource Usage:"
echo "----------------------------------------"
echo "📝 NODE RESOURCES:"
if ! kubectl top nodes 2>/dev/null; then
  echo "❌ Unable to get node metrics. Metrics server may not be installed."
fi

echo -e "\n📝 NETBOX POD RESOURCES:"
if kubectl get namespace netbox &>/dev/null; then
  if ! kubectl top pods -n netbox 2>/dev/null; then
    echo "❌ Unable to get pod metrics. Metrics server may not be installed."
  fi
else
  echo "❌ NetBox namespace does not exist."
fi

echo -e "\n📊 Cluster Pod Usage:"
echo "----------------------------------------"
TOTAL_PODS=$(kubectl get pods --all-namespaces | wc -l)
echo "📝 Total pod count: $TOTAL_PODS"

echo -e "\n📊 Node Capacity:"
echo "----------------------------------------"
kubectl describe nodes | grep -A 5 "Allocatable:" | grep -v "^Events:"

echo -e "\n📊 NetBox Service Status:"
echo "----------------------------------------"
if kubectl get namespace netbox &>/dev/null; then
  kubectl get svc -n netbox
else
  echo "❌ NetBox namespace does not exist."
fi

echo -e "\n====================== STATUS CHECK COMPLETE ======================\n"