variable "region" {
  default = "eu-west-1"
}

variable "cidr_block" {
  default = "172.17.0.0/16"
}

variable "az_count" {
  default = "2"
}

variable "domain" {
  description = "domain of deployment"
  default     = "backend"
}

variable "stage" {
  description = "stage of deployment"
  default     = "staging"
}

variable "environment" {
  description = "env we're deploying to"
  default     = "chimera"
}

variable "cartographer_image_tag" {
  type        = string
  description = "cartographer image tag"
  default     = "latest"
}

variable "full_image_name_sdk_server" {
  type        = string
  description = "sdk-server image name"
  default     = "latest"
}

variable "certificate_arn_testnet" {
  default = "arn:aws:acm:eu-west-1:679752396206:certificate/2693cdbc-986b-4fce-bd38-33ae429da186"
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_user" {
  type    = string
  default = "everclear"
}

variable "dd_api_key" {
  type      = string
  sensitive = true
}

variable "cartographer_intents_heartbeat" {
  type      = string
  sensitive = true
}

variable "cartographer_invoices_heartbeat" {
  type      = string
  sensitive = true
}

variable "cartographer_depositors_heartbeat" {
  type      = string
  sensitive = true
}

variable "cartographer_monitor_heartbeat" {
  type      = string
  sensitive = true
}

variable "blast_key" {
  type      = string
  sensitive = true
  default   = "neverclear"
}
