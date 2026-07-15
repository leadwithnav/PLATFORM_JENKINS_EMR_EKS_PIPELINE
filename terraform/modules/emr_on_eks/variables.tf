variable "environment" {
  type        = string
  description = "Target environment"
}

variable "eks_cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "EKS cluster OIDC provider ARN"
}

variable "eks_oidc_issuer_url" {
  type        = string
  description = "EKS cluster OIDC issuer URL"
}

variable "emr_namespace" {
  type        = string
  description = "Kubernetes namespace for EMR jobs"
  default     = "emr-jobs"
}

variable "emr_service_account_name" {
  type        = string
  description = "Service account for Spark executors"
  default     = "emr-spark-executor"
}

variable "node_role_arn" {
  type        = string
  description = "IAM Role ARN of the EKS worker nodes (for aws-auth mapping)"
}
