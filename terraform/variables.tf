# Input variables for the infrastructure provisioning pipeline

variable "aws_region" {
  type        = string
  description = "The AWS Region to deploy resources."
  default     = "us-west-2"
}

variable "environment" {
  type        = string
  description = "Target environment name (e.g. dev, staging, prod)."
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS Cluster."
  default     = "platform-eks-cluster"
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version for the EKS Cluster."
  default     = "1.30"
}

variable "ecr_repo_name" {
  type        = string
  description = "Name of the ECR Repository."
  default     = "platform-application-repo"
}

variable "emr_namespace" {
  type        = string
  description = "Namespace where EMR on EKS Spark jobs will run."
  default     = "emr-jobs"
}

variable "emr_release_label" {
  type        = string
  description = "EMR Release version."
  default     = "emr-6.13.0-latest"
}

# Testing/Sizing options for cost-effective deployments
variable "eks_instance_types" {
  type        = list(string)
  description = "Worker node EC2 instance types. t3.large is recommended as a minimum for EMR workloads."
  default     = ["t3.large"]
}

variable "eks_desired_size" {
  type        = number
  description = "Desired number of worker nodes."
  default     = 1
}

variable "eks_min_size" {
  type        = number
  description = "Minimum number of worker nodes."
  default     = 1
}

variable "eks_max_size" {
  type        = number
  description = "Maximum number of worker nodes."
  default     = 2
}
