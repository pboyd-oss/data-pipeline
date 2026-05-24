output "input_bucket_name" {
  description = "Name of the S3 bucket for raw data input"
  value       = aws_s3_bucket.input.bucket
}

output "jobs_queue_url" {
  description = "URL of the SQS queue for job notifications"
  value       = aws_sqs_queue.jobs.url
}

output "jobs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.jobs.arn
}
