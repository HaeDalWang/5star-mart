module "kubeapp-prometheus" {
  source         = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.21.0"
  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  enable_kube_prometheus_stack      = true
  kube_prometheus_stack_helm_config = {
    set_sensitive = [
      {
        name  = "grafana.adminPassword"
        value = jsondecode(data.aws_secretsmanager_secret_version.grafana.secret_string)["password"]
      }
    ]
    values  = [templatefile("./helm_values/kube-prometheus-stack.yaml", {})]
    timeout = "1200"
  }
}

#---------------------------------------------------------------
# Grafana Admin Password credentials with AWS Secrets Manager
#---------------------------------------------------------------

data "aws_secretsmanager_secret" "grafana" {
  name = "grafana"
}

data "aws_secretsmanager_secret_version" "grafana" {
  secret_id = data.aws_secretsmanager_secret.grafana.id
}