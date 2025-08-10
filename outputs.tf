output "s3_bucket_name" {
  description = "Name of the S3 bucket for data lake"
  value       = aws_s3_bucket.data_lake.bucket
}

output "firehose_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.data_firehose.name
}

# Cognito outputs removed - will be managed via CloudFormation

output "glue_database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.database.name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.workgroup.name
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.data_transformer.function_name
}

output "s3_processed_path" {
  description = "S3 path for processed data (use this in Athena)"
  value       = "s3://${aws_s3_bucket.data_lake.bucket}/processed/"
}

output "athena_fix_commands" {
  description = "Commands to fix Athena table"
  value = [
    "DROP TABLE IF EXISTS kdg_processed_data;",
    "Run terraform apply to recreate table",
    "MSCK REPAIR TABLE kdg_processed_data;"
  ]
}

# KDG-related outputs removed - will be managed via CloudFormation