terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.40.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# 버킷 생성
resource "aws_s3_bucket" "terraform_state" {
  bucket = "osung-s3-tfstate"

  lifecycle {
    prevent_destroy = true
  }
}

# 백엔드 지정
terraform {
  backend "s3" {
    bucket         = "osung-s3-tfstate"
    key            = "backend/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "osung-TerraformStateLock"
    encrypt        = true
  }
}

# S3 버전 활성
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.bucket
  versioning_configuration {
    status = "Enabled"
  }
}
# S3 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
# S3 퍼블릭 액세스 잠금
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
# Dynamodb 생성
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "osung-TerraformStateLock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}