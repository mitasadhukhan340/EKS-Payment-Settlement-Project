variable "role_name" {
    type = string
}

variable "oidc_provider_arn" {
    type = string
}

variable "namespace" {
    type = string
}

variable "service_account" {
  type = string
}
variable "policy_json" {
    type = string
}

locals {
    oidc_host = split("oidc-provider/",var.oidc_provider_arn)[1]
}

data "aws_iam_policy_document" trust {
    statement {
      actions = ["sts:AssumeRoleWithWebIdentity"]
      principals {
        type = "Federated"
        identifiers = [var.oidc_provider_arn]
      }
      condition {
        test = "StringEquals"
        variable = "${local.oidc_host}:sub"
        values = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
      }
      condition {
        test = "StringEquals"
        variable = "${local.oidc_host}:aud"
        values = ["sts.amazonaws.com"]
      }
    }
}

resource "aws_iam_role" "this" {
  name = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy" "this" {
  name = "inline"
  role = aws_iam_role.this.id
  policy = var.policy_json
  }

  output "role_arn" {
    value = aws_iam_role.this.arn
  }