# CloudWatch Log Groups for monitoring

# Kinesis Firehose Log Group
resource "aws_cloudwatch_log_group" "firehose_logs" {
  name              = "/aws/kinesisfirehose/${var.project_name}-firehose"
  retention_in_days = 7
}

# Lambda Data Transformer Log Group
resource "aws_cloudwatch_log_group" "data_transformer_logs" {
  name              = "/aws/lambda/${var.project_name}-transformer"
  retention_in_days = 7
}

# Lambda Glue Trigger Log Group
resource "aws_cloudwatch_log_group" "glue_trigger_logs" {
  name              = "/aws/lambda/${var.project_name}-glue-trigger"
  retention_in_days = 7
}

# Glue creates these log groups automatically, so we reference them
data "aws_cloudwatch_log_group" "glue_job_logs" {
  name = "/aws-glue/jobs/logs-v2"
}

data "aws_cloudwatch_log_group" "glue_job_error_logs" {
  name = "/aws-glue/jobs/error"
}

data "aws_cloudwatch_log_group" "glue_job_output_logs" {
  name = "/aws-glue/jobs/output"
}