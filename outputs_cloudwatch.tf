output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups for monitoring"
  value = {
    firehose_logs      = aws_cloudwatch_log_group.firehose_logs.name
    transformer_logs   = aws_cloudwatch_log_group.data_transformer_logs.name
    glue_trigger_logs  = aws_cloudwatch_log_group.glue_trigger_logs.name
    glue_job_logs      = data.aws_cloudwatch_log_group.glue_job_logs.name
    glue_error_logs    = data.aws_cloudwatch_log_group.glue_job_error_logs.name
    glue_output_logs   = data.aws_cloudwatch_log_group.glue_job_output_logs.name
  }
}