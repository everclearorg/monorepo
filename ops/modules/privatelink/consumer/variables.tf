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
  description = "VPC ID where the consuming service lives"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the VPC endpoint"
  type        = list(string)
}

variable "endpoint_service_name" {
  description = "Service name of the VPC Endpoint Service (from the provider module output)"
  type        = string
}

variable "port" {
  description = "Port of the target service"
  type        = number
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the PrivateLink endpoint (e.g. VPC CIDR)"
  type        = list(string)
}
