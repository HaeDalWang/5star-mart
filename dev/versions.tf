terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.52.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.17"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.3.2"
    }
    bcrypt = {
      source  = "viktorradnai/bcrypt"
      version = ">= 0.1.2"
    }
  }
  # 테라폼 백엔드 설정 - key 값 앞에 접두사는 환경이름과 동일
  backend "s3" {
    bucket         = "5star-mart-s3-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "TerraformStateLock"
    encrypt        = true
  }
}
