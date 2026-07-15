# AWS Pipeline Outputs & Resource Architecture

This document maps out the output variables and AWS resource configurations created upon a successful run of the platform CI/CD pipeline.

---

## 🏁 1. Pipeline & Terraform Outputs

These outputs are printed at the end of the `Terraform Execute` stage and are consumed by the subsequent Helm and Verification stages in the Jenkins pipeline.

| Output Variable Name | Description | Example Format |
| :--- | :--- | :--- |
| `vpc_id` | The ID of the VPC created for cluster isolation. | `vpc-0a8b9c10d2e3f4g56` |
| `ecr_repository_url` | Registry URL to host Docker container images. | `<account-id>.dkr.ecr.<region>.amazonaws.com/<env>-platform-application-repo` |
| `eks_cluster_name` | The name identifying the EKS Cluster. | `<env>-platform-eks-cluster` |
| `eks_cluster_endpoint` | Endpoint to interact with the Kubernetes API server. | `https://<cluster-endpoint-hash>.gr7.<region>.eks.amazonaws.com` |
| `eks_oidc_issuer_url` | The URL of the OpenID Connect (OIDC) identity provider. | `https://oidc.eks.<region>.amazonaws.com/id/<oidc-hash>` |
| `emr_virtual_cluster_id`| ID of the registered EMR Virtual Cluster on EKS. | `abc123def456ghi789jkl0123` |
| `emr_execution_role_arn`| IAM Role assumed by EMR Spark driver/executors. | `arn:aws:iam::<account-id>:role/<env>-emr-spark-execution-role` |

---

## 🏗️ 2. AWS Infrastructure Topology

The following resources are provisioned on AWS under the active environment profile (e.g. `dev`, `staging`, `prod`):

### 🌐 A. Virtual Private Cloud (VPC)
- **IP Block**: VPC CIDR `10.0.0.0/16`.
- **Subnet Configuration**:
  - **3 Public Subnets**: `10.0.0.0/24`, `10.0.1.0/24`, `10.0.2.0/24` (spread across 3 Availability Zones). Mapped with tags `kubernetes.io/role/elb = 1` for public load balancer attachment.
  - **3 Private Subnets**: `10.0.10.0/24`, `10.0.11.0/24`, `10.0.12.0/24` (spread across 3 Availability Zones). Mapped with tags `kubernetes.io/role/internal-elb = 1` for internal ingress routing.
- **NAT Gateway & EIP**: 1 Elastic IP and 1 NAT Gateway created inside public subnet `0` to routing outbound-only internet traffic for pods and nodes residing in private subnets.

### 📦 B. Elastic Container Registry (ECR)
- **Repository**: Named `<env>-platform-application-repo`.
- **Security**: Enabled with KMS envelope encryption and automatic image vulnerability scanning on image upload.
- **Lifecycle Policies**:
  - Drops untagged images older than 14 days.
  - Retains a maximum of 100 tagged images.

### ☸️ C. Elastic Kubernetes Service (EKS)
- **Kubernetes Version**: `1.28`.
- **API Server Endpoint Access**: Public & Private access enabled (allows secure kubectl execution from external build agents).
- **OIDC Provider**: Provisioned to map EKS web identities to IAM policies (IAM Roles for Service Accounts - IRSA).
- **Node Configuration**:
  - **Managed Node Group**: 1 node group (`<env>-managed-nodes`) deployed in private subnets.
  - **EC2 Instance Type**: `t3.large` (2 vCPUs, 8GB RAM) - optimized for test/development workloads.
  - **Scaling Capacity**: Desired: `1`, Min: `1`, Max: `2`.

### 📊 D. EMR on EKS Integration
- **Virtual Cluster**: 1 virtual EMR cluster (`<env>-emr-virtual-cluster`) registered on the EKS cluster namespace `emr-jobs`.
- **Execution Role**: 1 IAM execution role (`<env>-emr-spark-execution-role`).
  - **OIDC Trust Policy**: Allows EKS ServiceAccount `emr-spark-executor` inside the `emr-jobs` namespace to assume this role.
  - **IAM Privileges**:
    - **S3 Access**: Read/Write to S3 buckets matching `*-emr-data-lake` and `*-emr-logs` (bucket prefix-matching).
    - **CloudWatch**: Writes logs to `/aws/emr-containers/*` log groups.
    - **Glue Catalog**: Full metadata lookup and table update permissions.

---

## ☸️ 3. Kubernetes / Helm Platform Setup

Applied to EKS during the post-apply pipeline phase:
* **Namespace**: Creates the `emr-jobs` namespace.
* **ServiceAccount**: Creates `emr-spark-executor` annotated with the target IAM role ARN.
* **RBAC Setup**: Roles and RoleBindings mapped inside `emr-jobs` granting container orchestration permissions to the EMR service role.
* **ResourceQuota**: Enforces limits (`100 vCPUs` and `400GiB` memory) inside `emr-jobs` namespace to safeguard cluster stability.
