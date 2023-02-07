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
  enable_external_dns = true
  # Route53 Domain
  eks_cluster_domain = "51bsd.click"
  external_dns_helm_config = {
    name       = "external-dns"
    chart      = "external-dns"
    repository = "https://charts.bitnami.com/bitnami"
    version    = "6.13.1"
    namespace  = "external-dns"
    values = [templatefile("./helm_values/external_dns-values.yaml", {
      txtOwnerId   = local.name
      zoneIdFilter = "51bsd.click"
    })]
  }

  tags = local.tags
}