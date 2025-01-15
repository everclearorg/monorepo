terraform {
  backend "s3" {
    bucket = "connext-terraform-infra"
    key    = "state"
    region = "us-east-1"
  }
}


provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

module "iam" {
  source = "../modules/iam"
}

module "kms" {
  source = "../modules/kms"
}

module "ecr" {
  source           = "../modules/ecr"
  repository_names = ["connext-cartographer", "connext-lighthouse", "postgrest"]
  registry_replication_rules = [
    {
      destinations = [
        {
          region      = "eu-north-1"
          registry_id = data.aws_caller_identity.current.account_id
        }
      ]
    }
  ]
}
