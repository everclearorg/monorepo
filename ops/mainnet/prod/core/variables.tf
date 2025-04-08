variable "region" {
  default = "us-west-2"
}

variable "cidr_block" {
  default = "172.17.0.0/16"
}

variable "az_count" {
  default = "2"
}

variable "stage" {
  description = "stage of deployment"
  default     = "mainnet"
}

variable "environment" {
  description = "env we're deploying to"
  default     = "chimera"
}

variable "domain" {
  default = "core"
}

variable "lighthouse_image_tag" {
  type        = string
  description = "lighthouse image tag"
  default     = "latest"
}

variable "rmq_mgt_password" {
  type        = string
  description = "RabbitMQ management password"
  sensitive   = true
}

variable "rmq_mgt_user" {
  type        = string
  default     = "everclear"
  description = "RabbitMQ management user"
}



variable "certificate_arn_mainnet" {
  default = "arn:aws:acm:us-west-2:679752396206:certificate/f075a99b-4908-45fc-8bb6-f17c2754e4f0"
}


variable "blast_key" {
  type      = string
  sensitive = true
}

variable "drpc_key" {
  type      = string
  sensitive = true
  default   = "neverclear"
}

variable "alchemy_key" {
  type      = string
  sensitive = true
}

variable "infura_key" {
  type      = string
  sensitive = true
  default   = "neverclear"
}

variable "dd_api_key" {
  type      = string
  sensitive = true
}

variable "graph_api_key" {
  type      = string
  sensitive = true
}

variable "gelato_api_key" {
  type      = string
  sensitive = true
}

variable "gelato_everclear_rpc_key" {
  type      = string
  sensitive = true
}

variable "discord_webhook_token" {
  type      = string
  sensitive = true
  default = "neverclear"
}
variable "discord_webhook_id" {
  type      = string
  sensitive = true
  default = "everclear"
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "postgres_user" {
  type    = string
  default = "everclear"
}

variable "full_image_name_relayer" {
  type        = string
  description = "relayer image name"
  default     = "ghcr.io/connext/relayer:sha-64dc7c9"
}
variable "relayer_web3_signer_private_key" {
  type      = string
  sensitive = true
}

variable "full_image_name_watchtower" {
  type        = string
  description = "relayer image name"
  default     = "ghcr.io/connext/watchtower:sha-64dc7c9"
}

variable "full_image_name_monitor" {
  type        = string
  description = "monitor image name"
  default     = "ghcr.io/connext/monitor:sha-64dc7c9"
}

variable "full_image_name_monitor_poller" {
  type        = string
  description = "monitor image name"
  default     = "ghcr.io/connext/monitor:sha-64dc7c9"
}

variable "full_image_name_lighthouse" {
  type        = string
  description = "lighthouse image name"
  default     = "ghcr.io/connext/lighthouse:sha-64dc7c9"
}

variable "admin_token_lighthouse" {
  type      = string
  default   = "blahblah"
  sensitive = true
}


variable "admin_token_relayer" {
  type      = string
  default   = "blahblah"
  sensitive = true
}

variable "admin_token_watchtower" {
  type      = string
  default   = "blahblah"
  sensitive = true
}

variable "admin_token_monitor" {
  type      = string
  default   = "blahblah"
  sensitive = true
}

variable "lighthouse_web3_signer_private_key" {
  type      = string
  sensitive = true
}

variable "blockpi_key" {
  type      = string
  sensitive = true
  default   = "neverclear"
}

variable "watchtower_web3_signer_private_key" {
  type      = string
  sensitive = true
}

variable "lighthouse_intent_heartbeat" {
  type      = string
  sensitive = true
}

variable "lighthouse_fill_heartbeat" {
  type      = string
  sensitive = true
}

variable "lighthouse_settlement_heartbeat" {
  type      = string
  sensitive = true
}

variable "lighthouse_expired_heartbeat" {
  type      = string
  sensitive = true
}

variable "lighthouse_invoice_heartbeat" {
  type      = string
  sensitive = true
}

variable "lighthouse_reward_heartbeat" {
  type      = string
  sensitive = true
}

variable "lighthouse_reward_metadata_heartbeat" {
  type      = string
  sensitive = true
}

variable "monitor_poller_heartbeat" {
  type      = string
  sensitive = true
}

variable "relayer_poller_heartbeat" {
  type      = string
  sensitive = true
}

variable "betteruptime_requester_email" {
  type      = string
  sensitive = true
  default = "everclear"
}

variable "betteruptime_api_key" {
  type      = string
  sensitive = true
  default = "neverclear"
}

variable "telegram_chat_id" {
  type      = string
  sensitive = true
  default = "everclear"
}

variable "telegram_api_key" {
  type      = string
  sensitive = true
  default = "neverclear"
}

variable "coingecko_api_key" {
  type      = string
  sensitive = true
  default = "neverclear"
}
