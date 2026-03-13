variable "sg_id" {
  type        = string
  description = "security group id of worker node sg"
}

variable "vpc_id" {
  type        = string
  description = "underlying vpc id"
}

variable "stage" {
  description = "stage of deployment"
}

variable "environment" {
  description = "env we're deploying to"
}

variable "family" {
  default = "sequencer"
}

variable "cache_subnet_group_subnet_ids" {
  description = "subnet group ids"
  type        = list(string)
}

variable "node_type" {
  description = "node type of redis cluster"
  default     = "cache.t2.small"
  type        = string
}

variable "public_redis" {
  description = "whether to make redis public"
  default     = false
  type        = bool
}

variable "auth_token" {
  description = "Auth token for Redis AUTH. Requires transit_encryption_enabled = true. When set, creates a replication group instead of a standalone cluster."
  default     = null
  type        = string
  sensitive   = true
}

variable "transit_encryption_enabled" {
  description = "Whether to enable TLS for in-transit encryption. Required when auth_token is set."
  default     = false
  type        = bool
}
