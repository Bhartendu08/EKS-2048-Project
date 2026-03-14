# End-to-End Kubernetes Web App on Amazon EKS
This project demonstrates a production-grade deployment of the classic 2048 game on Amazon EKS using a serverless AWS Fargate data plane. It features an automated Application Load Balancer (ALB) setup via the AWS Load Balancer Controller to expose the application to the internet.

![Project Screenshot](https://github.com/Bhartendu08/EKS-2048-Project/blob/main/Screenshot%202026-03-14%20124954.png)

## Architecture Overview
The architecture follows AWS best practices for security and scalability, placing application pods in private subnets while exposing them via a public-facing Application Load Balancer.
Key Components:

    Control Plane: Fully managed Amazon EKS (High Availability across 3 AZs).

    Data Plane: AWS Fargate, eliminating node management, patching, and scaling overhead.

    Ingress: AWS Application Load Balancer automatically provisioned by the AWS Load Balancer Controller.

    Security: IAM Roles for Service Accounts (IRSA) using OIDC for least-privilege pod-level permissions.

    Networking: Custom VPC with public and private subnets, including NAT Gateways for secure outbound traffic.

## Tech Stack & Tools
Cloud: AWS (EKS, Fargate, VPC, IAM, ALB, EC2, STS)

Container Orchestration: Kubernetes

Deployment & Management: kubectl, eksctl, Helm

Application: Dockerized 2048 Game (Nginx-based)

## Deployment Workflow
### Management Host Setup
I utilized an EC2 Instance (Amazon Linux 2023) as a bastion host. This environment was secured using an IAM Instance Profile (Role) to manage AWS resources without hardcoding access keys.
### Cluster Provisioning

The cluster was provisioned using eksctl with a Fargate-only configuration:
eksctl create cluster --name demo-cluster --region ap-south-1 --fargate

### Ingress & ALB Controller Configuration
To enable the Ingress resource, I configured the OIDC provider and installed the AWS Load Balancer Controller via Helm:
### Associate OIDC Provider
eksctl utils associate-iam-oidc-provider --cluster demo-cluster --approve

### Deploy the ALB Controller via Helm
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=$VPC_ID

### Application Deployment
kubectl apply -f k8s-manifests/

### Cleanup
To manage cloud costs, I implemented a teardown script that follows a strict dependency order:

    Kubernetes Ingress: Triggers the ALB Controller to delete the AWS Load Balancer.

    Helm Release & IAM Roles: Cleans up controller resources and service accounts.

    EKS Cluster: Deletes the Fargate profiles and the underlying VPC infrastructure.
