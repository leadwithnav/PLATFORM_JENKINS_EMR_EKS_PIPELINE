# EMR on EKS Virtual Cluster provisioning and IAM setup

locals {
  # Strip "https://" prefix from OIDC issuer URL for trust relationship conditions
  oidc_provider = replace(var.eks_oidc_issuer_url, "https://", "")
}

# 1. Create target Kubernetes namespace
resource "kubernetes_namespace" "emr_namespace" {
  metadata {
    name = var.emr_namespace
    labels = {
      "environment"                  = var.environment
      "emr-containers.amazonaws.com" = "true"
    }
  }
}

# 2. IAM Job Execution Role for EMR Spark jobs
# This is the role assumed by Spark driver/executor pods to access S3, Glue, and CloudWatch.
resource "aws_iam_role" "emr_execution" {
  name = "${var.environment}-emr-spark-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.eks_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:sub" = "system:serviceaccount:${var.emr_namespace}:${var.emr_service_account_name}"
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Execution Role Policies: Least privilege access to S3, Glue Catalog, and CloudWatch Logs
resource "aws_iam_policy" "emr_execution_policy" {
  name        = "${var.environment}-emr-spark-execution-policy"
  description = "Execution policy for EMR on EKS Spark jobs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 access for logs and data lakes
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*-emr-data-lake",
          "arn:aws:s3:::*-emr-data-lake/*",
          "arn:aws:s3:::*-emr-logs",
          "arn:aws:s3:::*-emr-logs/*"
        ]
      },
      # CloudWatch Logs access
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/emr-containers/*"
        ]
      },
      # AWS Glue Data Catalog access (for Spark SQL queries)
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:BatchCreatePartition"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "emr_execution_attach" {
  policy_arn = aws_iam_policy.emr_execution_policy.arn
  role       = aws_iam_role.emr_execution.name
}

# 3. Create EMR Virtual Cluster
resource "aws_emrcontainers_virtual_cluster" "this" {
  name = "${var.environment}-emr-virtual-cluster"

  container_provider {
    id   = var.eks_cluster_name
    type = "EKS"

    info {
      eks_info {
        namespace = kubernetes_namespace.emr_namespace.metadata[0].name
      }
    }
  }

  tags = {
    Name = "${var.environment}-emr-virtual-cluster"
  }

  # Ensure EKS auth mapping and K8s RBAC mapping are active BEFORE registering
  depends_on = [
    kubernetes_namespace.emr_namespace,
    kubernetes_config_map_v1_data.aws_auth,
    kubernetes_role_binding.emr_service
  ]
}

# 4. Map the EMR Service Role in AWS to EKS (required for EMR to manage namespaces and pods)
# We create a Kubernetes Role & RoleBinding specifically for EMRContainers service role.
resource "kubernetes_role" "emr_service" {
  metadata {
    name      = "emr-containers-service-role"
    namespace = kubernetes_namespace.emr_namespace.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/status", "pods/log", "serviceaccounts", "services", "configmaps", "persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# Bind the system username "emr-containers" mapped from EMR service role to this namespace RBAC
resource "kubernetes_role_binding" "emr_service" {
  metadata {
    name      = "emr-containers-service-role-binding"
    namespace = kubernetes_namespace.emr_namespace.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.emr_service.metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "emr-containers"
    api_group = "rbac.authorization.k8s.io"
  }
}

# 5. Map the AWS EMR Service Linked Role in EKS using aws-auth ConfigMap
# (AWS does not allow mapping Service Linked Roles via the EKS Access Entry API)
data "aws_caller_identity" "current" {}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<-EOT
      - rolearn: ${var.node_role_arn}
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
      - rolearn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/emr-containers.amazonaws.com/AWSServiceRoleForEMRContainers
        username: emr-containers
        groups:
          - system:authenticated
    EOT
  }

  force = true
}
