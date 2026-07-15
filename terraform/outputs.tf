# Outputs from Terraform deployment to be consumed by Jenkins stages and other systems

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "ecr_repository_url" {
  description = "The URL of the ECR Repository"
  value       = module.ecr.repository_url
}

output "eks_cluster_name" {
  description = "The EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_issuer_url" {
  description = "The OIDC Issuer URL for EKS cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "emr_virtual_cluster_id" {
  description = "The ID of the registered EMR Virtual Cluster"
  value       = module.emr_on_eks.emr_virtual_cluster_id
}

output "emr_execution_role_arn" {
  description = "IAM Role ARN for EMR execution jobs"
  value       = module.emr_on_eks.emr_execution_role_arn
}

output "emr_namespace" {
  description = "Kubernetes namespace for EMR jobs"
  value       = var.emr_namespace
}
