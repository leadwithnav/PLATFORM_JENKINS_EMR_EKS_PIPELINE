# Elastic Container Registry for storing platform and spark job Docker images

resource "aws_ecr_repository" "repo" {
  name                 = "${var.environment}-${var.ecr_repo_name}"
  image_tag_mutability = "MUTABLE" # Recommended: IMMUTABLE for production to prevent overrides

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS" # Production-grade encryption at rest using AWS KMS
  }

  tags = {
    Name = "${var.environment}-${var.ecr_repo_name}"
  }
}

# Image cleaning policy to clean up old, unused untagged container images (prevents runaway storage costs)
resource "aws_ecr_lifecycle_policy" "policy" {
  repository = aws_ecr_repository.repo.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire untagged images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Keep last 100 tagged images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 100
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
