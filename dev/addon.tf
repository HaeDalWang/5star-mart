#---------------------------------------------------------------
# EKS Common Addon
#---------------------------------------------------------------

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.21.0"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  # EKS Managed Add-ons
  enable_amazon_eks_vpc_cni            = true
  enable_amazon_eks_coredns            = true
  enable_amazon_eks_kube_proxy         = true
  enable_amazon_eks_aws_ebs_csi_driver = true

  # Add-ons
  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true

  enable_cluster_autoscaler = true
  cluster_autoscaler_helm_config = {
    set = [
      {
        name  = "podLabels.prometheus\\.io/scrape",
        value = "true",
        type  = "string",
      }
    ]
  }

  eks_cluster_domain  = local.cluster_domain
  enable_external_dns = true
  external_dns_helm_config = {
    values = [templatefile("./helm_values/external_dns-values.yaml", {
      txtOwnerId    = local.name
      domainFilters = local.cluster_domain
    })]
  }

  tags = local.tags
}

#---------------------------------------------------------------
# 기본 StorageClass 교체 
#---------------------------------------------------------------

# EBS CSI 드라이버를 사용하는 스토리지 클래스 gp3
resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "gp3"
  }
}
# 기본값으로 생성된 스토리지 클래스 해제
resource "kubernetes_annotations" "default_storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  depends_on = [
    kubernetes_storage_class.ebs_sc
  ]
}

#---------------------------------------------------------------
# 도메인 인증서 부분
#---------------------------------------------------------------

# 운영시 사용할 Route53 하위 도메인 
data "aws_route53_zone" "osung_domain" {
  name         = local.cluster_domain
  private_zone = false
}
# 상위 도메인
data "aws_route53_zone" "root_domain" {
  name         = "51bsd.click"
  private_zone = false
}
# ACM 인증서 발급
resource "aws_acm_certificate" "acm_osung_certification" {
  domain_name       = "*.${data.aws_route53_zone.osung_domain.name}"
  validation_method = "DNS"
}

# 루트도메인의 ACM 하위 인증서 레코드 추가
resource "aws_route53_record" "osung_acm_recode" {
  for_each = {
    for dvo in aws_acm_certificate.acm_osung_certification.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.root_domain.zone_id
}

# 상위도메인의 하위도메인 NS레코드 추가
resource "aws_route53_record" "osung_ns_recode" {
  allow_overwrite = true
  name            = "osung"
  ttl             = 172800
  type            = "NS"
  zone_id         = data.aws_route53_zone.root_domain.zone_id

  records = [
    data.aws_route53_zone.osung_domain.name_servers[0],
    data.aws_route53_zone.osung_domain.name_servers[1],
    data.aws_route53_zone.osung_domain.name_servers[2],
    data.aws_route53_zone.osung_domain.name_servers[3],
  ]
}