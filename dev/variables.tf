# 클러스터 이름
variable "cluster_name" {
  description = "Name of cluster - used by Terratest for e2e test automation"
  type        = string
  default     = "5star-mart"
}

# Route53 Domain 
variable "eks_cluster_domain" {
  type        = string
  description = "Route53 domain for the cluster."
  default     = "51bsd.click"
}