variable "cluster_name" {
  type        = string
  description = "The EKS cluster name"
}

variable "eks_version" {
  type        = string
  description = "The Kubernetes version for EKS"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where cluster is created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the node group workloads (private subnet recommended)"
}

variable "environment" {
  type        = string
  description = "Target environment"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for the worker nodes"
}

variable "desired_size" {
  type        = number
  description = "Desired count of worker nodes"
}

variable "min_size" {
  type        = number
  description = "Minimum count of worker nodes"
}

variable "max_size" {
  type        = number
  description = "Maximum count of worker nodes"
}
