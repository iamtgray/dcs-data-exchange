# Upload sample objects with DCS labels for scenario testing

resource "aws_s3_object" "intel_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "intel-report-001.txt"
  content      = "Sample intelligence report - SECRET GBR/USA/POL"
  content_type = "text/plain"

  tags = {
    "dcs:classification"      = "2"
    "dcs:classification-name" = "SECRET"
    "dcs:rel-GBR"             = "true"
    "dcs:rel-USA"             = "true"
    "dcs:rel-POL"             = "true"
    "dcs:sap"                 = "NONE"
    "dcs:originator"          = "POL"
    "dcs:labeled-at"          = timestamp()
  }
}

resource "aws_s3_object" "uk_eyes_only" {
  bucket       = aws_s3_bucket.data.id
  key          = "uk-eyes-only-002.txt"
  content      = "UK EYES ONLY - SECRET assessment"
  content_type = "text/plain"

  tags = {
    "dcs:classification"      = "2"
    "dcs:classification-name" = "SECRET"
    "dcs:rel-GBR"             = "true"
    "dcs:sap"                 = "NONE"
    "dcs:originator"          = "GBR"
    "dcs:labeled-at"          = timestamp()
  }
}

resource "aws_s3_object" "sap_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "wall-report-003.txt"
  content      = "SAP WALL compartmented report"
  content_type = "text/plain"

  tags = {
    "dcs:classification"      = "2"
    "dcs:classification-name" = "SECRET"
    "dcs:rel-GBR"             = "true"
    "dcs:rel-USA"             = "true"
    "dcs:sap"                 = "WALL"
    "dcs:originator"          = "GBR"
    "dcs:labeled-at"          = timestamp()
  }
}

resource "aws_s3_object" "unclass_logistics" {
  bucket       = aws_s3_bucket.data.id
  key          = "logistics-004.csv"
  content      = "Unclassified logistics data"
  content_type = "text/csv"

  tags = {
    "dcs:classification"      = "0"
    "dcs:classification-name" = "UNCLASSIFIED"
    "dcs:rel-ALL"             = "true"
    "dcs:sap"                 = "NONE"
    "dcs:originator"          = "USA"
    "dcs:labeled-at"          = timestamp()
  }
}
