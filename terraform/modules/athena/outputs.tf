output "workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.main.name
}

output "database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.cloudtrail.name
}

output "table_name" {
  description = "Name of the CloudTrail logs table"
  value       = aws_glue_catalog_table.cloudtrail_logs.name
}

output "results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.id
}
