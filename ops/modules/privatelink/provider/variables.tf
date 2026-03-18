variable "environment" {
  description = "Environment name"
  type        = string
}

variable "stage" {
  description = "Stage of deployment"
  type        = string
}

variable "family" {
  description = "Service family name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the target service lives"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the NLB"
  type        = list(string)
}

variable "target_address" {
  description = "DNS address of the target service (resolved to IP for the NLB target group)"
  type        = string
}

variable "target_port" {
  description = "Port of the target service"
  type        = number
}
