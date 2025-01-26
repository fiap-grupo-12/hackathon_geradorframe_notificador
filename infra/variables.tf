variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "A região AWS onde os recursos serão criados."
}

variable "sendgrid_api_key" {
  description = "SendGrid API Key"
  type        = string
}

variable "email_from" {
  description = "Email sender address"
  type        = string
}

variable "name_from" {
  description = "Email sender name"
  type        = string
}