
# The ECR repository resource is already aws_ecr_repository.property_app.

resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.existing_github_oidc_provider_arn == "" ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # IAM retrieves the certificate thumbprint when this new provider is created.
  # Do not copy a stale thumbprint from an old tutorial.
  lifecycle {
    prevent_destroy = true
  }
}

locals {
  property_github_oidc_provider_arn = (
    var.existing_github_oidc_provider_arn != ""
    ? var.existing_github_oidc_provider_arn
    : aws_iam_openid_connect_provider.github_actions[0].arn
  )
}

data "aws_iam_policy_document" "github_ecr_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.property_github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_ecr_oidc_subject]
    }
  }
}

resource "aws_iam_role" "github_ecr_push" {
  name                 = "${var.project_name}-${var.environment}-github-ecr-push"
  description          = "Publish property app images from the aws-deployment GitHub branch"
  assume_role_policy   = data.aws_iam_policy_document.github_ecr_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_ecr_push" {
  statement {
    sid       = "AuthenticateToECR"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushOnlyToPropertyRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.property_app.arn]
  }
}

resource "aws_iam_role_policy" "github_ecr_push" {
  name   = "push-property-app-images"
  role   = aws_iam_role.github_ecr_push.id
  policy = data.aws_iam_policy_document.github_ecr_push.json
}
