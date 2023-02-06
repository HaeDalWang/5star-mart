#---------------------------------------------------------------
# ArgoCD 설치 및 어플레케이션 등록
#---------------------------------------------------------------

module "kubeapp-argocd" {
  source         = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.21.0"
  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  enable_argocd = true
  argocd_helm_config = {
    set_sensitive = [{
        name  = "configs.secret.argocdServerAdminPassword"
        value = bcrypt_hash.argo.id
      }]
    values  = [templatefile("./helm_values/argocd.yaml", {})]
    timeout = "1200"
  }

  argocd_manage_add_ons = false

  # 어플리케이션 추가
  argocd_applications = {
    addons = {
      path               = "frontend"
      repo_url           = "HaeDalWang/helmchart-test"
      add_on_application = true
      ssh_key_secret_name = "github-ssh-key"
    }
  }
    
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
# ECR Repository 생성 10개
#---------------------------------------------------------------

resource "aws_ecr_repository" "osung" {
  for_each = toset(["osung-frontend","osung-ad","osung-recomend","osung-productcatalog","osung-cart","osung-shipping","osung-checkout","osung-currency","osung-payment","osung-email"])

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

#---------------------------------------------------------------
# Github OIDC 설정
#---------------------------------------------------------------

data "tls_certificate" "github_oidc_issuer_cert" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc_issuer_cert.certificates[0].sha1_fingerprint]
  url             = "https://token.actions.githubusercontent.com" 
}

resource "aws_iam_role" "github" {
  name                = "github-actions-role"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"]
  assume_role_policy  = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.github.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity"
    }
  ]
}
POLICY
}