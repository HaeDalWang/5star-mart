#---------------------------------------------------------------
# 프로바이더 및 로컬 변수 지정
#---------------------------------------------------------------

provider "aws" {
  region = local.region
}
provider "kubernetes" {
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}
provider "helm" {
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}

locals {
  name         = "5star-dev"
  environment  = "dev"
  cluster_name = local.name
  # Route53 Domain
  cluster_domain = "osung.51bsd.click"
  region       = "ap-northeast-2"

  tags = {
    environment = "dev"
  }
}