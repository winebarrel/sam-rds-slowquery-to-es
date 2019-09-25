provider "aws" {
  version = "= 2.29.0"
  region  = "ap-northeast-1"

  allowed_account_ids = [
    "${var.account_id}",
  ]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
