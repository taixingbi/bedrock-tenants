variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "function_name" {
  type    = string
  default = "bedrock-inference-mvp"
}

variable "lambda_zip" {
  type        = string
  description = "Absolute path to the packaged Lambda zip"
}

variable "model_id" {
  type    = string
  default = "amazon.nova-lite-v1:0"
}

variable "model_map" {
  type    = string
  default = ""
}

variable "api_key" {
  type      = string
  sensitive = true
}

variable "guardrail_id" {
  type    = string
  default = ""
}

variable "guardrail_version" {
  type    = string
  default = "DRAFT"
}
