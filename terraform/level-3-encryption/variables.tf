variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "dcs-level-3"
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "cognito_uk_pool_id" {
  description = "Cognito User Pool ID for the UK IdP (from Lab 2)"
  type        = string
}

variable "cognito_uk_client_id" {
  description = "Cognito User Pool Client ID for the UK IdP (from Level 2)"
  type        = string
}
