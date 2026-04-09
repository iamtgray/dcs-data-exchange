resource "aws_dynamodb_table" "data" {
  name         = "${var.project_name}-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "dataId"

  attribute {
    name = "dataId"
    type = "S"
  }

  attribute {
    name = "classification"
    type = "S"
  }

  global_secondary_index {
    name            = "by-classification"
    hash_key        = "classification"
    projection_type = "ALL"
  }

  tags = {
    Purpose = "DCS Level 2 labeled data store"
  }
}


resource "aws_dynamodb_table_item" "intel_report" {
  table_name = aws_dynamodb_table.data.name
  hash_key   = aws_dynamodb_table.data.hash_key
  item = jsonencode({
    dataId              = { S = "intel-report-001" }
    classification      = { S = "SECRET" }
    classificationLevel = { N = "2" }
    releasableTo        = { SS = ["GBR", "USA", "POL"] }
    requiredSap         = { S = "" }
    originator          = { S = "POL" }
    created             = { S = "2025-03-15T10:30:00Z" }
    payload             = { S = "Enemy forces observed moving through northern sector. Estimated 200 personnel with armoured vehicles." }
  })
}

resource "aws_dynamodb_table_item" "wall_report" {
  table_name = aws_dynamodb_table.data.name
  hash_key   = aws_dynamodb_table.data.hash_key
  item = jsonencode({
    dataId              = { S = "wall-report-003" }
    classification      = { S = "SECRET" }
    classificationLevel = { N = "2" }
    releasableTo        = { SS = ["GBR", "USA", "POL"] }
    requiredSap         = { S = "WALL" }
    originator          = { S = "GBR" }
    created             = { S = "2025-03-16T08:15:00Z" }
    payload             = { S = "UK enriched intelligence: Operation WALL updated assessment with HUMINT sources." }
  })
}

resource "aws_dynamodb_table_item" "uk_eyes" {
  table_name = aws_dynamodb_table.data.name
  hash_key   = aws_dynamodb_table.data.hash_key
  item = jsonencode({
    dataId              = { S = "uk-eyes-only-002" }
    classification      = { S = "SECRET" }
    classificationLevel = { N = "2" }
    releasableTo        = { SS = ["GBR"] }
    requiredSap         = { S = "" }
    originator          = { S = "GBR" }
    created             = { S = "2025-03-16T14:00:00Z" }
    payload             = { S = "UK-only assessment of partner nation capabilities." }
  })
}