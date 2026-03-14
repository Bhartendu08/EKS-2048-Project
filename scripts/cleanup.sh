#!/bin/bash

# 1. Set your project variables
export CLUSTER_NAME="demo-cluster"
export REGION="ap-south-1"  # Mumbai (or your corrected region)
export NAMESPACE="game-2048"

echo "Starting cleanup for $CLUSTER_NAME in $REGION..."

# 2. Delete the Application (Ingress, Service, Deployment)
# This triggers the ALB Controller to automatically delete the AWS Load Balancer
echo "Step 1: Deleting Kubernetes resources (triggers ALB deletion)..."
kubectl delete ingress ingress-2048 -n $NAMESPACE
kubectl delete service service-2048 -n $NAMESPACE
kubectl delete deployment deployment-2048 -n $NAMESPACE

# Wait for ALB to be deleted in AWS (approx 2-3 mins)
echo "Waiting for AWS Load Balancer to fully detach..."
sleep 120

# 3. Uninstall the AWS Load Balancer Controller
echo "Step 2: Uninstalling Helm release..."
helm uninstall aws-load-balancer-controller -n kube-system

# 4. Delete IAM Service Accounts
# This removes the trust relationship between K8s and IAM
echo "Step 3: Deleting IAM Service Accounts..."
eksctl delete iamserviceaccount \
    --cluster $CLUSTER_NAME \
    --region $REGION \
    --namespace kube-system \
    --name aws-load-balancer-controller

# 5. Delete the EKS Cluster
# This deletes Fargate profiles, the VPC, and the Control Plane
echo "Step 4: Deleting EKS Cluster (this takes ~15 minutes)..."
eksctl delete cluster --name $CLUSTER_NAME --region $REGION --wait

# 6. Final check: Release any orphaned Elastic IPs
# If the NAT Gateway deletion was messy, this saves you from quota errors later
echo "Step 5: Cleaning up any unassociated Elastic IPs..."
UNUSED_EIPS=$(aws ec2 describe-addresses --region $REGION --query 'Addresses[?AssociationId==null].AllocationId' --output text)

for EIP in $UNUSED_EIPS; do
    if [ "$EIP" != "None" ]; then
        echo "Releasing orphaned Elastic IP: $EIP"
        aws ec2 release-address --allocation-id $EIP --region $REGION
    fi
done

echo "Cleanup Complete!"