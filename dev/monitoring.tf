#---------------------------------------------------------------
# kube-prometheus-stack 설치
#---------------------------------------------------------------

resource "aws_s3_bucket" "thanos" {
  bucket = "5starmart-thanos-storage"
}

resource "kubernetes_namespace_v1" "thanos" {
  metadata {
      name = "thanos"
  }
}
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
      name = "monitoring"
  }
}

# 프로메테우스
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "41.6.1"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  set_sensitive {
      name  = "grafana.adminPassword"
      value = jsondecode(data.aws_secretsmanager_secret_version.grafana.secret_string)["password"]
  }
  values = [templatefile("./helm_values/kube-prometheus-stack.yaml", {
      thanos_role_arn              = aws_iam_role.thanos.arn
      thanos_objconfig_secret_name = kubernetes_secret_v1.prometheus_object_store_config.metadata[0].name
  })]
}

module "kubeapp-monitoring" {
  source         = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.21.0"
  eks_cluster_id = module.eks_blueprints.eks_cluster_id

#   # 프로메테우스
#   # issue: kube-prometheus-stack 모듈 만 namespace ? 1:0  조건없이 무조건 생성해서 순서가 꼬임
#   enable_kube_prometheus_stack = true
#   kube_prometheus_stack_helm_config = {
#     set_sensitive = [{
#       name  = "grafana.adminPassword"
#       value = jsondecode(data.aws_secretsmanager_secret_version.grafana.secret_string)["password"]
#     }]

#     values = [templatefile("./helm_values/kube-prometheus-stack.yaml", {
#       thanos_role_arn              = aws_iam_role.thanos.arn
#       thanos_objconfig_secret_name = kubernetes_secret_v1.prometheus_object_store_config.metadata[0].name
#     })]

#     namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
#   }

  # 타노스
  enable_thanos = true
  thanos_helm_config = {
    values = [
      templatefile("./helm_values/thanos.yaml", {
        thanos_objconfig_secret_name = kubernetes_secret_v1.thanos_object_store_config.metadata[0].name
        thanos_role_arn              = aws_iam_role.thanos.arn
      })
    ]
    create_namespace = false
    namespace = kubernetes_namespace_v1.thanos.metadata[0].name
  }
}

#---------------------------------------------------------------
# 그라파나 어드민 비밀번호를 AWS SecretManager로 사용
#---------------------------------------------------------------

data "aws_secretsmanager_secret" "grafana" {
  name = "grafana"
}

data "aws_secretsmanager_secret_version" "grafana" {
  secret_id = data.aws_secretsmanager_secret.grafana.id
}

#---------------------------------------------------------------
# 타노스 컴포넌트 Role + 설정파일 Secret
#---------------------------------------------------------------

# 타노스 사이드카 설정 파일
resource "kubernetes_secret_v1" "prometheus_object_store_config" {
  metadata {
    name      = "thanos-objstore-config"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    "thanos.yaml" = yamlencode({
      type = "s3"
      config = {
        bucket   = aws_s3_bucket.thanos.bucket
        endpoint = replace(aws_s3_bucket.thanos.bucket_regional_domain_name, "${aws_s3_bucket.thanos.bucket}.", "")
      }
    })
  }
}

# 타노스 컴포넌트 설정 파일
resource "kubernetes_secret_v1" "thanos_object_store_config" {
  metadata {
    name      = "objstore-config"
    namespace = kubernetes_namespace_v1.thanos.metadata[0].name
  }
  data = {
    "objstore.yml" = yamlencode({
      type = "s3"
      config = {
        bucket   = aws_s3_bucket.thanos.bucket
        endpoint = replace(aws_s3_bucket.thanos.bucket_regional_domain_name, "${aws_s3_bucket.thanos.bucket}.", "")
      }
    })
  }
}

# Thanos (컴포넌트+사이드카)에 부여할 IAM Role
resource "aws_iam_role" "thanos" {
  name_prefix        = substr("${local.cluster_name}-thanos-", 0, 37)
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${module.eks_blueprints.eks_oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity"
    }
  ]
}
POLICY
  inline_policy {
    name = "s3-access"

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.thanos.arn}",
        "${aws_s3_bucket.thanos.arn}/*"
      ]
    }
  ]
}
EOF
  }
}