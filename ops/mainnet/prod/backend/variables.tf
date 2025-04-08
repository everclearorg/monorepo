variable "region" {
  default = "us-west-2"
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
  default     = "mainnet"
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

variable "certificate_arn_mainnet" {
  default = "arn:aws:acm:us-west-2:679752396206:certificate/f075a99b-4908-45fc-8bb6-f17c2754e4f0"
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

variable "graph_api_key" {
  type      = string
  sensitive = true
}

variable "gelato_everclear_rpc_key" {
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

variable "drpc_key" {
  type      = string
  sensitive = true
  default   = "neverclear"
}


variable "alchemy_key" {
  type      = string
  sensitive = true
  default   = "neverclear"
}
