terraform {
  required_version = ">=1.6"
  required_providers {
    aws = {
        source = "hashicorp/aws",
        version = "~>5.0"
    }
  }
  backend "s3" {
    bucket = "payments-lab-tfstate-128425594280"
    key = "dev/addons/terraform.tfstate"
    use_lockfile = true
    region = "ap-south-1"
    encrypt = true
  }
}

provider "aws" {
  region = "ap-south-1"
  default_tags {
    tags = {
      Env = "dev"
      Project = "eks-payments-lab",
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {
}

data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket = "payments-lab-tfstate-128425594280"
    key = "dev/cluster/terraform.tfstate"
    region = "ap-south-1"
  }
}

locals {
  oidc_arn = data.terraform_remote_state.cluster.outputs.oidc_provider_arn
  cluster_name = data.terraform_remote_state.cluster.outputs.cluster_name
  account_id = data.aws_caller_identity.current.account_id
}

module "alb_irsa" {
    source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    version = "~>5.0"
    role_name = "${local.cluster_name}-alb-controller"
    attach_load_balancer_controller_policy = true
    oidc_providers = {
        main = {
            provider_arn = local.oidc_arn
            namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
        }
    }
}

module "eso_irsa" {
  source = "../../../modules/irsa"
  role_name = "${local.cluster_name}-external-secrets"
  oidc_provider_arn = local.oidc_arn
  namespace = "external-secrets"
  service_account = "external-secrets"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", 
      "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:ap-south-1:${local.account_id}:secret:payments/*"
    }]
  })
}

module "autoscaler_irsa" {
  source            = "../../../modules/irsa"
  role_name         = "${local.cluster_name}-cluster-autoscaler"
  oidc_provider_arn = local.oidc_arn
  namespace         = "kube-system"
  service_account   = "cluster-autoscaler"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:SetDesiredCapacity", "autoscaling:TerminateInstanceInAutoScalingGroup"]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:ResourceTag/k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned" }
        }
      }
    ]
  })
}

module "ecr" {
  source = "../../../modules/ecr"
  repos  = ["payments-app"]
}

output "alb_role_arn" {
  value = module.alb_irsa.iam_role_arn
}

output "eso_role_arn" {
  value = module.eso_irsa.role_arn
}

output "autoscaler_role_arn" {
  value = module.autoscaler_irsa.role_arn
}

output "ecr_urls" {
  value = module.ecr.repository_urls
}
