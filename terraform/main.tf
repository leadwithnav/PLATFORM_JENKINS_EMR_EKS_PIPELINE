# Main Orchestrator for Platform Infrastructure provisioning

module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  environment  = var.environment
  cluster_name = var.cluster_name
}

module "ecr" {
  source        = "./modules/ecr"
  ecr_repo_name = var.ecr_repo_name
  environment   = var.environment
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  eks_version        = var.eks_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  environment        = var.environment
  instance_types     = var.eks_instance_types
  desired_size       = var.eks_desired_size
  min_size           = var.eks_min_size
  max_size           = var.eks_max_size

  depends_on = [module.vpc]
}

module "emr_on_eks" {
  source                   = "./modules/emr_on_eks"
  environment              = var.environment
  eks_cluster_name         = module.eks.cluster_name
  eks_oidc_provider_arn    = module.eks.cluster_oidc_provider_arn
  eks_oidc_issuer_url      = module.eks.cluster_oidc_issuer_url
  emr_namespace            = var.emr_namespace
  emr_service_account_name = "emr-spark-executor"
  node_role_arn            = module.eks.node_role_arn

  depends_on = [module.eks]
}
