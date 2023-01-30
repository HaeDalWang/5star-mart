#---------------------------------------------------------------
# Kubeapp Argocd 
#---------------------------------------------------------------

module "kubeapp-argocd" {
  source         = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.21.0"
  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  enable_argocd = true
  argocd_helm_config = {
    set_sensitive = [
      {
        name  = "configs.secret.argocdServerAdminPassword"
        value = bcrypt_hash.argo.id
      }
    ]
    values  = [templatefile("./helm_values/argocd.yaml", {})]
    timeout = "1200"
  }

  argocd_manage_add_ons = false

  ## 어플리케이션 설정
  #   argocd_applications = {
  #     addons = {
  #       path               = "chart"
  #       repo_url           = "https://github.com/aws-samples/eks-blueprints-add-ons.git"
  #       add_on_application = true
  #     }
  #     workloads = {
  #       path               = "envs/dev"
  #       repo_url           = "https://github.com/aws-samples/eks-blueprints-workloads.git"
  #       add_on_application = false
  #     }
  #   }

  #   enable_argo_rollouts = true
  tags = local.tags
}

#---------------------------------------------------------------
# ArgoCD 어드민 비밀번호 AWS SecretManager 사용
#---------------------------------------------------------------

resource "bcrypt_hash" "argo" {
  cleartext = jsondecode(data.aws_secretsmanager_secret_version.argocd.secret_string)["password"]
}

data "aws_secretsmanager_secret" "argocd" {
  name = "argocd"
}

data "aws_secretsmanager_secret_version" "argocd" {
  secret_id = data.aws_secretsmanager_secret.argocd.id
}

#---------------------------------------------------------------
# Github Action
#---------------------------------------------------------------
# module "github-actoin" {
#   source = "./modules/github-action"
# }