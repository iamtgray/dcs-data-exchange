variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dcs-l1-assured"
}

variable "nato_classifications" {
  description = "Valid NATO classification levels (ordered lowest to highest)"
  type        = list(string)
  default     = [
    "NATO UNCLASSIFIED",
    "NATO RESTRICTED",
    "NATO CONFIDENTIAL",
    "NATO SECRET",
    "COSMIC TOP SECRET"
  ]
}

variable "gbr_classifications" {
  description = "Valid UK national classification levels"
  type        = list(string)
  default     = ["OFFICIAL", "SECRET", "TOP SECRET"]
}

variable "valid_nationalities" {
  description = "Valid nationality codes for releasability"
  type        = list(string)
  default     = ["GBR", "USA", "POL", "DEU", "FRA", "CAN"]
}
