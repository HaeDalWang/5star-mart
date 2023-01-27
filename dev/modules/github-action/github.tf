# Github OIDC 발급자 인증서 불러오기
data "tls_certificate" "github_oidc_issuer_cert" {
  url = "https://token.actions.githubusercontent.com"
}

# Github OIDC 제공자
resource "aws_iam_openid_connect_provider" "github" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc_issuer_cert.certificates[0].sha1_fingerprint]
  url             = "https://token.actions.githubusercontent.com" 
}

# Github Actions에 부여할 IAM 역할 생성
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