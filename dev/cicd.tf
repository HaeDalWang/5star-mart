# #---------------------------------------------------------------
# # ArgoCD 설치 및 어플레케이션 등록
# #---------------------------------------------------------------

# module "kubeapp-argocd" {
#   source         = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.21.0"
#   eks_cluster_id = module.eks_blueprints.eks_cluster_id

#   enable_argocd = true
#   argocd_helm_config = {
#     set_sensitive = [{
#       name  = "configs.secret.argocdServerAdminPassword"
#       value = bcrypt_hash.argo.id
#     }]
#     values  = [templatefile("./helm_values/argocd.yaml", {})]
#     timeout = "1200"
#   }

#   argocd_manage_add_ons = false

#   depends_on = [
#     aws_ecr_repository.osung,
#     aws_iam_role.github
#   ]

#   tags = local.tags
# }

# #---------------------------------------------------------------
# # ArgoCD 어드민 비밀번호 AWS SecretManager 사용
# #---------------------------------------------------------------

# resource "bcrypt_hash" "argo" {
#   cleartext = jsondecode(data.aws_secretsmanager_secret_version.argocd.secret_string)["password"]
# }

# data "aws_secretsmanager_secret" "argocd" {
#   name = "argocd"
# }

# data "aws_secretsmanager_secret_version" "argocd" {
#   secret_id = data.aws_secretsmanager_secret.argocd.id
# }

# #---------------------------------------------------------------
# # ECR Repository 생성 2개
# #---------------------------------------------------------------

# resource "aws_ecr_repository" "osung" {
#   for_each = toset(["osung-frontend", "osung-email"])

#   name                 = each.key
#   image_tag_mutability = "MUTABLE"

#   image_scanning_configuration {
#     scan_on_push = true
#   }
# }

# #---------------------------------------------------------------
# # Github OIDC & Role 설정
# #---------------------------------------------------------------

# data "tls_certificate" "github_oidc_issuer_cert" {
#   url = "https://token.actions.githubusercontent.com"
# }

# resource "aws_iam_openid_connect_provider" "github" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = [data.tls_certificate.github_oidc_issuer_cert.certificates[0].sha1_fingerprint]
#   url             = "https://token.actions.githubusercontent.com"
# }

# resource "aws_iam_role" "github" {
#   name                = "github-actions-role"
#   managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"]
#   assume_role_policy  = <<POLICY
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Federated": "${aws_iam_openid_connect_provider.github.arn}"
#       },
#       "Action": "sts:AssumeRoleWithWebIdentity"
#     }
#   ]
# }
# POLICY
# }

# #---------------------------------------------------------------
# # repo 추가 및 어플리케이션 배포
# #---------------------------------------------------------------

# # data "aws_secretsmanager_secret" "dev" {
# #   name = "argocd"
# # }
# # data "aws_secretsmanager_secret_version" "dev" {
# #   secret_id = data.aws_secretsmanager_secret.dev.id
# # }

# /* 헬름 차트 리포지토리 등록
# https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#repositories */
# # resource "kubernetes_secret_v1" "beautyselection_helm_charts_repo" {
# #   metadata {
# #     name      = "test-helm-charts"
# #     namespace = "argocd"
# #     labels = {
# #       "argocd.argoproj.io/secret-type" = "repository"
# #     }
# #   }
# #   data = {
# #     type     = "git"
# #     url      = "https://github.com//.git"
# #     password = jsondecode(data.aws_secretsmanager_secret_version.dev.secret_string)["github"]
# #     username = "not-used"
# #   }
# # }

# /* Argo CD 애플리케이션 생성
# https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#applications */
# # resource "kubernetes_manifest" "test" {
# #   provider = kubernetes.ops

# #   manifest = {
# #     apiVersion = "argoproj.io/v1alpha1"
# #     kind       = "Application"

# #     metadata = {
# #       name      = "cafe24-api-${local.environment}"
# #       namespace = kubernetes_namespace_v1.argocd.metadata[0].name
# #     }
# #     spec = {
# #       project = kubernetes_manifest.argocd_project.manifest.metadata.name
# #       source = {
# #         repoURL        = "https://github.com//k8s-manifest.git"
# #         targetRevision = "HEAD"
# #         path           = "helm-charts/"
# #         helm = {
# #           valueFiles = [
# #             "values_${local.environment}.yaml"
# #           ]
# #         }
# #       }
# #       destination = {
# #         name      = kubernetes_secret_v1.argocd_cluster.data.name
# #         namespace = "default"
# #       }
# #     }
# #   }
# # }