variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "email_a" {
  type        = string
  description = "Unused email for member account A (AWS root). Do not change after create."
  default     = "tb_bedrock_a@gmail.com"
}

variable "email_b" {
  type        = string
  description = "Unused email for member account B (AWS root). Do not change after create."
  default     = "tb_bedrock_b@gmail.com"
}

variable "account_a_name" {
  type    = string
  default = "mvp-bedrock-a"
}

variable "account_b_name" {
  type    = string
  default = "mvp-bedrock-b"
}

variable "ou_name" {
  type    = string
  default = "inference"
}

variable "role_name" {
  type    = string
  default = "OrganizationAccountAccessRole"
}
