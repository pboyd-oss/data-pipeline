variable "env" {
  description = "Deployment environment name (staging, production-us)"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}
