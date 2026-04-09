variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dcs-level-1"
}

variable "classification_levels" {
  description = "Valid classification levels (ordered lowest to highest)"
  type        = list(string)
  default     = ["UNCLASSIFIED", "OFFICIAL", "SECRET", "TOP-SECRET"]
}

variable "valid_nationalities" {
  description = "Valid nationality codes for releasability"
  type        = list(string)
  default     = ["GBR", "USA", "POL"]
}
