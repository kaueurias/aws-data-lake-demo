terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "data-lake-demo"
}

# S3 Bucket for Data Lake
resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project_name}-data-lake-${random_string.suffix.result}"
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Kinesis Data Firehose
resource "aws_kinesis_firehose_delivery_stream" "data_firehose" {
  name        = "${var.project_name}-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.data_lake.arn
    prefix             = "raw/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "errors/"
    compression_format = "GZIP"
    
    buffering_size     = 1
    buffering_interval = 60
    
    processing_configuration {
      enabled = true
      processors {
        type = "Lambda"
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.data_transformer.arn
        }
      }
    }
    
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = "${var.project_name}-firehose-stream"
    }
  }
}

# Data transformer Lambda
resource "aws_lambda_function" "data_transformer" {
  filename         = "transformer_function.zip"
  function_name    = "${var.project_name}-transformer"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60
  
  depends_on = [data.archive_file.transformer_zip]
}

data "archive_file" "transformer_zip" {
  type        = "zip"
  output_path = "transformer_function.zip"
  source {
    content = <<EOF
import json
import base64
from datetime import datetime

def handler(event, context):
    output = []
    
    for record in event['records']:
        payload = base64.b64decode(record['data'])
        data = json.loads(payload)
        data['ingestion_time'] = datetime.utcnow().isoformat()
        
        output_record = {
            'recordId': record['recordId'],
            'result': 'Ok',
            'data': base64.b64encode(json.dumps(data).encode('utf-8')).decode('utf-8')
        }
        output.append(output_record)
    
    return {'records': output}
EOF
    filename = "index.py"
  }
}

# S3 Event Notification
resource "aws_s3_bucket_notification" "glue_trigger" {
  bucket = aws_s3_bucket.data_lake.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.glue_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".gz"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# Glue trigger Lambda
resource "aws_lambda_function" "glue_trigger" {
  filename         = "glue_trigger.zip"
  function_name    = "${var.project_name}-glue-trigger"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60
  
  depends_on = [data.archive_file.glue_trigger_zip]
}

data "archive_file" "glue_trigger_zip" {
  type        = "zip"
  output_path = "glue_trigger.zip"
  source {
    content = <<EOF
import json
import boto3

def handler(event, context):
    glue = boto3.client('glue')
    
    try:
        response = glue.get_job_runs(JobName='${var.project_name}-etl-job', MaxResults=1)
        
        if response['JobRuns'] and response['JobRuns'][0]['JobRunState'] in ['RUNNING', 'STARTING']:
            return {'statusCode': 200, 'body': 'Job already running'}
        
        glue.start_job_run(JobName='${var.project_name}-etl-job')
        return {'statusCode': 200, 'body': 'Glue job triggered'}
        
    except Exception as e:
        return {'statusCode': 500, 'body': f'Error: {str(e)}'}
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.glue_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data_lake.arn
}

# Glue Database
resource "aws_glue_catalog_database" "database" {
  name = "${replace(var.project_name, "-", "_")}_database"
}

# Glue ETL Job
resource "aws_glue_job" "etl_job" {
  name         = "${var.project_name}-etl-job"
  role_arn     = aws_iam_role.glue_role.arn
  glue_version = "4.0"
  
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.data_lake.bucket}/scripts/etl_script.py"
    python_version  = "3"
  }
  
  default_arguments = {
    "--job-bookmark-option" = "job-bookmark-enable"
    "--enable-metrics"      = ""
    "--TempDir"            = "s3://${aws_s3_bucket.data_lake.bucket}/temp/"
    "--s3_input_path"      = "s3://${aws_s3_bucket.data_lake.bucket}/raw/"
    "--s3_output_path"     = "s3://${aws_s3_bucket.data_lake.bucket}/processed/"
    "--database_name"      = aws_glue_catalog_database.database.name
  }
  
  worker_type       = "G.1X"
  number_of_workers = 2
  max_retries       = 1
  timeout           = 60
}

# Glue ETL Script
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.data_lake.bucket
  key    = "scripts/etl_script.py"
  content = <<EOF
import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from datetime import datetime

args = getResolvedOptions(sys.argv, ["JOB_NAME", "s3_input_path", "s3_output_path", "database_name"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

datasource = glueContext.create_dynamic_frame.from_options(
    format_options={"multiline": False},
    connection_type="s3",
    format="json",
    connection_options={
        "paths": [args["s3_input_path"]],
        "recurse": True
    },
    transformation_ctx="datasource"
)

mapped_frame = ApplyMapping.apply(
    frame=datasource,
    mappings=[
        ("year", "string", "year", "int"),
        ("month", "string", "month", "int"),
        ("day", "string", "day", "int"),
        ("firstname", "string", "firstname", "string"),
        ("lastname", "string", "lastname", "string"),
        ("city", "string", "city", "string"),
        ("state", "string", "state", "string"),
        ("country", "string", "country", "string"),
        ("zipcode", "string", "zipcode", "string"),
        ("street", "string", "street", "string"),
        ("transactionamount", "string", "transactionamount", "decimal(10,2)"),
        ("ingestion_time", "string", "ingestion_time", "timestamp")
    ],
    transformation_ctx="mapped_frame"
)

now = datetime.now()
s3_path = f"{args['s3_output_path']}year={now.year}/month={now.month:02d}/day={now.day:02d}/"

glueContext.write_dynamic_frame.from_options(
    frame=mapped_frame,
    connection_type="s3",
    format="glueparquet",
    connection_options={"path": s3_path, "partitionKeys": []},
    format_options={"compression": "snappy"},
    transformation_ctx="datasink"
)

job.commit()
EOF
}

# Athena Workgroup
resource "aws_athena_workgroup" "workgroup" {
  name = "${var.project_name}-workgroup"
  force_destroy = true
  
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.bucket}/athena-results/"
    }
  }
}