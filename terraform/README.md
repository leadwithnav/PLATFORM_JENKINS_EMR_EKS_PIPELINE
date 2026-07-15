# Terraform Infrastructure Design & Files Documentation

This directory contains the Infrastructure as Code (IaC) configuration to provision the platform foundations on AWS. The configuration is modularized to ensure separation of concerns, readability, and scalability across environments (`dev`, `staging`, `prod`).

---

## 📂 Directory Structure

```text
terraform/
├── backend.tf               # S3 and DynamoDB remote state storage configuration
├── providers.tf             # AWS, Kubernetes, and Helm provider definitions
├── variables.tf             # Global input variables (environment, region, CIDRs, etc.)
├── outputs.tf               # Orchestrated Outputs (EKS endpoints, EMR cluster IDs, etc.)
├── main.tf                  # Root orchestrator calling sub-modules
└── modules/
    ├── vpc/                 # Network topology (subnets, NAT gateways, route tables)
    ├── ecr/                 # Elastic Container Registry with lifecycle rules
    ├── eks/                 # EKS cluster, worker nodes, and IAM OIDC Provider
    └── emr_on_eks/          # Namespace setup, execution IAM roles, and EMR Virtual Cluster
```

---

## 📄 File-by-File Breakdown

### Root Configurations

#### 1. [`backend.tf`](file:///d:/trainings/platform_jenkins_emr_eks_pipeline/terraform/backend.tf)
- **Purpose**: Defines how and where Terraform stores its state file.
- **Details**: Configured to use Amazon S3 as the remote storage and DynamoDB as the distributed lock table. In the CI/CD pipeline, backend properties (bucket name, key, region, and table) are dynamically overridden during `terraform init` to support environment isolation.

#### 2. [`providers.tf`](file:///d:/trainings/platform_jenkins_emr_eks_pipeline/terraform/providers.tf)
- **Purpose**: Configures the API endpoints and authentications for providers.
- **Details**:
  - **AWS**: Provisions resources in the target AWS Region. Automatically injects default resource tags (`Environment`, `ManagedBy`, `Owner`).
  - **Kubernetes & Helm**: Authenticate dynamically against the newly created EKS cluster using token-based access generated via EKS cluster data sources. This avoids hardcoded tokens or relying on manual kubeconfig generation.

#### 3. [`variables.tf`](file:///d:/trainings/platform_jenkins_emr_eks_pipeline/terraform/variables.tf)
- **Purpose**: Defines inputs to customize the infrastructure.
- **Key Variables**:
  - `aws_region`: Target deployment region (default: `us-east-1`).
  - `environment`: Deployment tier (`dev`, `staging`, `prod`).
  - `vpc_cidr`: Base networking IP block (default: `10.0.0.0/16`).
  - `cluster_name`: Kubernetes EKS cluster identity tag.
  - `emr_namespace`: Target Kubernetes namespace for Spark applications.
  - **Sizing & Instance Customization (Testing/Small Clusters)**:
    - `eks_instance_types`: EC2 instance types for EKS worker nodes. Default is `["t3.large"]` (cheaper, test-friendly instance with 2 vCPUs and 8GB RAM, suitable for system pods + lightweight Spark jobs).
    - `eks_desired_size`: Desired count of EKS worker nodes (default: `1`).
    - `eks_min_size`: Minimum count of EKS worker nodes (default: `1`).
    - `eks_max_size`: Maximum count of EKS worker nodes (default: `2`).

#### 4. [`outputs.tf`](file:///d:/trainings/platform_jenkins_emr_eks_pipeline/terraform/outputs.tf)
- **Purpose**: Exposes configuration data after a successful apply.
- **Details**: Bubble up outputs from internal modules to the root so the Jenkins pipeline can retrieve them (e.g., EKS URL, EMR Virtual Cluster ID, and IAM execution roles for application deployment).

#### 5. [`main.tf`](file:///d:/trainings/platform_jenkins_emr_eks_pipeline/terraform/main.tf)
- **Purpose**: Parent orchestrator that coordinates parameters between modules.
- **Details**: Establishes creation ordering through `depends_on` attributes (e.g., ensuring EKS is active before registering EMR on EKS, and VPC is active before EKS nodes launch).

---

## 📦 Sub-Modules Detail

### 1. VPC Module (`modules/vpc/`)
Provisions the base networking layer.
- **Subnets**: Splits the CIDR block into 3 Public Subnets (front-facing) and 3 Private Subnets (workloads like EKS nodes and EMR executors).
- **NAT Gateway & EIP**: Provisions an Elastic IP and NAT Gateway in a public subnet to allow private-subnet workloads to pull dependencies (like container images, packages) without being exposed to incoming public traffic.
- **EKS Integration Tags**: Automatically applies subnets tags:
  - `kubernetes.io/role/elb = 1` on public subnets (enables public load-balancer placement).
  - `kubernetes.io/role/internal-elb = 1` on private subnets (enables internal load-balancer placement).
  - `kubernetes.io/cluster/<cluster_name> = shared` on all subnets for auto-discovery.

### 2. ECR Module (`modules/ecr/`)
Manages Docker container image registries.
- **Encryption**: Uses AWS KMS Customer Managed Keys for securing container layers.
- **Lifecycle Policies**: Automatically drops untagged images older than 14 days and limits active tagged images to 100 to optimize storage costs.
- **Security scanning**: Features "scan on push" to automatically run vulnerabilities assessments on new image uploads.

### 3. EKS Module (`modules/eks/`)
Provisions the managed Kubernetes infrastructure.
- **Control Plane**: Sets up the EKS cluster master plane with endpoints configured for both public and secure private access.
- **OIDC Provider**: Sets up an OpenID Connect (OIDC) identity provider. Crucial for enabling IAM Roles for Service Accounts (IRSA) so pods can assume specific AWS IAM roles instead of node-level roles.
- **Managed Node Groups**: Provisions an auto-scaling EC2 node group running inside private subnets for resource isolation. Node scaling capacity and instance types are passed dynamically from the root module variables.
- **IAM Policies**: Attaches Kubernetes network interfaces (CNI), worker node, container registry access, and CloudWatch logging policies to node roles.

### 4. EMR on EKS Module (`modules/emr_on_eks/`)
Sets up AWS EMR virtualization layer on Kubernetes.
- **Namespace Configuration**: Generates a dedicated namespace labeled for EMR mapping.
- **Execution Role**: Provisions the EMR Spark Job Execution IAM Role (`-emr-spark-execution-role`) with a trust relationship matching the EKS OIDC provider.
- **Least-Privilege Policy**: Attaches permissions allowing data access to configured S3 datalakes, CloudWatch log streams (`/aws/emr-containers/*`), and AWS Glue catalogs.
- **Virtual Cluster Registration**: Registers the EMR Virtual Cluster (`aws_emrcontainers_virtual_cluster`) linking the EKS cluster namespace to EMR jobs.
- **Kubernetes RBAC**: Provisions custom `Role` and `RoleBinding` inside the jobs namespace to grant control-plane permissions to the EMR service role.
