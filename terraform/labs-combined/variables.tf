variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "db_password" {
  description = "Password for the OpenTDF RDS database"
  type        = string
  sensitive   = true
}

variable "user_password" {
  description = "Password for all Cognito test users"
  type        = string
  default     = "TempPass1!"
  sensitive   = true
}
