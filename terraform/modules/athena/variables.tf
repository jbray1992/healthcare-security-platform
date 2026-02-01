variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket containing CloudTrail logs"
  type        = string
}
