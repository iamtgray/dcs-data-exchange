variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "dcs-cloud-native"
}

variable "data_bucket_name" {
  description = "Name of the S3 data bucket"
  type        = string
  default     = "dcs-data"
}

variable "audit_bucket_name" {
  description = "Name of the CloudTrail audit bucket"
  type        = string
  default     = "dcs-audit-trail"
}

variable "nations" {
  description = "Coalition nations with their classification mappings"
  type = map(object({
    clearance_level = number
    nationality     = string
    saps            = list(string)
    organisation    = string
  }))
  default = {
    uk_secret = {
      clearance_level = 2
      nationality     = "GBR"
      saps            = ["WALL"]
      organisation    = "UK-MOD"
    }
    pl_secret = {
      clearance_level = 2
      nationality     = "POL"
      saps            = []
      organisation    = "PL-MON"
    }
    us_secret = {
      clearance_level = 2
      nationality     = "USA"
      saps            = ["WALL"]
      organisation    = "US-DOD"
    }
    contractor = {
      clearance_level = 0
      nationality     = "USA"
      saps            = []
      organisation    = "CONTRACTOR"
    }
  }
}
