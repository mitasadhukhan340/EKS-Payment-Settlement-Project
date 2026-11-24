terraform {
    required_version= ">=1.6"
    backend "s3" {
        bucket = "payments-lab-tfstate-128425594280"
        key = "dev/cluster/terraform.tfstate"
        region = "ap-south-1"
        dynamodb_table = "tf-locks"
        encrypt = true
    }
    required_providers {
        aws = { 
            source= "hashicorp/aws",
            version= "~>5.0"
        }
    }
}

provider "aws" {
    region = "ap-south-1"
    default_tags {
        tags = {
            Project = "eks-paymens-lab",
            Env = "dev",
            ManagedBy = "terraform"
        }
    }
}

data "terraform_remote_state" "network" {
    backend = "s3"
    config = {
        bucket = "payments-lab-tfstate-128425594280"
        key = "dev/network/terraform.tfstate"
        region = "ap-south-1"
    }
}

module "eks" {
    source = "../../../modules/eks"
    cluster_name = "payments-dev"
    cluster_version = "1.36"
    vpc_id = data.terraform_remote_state.network.outputs.vpc_id
    private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
    instance_types = ["m7i-flex.large"]
    min_size = 2
    max_size = 5
    desired_size = 2
}

output "cluster_name" {
    value = module.eks.cluster_name
}

output "oidc_provider_arn" {
    value = module.eks.oidc_provider_arn
}