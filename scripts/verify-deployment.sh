#!/usr/bin/env bash

# This script verifies the deployment status of the EKS cluster, Helm releases, and EMR Virtual Cluster.
# Arguments:
#   1. EKS_CLUSTER_NAME
#   2. AWS_REGION
#   3. EMR_VIRTUAL_CLUSTER_ID (optional)

set -eo pipefail

CLUSTER_NAME=${1}
REGION=${2}
EMR_CLUSTER_ID=${3:-""}

if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ]; then
    echo "❌ Error: EKS_CLUSTER_NAME and AWS_REGION must be provided."
    echo "Usage: $0 <eks-cluster-name> <aws-region> [emr-virtual-cluster-id]"
    exit 1
fi

echo "===================================================="
echo " Starting Post-Deployment Verification..."
echo " EKS Cluster: $CLUSTER_NAME"
echo " AWS Region:  $REGION"
if [ -n "$EMR_CLUSTER_ID" ]; then
    echo " EMR Cluster: $EMR_CLUSTER_ID"
fi
echo "===================================================="

# 1. Update kubeconfig
echo "Configuring kubectl for cluster: $CLUSTER_NAME..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# 2. Check cluster accessibility
echo "Checking connection to EKS Kubernetes API..."
if kubectl cluster-info &> /dev/null; then
    echo "✅ Successfully connected to EKS API server."
else
    echo "❌ Failed to connect to EKS cluster!"
    exit 1
fi

# 3. Check Namespaces
echo "Checking namespaces..."
kubectl get ns

# 4. Check Helm releases
echo "Checking Helm releases..."
helm list -A

# 5. Check Nodes
echo "Checking worker nodes status..."
kubectl get nodes -o wide

# 6. Verify EMR on EKS Virtual Cluster if ID is provided
if [ -n "$EMR_CLUSTER_ID" ]; then
    echo "Verifying EMR on EKS Virtual Cluster status..."
    CLUSTER_DESC=$(aws emr-containers describe-virtual-cluster --id "$EMR_CLUSTER_ID" --region "$REGION")
    CLUSTER_STATE=$(echo "$CLUSTER_DESC" | grep -o '"state": "[^"]*' | grep -o '[^"]*$')
    
    echo "EMR Virtual Cluster State: $CLUSTER_STATE"
    if [ "$CLUSTER_STATE" == "RUNNING" ]; then
        echo "✅ EMR on EKS Virtual Cluster is RUNNING."
    else
        echo "❌ EMR on EKS Virtual Cluster is not in RUNNING state! Current state: $CLUSTER_STATE"
        exit 1
    fi
fi

echo "===================================================="
echo "✅ All verification checks passed successfully!"
echo "===================================================="
exit 0
