resource "aws_dynamodb_table" "labels" {
  name         = "${var.project_name}-labels"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "object_key"
  range_key    = "object_version"

  attribute {
    name = "object_key"
    type = "S"
  }

  attribute {
    name = "object_version"
    type = "S"
  }

  attribute {
    name = "classification"
    type = "S"
  }

  attribute {
    name = "originator"
    type = "S"
  }

  global_secondary_index {
    name            = "classification-index"
    hash_key        = "classification"
    range_key       = "object_key"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "originator-index"
    hash_key        = "originator"
    range_key       = "object_key"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Purpose = "STANAG-4774-label-store"
  }
}
