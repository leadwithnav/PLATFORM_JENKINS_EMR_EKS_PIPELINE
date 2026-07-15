variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "environment" {
  type        = string
  description = "Target environment"
}

variable "cluster_name" {
  type        = string
  description = "The EKS cluster name (used for auto-discovery tags)"
}
