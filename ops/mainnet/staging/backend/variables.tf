variable "region" {
  default = "us-east-1"
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

# TODO: Remove once lambda decommission is complete
variable "cartographer_image_tag" {
  type        = string
  description = "cartographer poller image tag (deprecated - lambdas replaced by handler)"
  default     = "latest"
}

variable "full_image_name_sdk_server" {
  type        = string
  description = "sdk-server image name"
  default     = "latest"
}

variable "certificate_arn_mainnet" {
  default = "arn:aws:acm:us-east-1:679752396206:certificate/8b29921c-d3d1-46f6-995d-03e590389841"
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_user" {
  type    = string
  default = "everclear"
}

variable "postgrest_jwt_secret" {
  type    = string
  default = "neverclear"
}

variable "dd_api_key" {
  type      = string
  sensitive = true
}

# TODO: Remove once lambda decommission is complete
variable "graph_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "gelato_everclear_rpc_key" {
  type      = string
  sensitive = true
}

# TODO: Remove once lambda decommission is complete
variable "cartographer_intents_heartbeat" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cartographer_invoices_heartbeat" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cartographer_depositors_heartbeat" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cartographer_monitor_heartbeat" {
  type      = string
  sensitive = true
  default   = ""
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

variable "ankr_key" {
  type      = string
  sensitive = true
}

variable "helius_key" {
  type      = string
  sensitive = true
}

variable "trongrid_api_key" {
  type      = string
  sensitive = true
  default   = "neverclear"
}

variable "cartographer_handler_image_tag" {
  type        = string
  description = "cartographer handler image tag"
  default     = "latest"
}

variable "goldsky_webhook_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cartographer_handler_heartbeat" {
  type      = string
  sensitive = true
  default   = ""
}
