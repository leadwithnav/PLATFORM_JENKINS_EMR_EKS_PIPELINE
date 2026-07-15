output "emr_virtual_cluster_id" {
  description = "The EMR on EKS Virtual Cluster ID"
  value       = aws_emrcontainers_virtual_cluster.this.id
}

output "emr_execution_role_arn" {
  description = "IAM Role ARN for Spark job execution"
  value       = aws_iam_role.emr_execution.arn
}
