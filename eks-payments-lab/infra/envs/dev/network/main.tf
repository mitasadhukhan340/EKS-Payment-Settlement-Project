terraform {
  required_version = ">= 1.6"
  backend "s3" {
    bucket         = "payments-lab-tfstate-128425594280"
    key            = "dev/network/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = { Project = "eks-payments-lab", Env = "dev", ManagedBy = "terraform" }
  }
}

module "network" {
  source             = "../../../modules/network"
  name               = "payments-dev"
  cluster_name       = "payments-dev"
  vpc_cidr           = "10.0.0.0/16"
  single_nat_gateway = true
}


output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}
