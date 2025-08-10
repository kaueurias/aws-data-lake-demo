# Glue Crawler for processed data
resource "aws_glue_crawler" "processed_data_crawler" {
  database_name = aws_glue_catalog_database.database.name
  name          = "${var.project_name}-processed-data-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/processed/"
  }

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  schedule = "cron(0 2 * * ? *)"  # Daily at 2 AM
}

# Glue Table matching actual data structure
resource "aws_glue_catalog_table" "processed_data" {
  name          = "processed_data"
  database_name = aws_glue_catalog_database.database.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "classification" = "parquet"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.data_lake.bucket}/processed/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    columns {
      name = "year"
      type = "int"
    }

    columns {
      name = "month"
      type = "int"
    }

    columns {
      name = "day"
      type = "int"
    }

    columns {
      name = "firstname"
      type = "string"
    }

    columns {
      name = "lastname"
      type = "string"
    }

    columns {
      name = "city"
      type = "string"
    }

    columns {
      name = "state"
      type = "string"
    }

    columns {
      name = "country"
      type = "string"
    }

    columns {
      name = "zipcode"
      type = "string"
    }

    columns {
      name = "street"
      type = "string"
    }

    columns {
      name = "transactionamount"
      type = "decimal(10,2)"
    }

    columns {
      name = "ingestion_time"
      type = "timestamp"
    }
  }

  partition_keys {
    name = "year_partitioned"
    type = "string"
  }

  partition_keys {
    name = "month_partitioned"
    type = "string"
  }

  partition_keys {
    name = "day_partitioned"
    type = "string"
  }
}