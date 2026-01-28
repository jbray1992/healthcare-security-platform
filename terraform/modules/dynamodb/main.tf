resource "aws_dynamodb_table" "patient_records" {
  name         = "${var.project}-patient-records"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PatientID"
  range_key    = "RecordType"

  attribute {
    name = "PatientID"
    type = "S"
  }

  attribute {
    name = "RecordType"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name    = "${var.project}-patient-records"
    Purpose = "Patient records storage"
  }
}
