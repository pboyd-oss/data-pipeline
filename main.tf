terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "tuxgrid-terraform-state"
    region = "eu-west-1"
    # key is injected at plan time:
    #   -backend-config="key=team-b/<env>/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "input" {
  bucket = "${var.env}-team-b-data-input"

  tags = {
    Team        = "team-b"
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "input" {
  bucket = aws_s3_bucket.input.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input" {
  bucket = aws_s3_bucket.input.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "input" {
  bucket                  = aws_s3_bucket.input.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sqs_queue" "jobs" {
  name                       = "${var.env}-team-b-jobs"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400

  tags = {
    Team        = "team-b"
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

resource "aws_sqs_queue_policy" "jobs" {
  queue_url = aws_sqs_queue.jobs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.jobs.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_s3_bucket.input.arn
        }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "input_to_jobs" {
  bucket = aws_s3_bucket.input.id

  queue {
    queue_arn     = aws_sqs_queue.jobs.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
  }

  depends_on = [aws_sqs_queue_policy.jobs]
}
