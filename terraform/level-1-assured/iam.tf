resource "aws_iam_user" "uk_secret" {
  name = "${var.project_name}-user-gbr-secret"
  tags = {
    "dcs:clearance"    = "SECRET"
    "dcs:nationality"  = "GBR"
    "dcs:saps"         = "WALL"
    "dcs:organisation" = "UK-MOD"
    "dcs:policy"       = "NATO"
  }
}

resource "aws_iam_user" "pol_secret" {
  name = "${var.project_name}-user-pol-ns"
  tags = {
    "dcs:clearance"    = "NATO SECRET"
    "dcs:nationality"  = "POL"
    "dcs:saps"         = ""
    "dcs:organisation" = "PL-MON"
    "dcs:policy"       = "NATO"
  }
}

resource "aws_iam_user" "us_secret" {
  name = "${var.project_name}-user-usa-secret"
  tags = {
    "dcs:clearance"    = "SECRET"
    "dcs:nationality"  = "USA"
    "dcs:saps"         = "WALL"
    "dcs:organisation" = "US-DOD"
    "dcs:policy"       = "NATO"
  }
}

resource "aws_iam_user" "contractor" {
  name = "${var.project_name}-user-contractor"
  tags = {
    "dcs:clearance"    = "NATO UNCLASSIFIED"
    "dcs:nationality"  = "GBR"
    "dcs:saps"         = ""
    "dcs:organisation" = "CONTRACTOR"
    "dcs:policy"       = "NATO"
  }
}

resource "aws_iam_policy" "api_invoke" {
  name = "${var.project_name}-api-invoke"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "execute-api:Invoke"
        Resource = "${aws_api_gateway_rest_api.dcs.execution_arn}/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "uk_api" {
  user       = aws_iam_user.uk_secret.name
  policy_arn = aws_iam_policy.api_invoke.arn
}

resource "aws_iam_user_policy_attachment" "pol_api" {
  user       = aws_iam_user.pol_secret.name
  policy_arn = aws_iam_policy.api_invoke.arn
}

resource "aws_iam_user_policy_attachment" "us_api" {
  user       = aws_iam_user.us_secret.name
  policy_arn = aws_iam_policy.api_invoke.arn
}

resource "aws_iam_user_policy_attachment" "contractor_api" {
  user       = aws_iam_user.contractor.name
  policy_arn = aws_iam_policy.api_invoke.arn
}
