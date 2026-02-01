data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project}-athena-results-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.project}-athena-results"
    Purpose = "Athena query results storage"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy - delete query results after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-results"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 7
    }
  }
}

# Athena workgroup
resource "aws_athena_workgroup" "main" {
  name = "${var.project}-workgroup"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.id}/results/"
    }
  }

  tags = {
    Name    = "${var.project}-workgroup"
    Purpose = "Athena workgroup for compliance queries"
  }
}

# Glue database for CloudTrail logs
resource "aws_glue_catalog_database" "cloudtrail" {
  name = replace("${var.project}-cloudtrail-db", "-", "_")

  description = "Database for CloudTrail log analysis"
}

# Glue table for CloudTrail logs
resource "aws_glue_catalog_table" "cloudtrail_logs" {
  name          = "cloudtrail_logs"
  database_name = aws_glue_catalog_database.cloudtrail.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "projection.enabled"            = "true"
    "projection.date.type"          = "date"
    "projection.date.range"         = "2024/01/01,NOW"
    "projection.date.format"        = "yyyy/MM/dd"
    "projection.date.interval"      = "1"
    "projection.date.interval.unit" = "DAYS"
    "projection.region.type"        = "enum"
    "projection.region.values"      = data.aws_region.current.name
    "storage.location.template"     = "s3://${var.cloudtrail_bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/$${region}/$${date}"
  }

  storage_descriptor {
    location      = "s3://${var.cloudtrail_bucket_name}/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/"
    input_format  = "com.amazon.emr.cloudtrail.CloudTrailInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hive.hcatalog.data.JsonSerDe"
    }

    columns {
      name = "eventversion"
      type = "string"
    }
    columns {
      name = "useridentity"
      type = "struct<type:string,principalid:string,arn:string,accountid:string,invokedby:string,accesskeyid:string,username:string,sessioncontext:struct<attributes:struct<mfaauthenticated:string,creationdate:string>,sessionissuer:struct<type:string,principalid:string,arn:string,accountid:string,username:string>,webidfederationdata:struct<federatedprovider:string,attributes:map<string,string>>>>"
    }
    columns {
      name = "eventtime"
      type = "string"
    }
    columns {
      name = "eventsource"
      type = "string"
    }
    columns {
      name = "eventname"
      type = "string"
    }
    columns {
      name = "awsregion"
      type = "string"
    }
    columns {
      name = "sourceipaddress"
      type = "string"
    }
    columns {
      name = "useragent"
      type = "string"
    }
    columns {
      name = "errorcode"
      type = "string"
    }
    columns {
      name = "errormessage"
      type = "string"
    }
    columns {
      name = "requestparameters"
      type = "string"
    }
    columns {
      name = "responseelements"
      type = "string"
    }
    columns {
      name = "additionaleventdata"
      type = "string"
    }
    columns {
      name = "requestid"
      type = "string"
    }
    columns {
      name = "eventid"
      type = "string"
    }
    columns {
      name = "eventtype"
      type = "string"
    }
    columns {
      name = "recipientaccountid"
      type = "string"
    }
    columns {
      name = "serviceeventdetails"
      type = "string"
    }
    columns {
      name = "sharedeventid"
      type = "string"
    }
    columns {
      name = "vpcendpointid"
      type = "string"
    }
    columns {
      name = "resources"
      type = "array<struct<arn:string,accountid:string,type:string>>"
    }
  }

  partition_keys {
    name = "region"
    type = "string"
  }
  partition_keys {
    name = "date"
    type = "string"
  }
}
