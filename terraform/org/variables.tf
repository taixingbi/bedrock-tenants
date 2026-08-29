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

variable "email_c" {
  type        = string
  description = "Unused email for member account C (AWS root). Do not change after create."
  default     = "tb_bedrock_c@gmail.com"
}

variable "email_d" {
  type        = string
  description = "Unused email for member account D (AWS root). Do not change after create."
  default     = "tb_bedrock_d@gmail.com"
}

variable "account_a_name" {
  type    = string
  default = "bedrock-tenant-a"
}

variable "account_b_name" {
  type    = string
  default = "bedrock-tenant-b"
}

variable "account_c_name" {
  type    = string
  default = "bedrock-tenant-c"
}

variable "account_d_name" {
  type    = string
  default = "bedrock-tenant-d"
}

variable "ou_name" {
  type    = string
  default = "bedrock-inference-dev"
}

variable "role_name" {
  type    = string
  default = "OrganizationAccountAccessRole"
}
