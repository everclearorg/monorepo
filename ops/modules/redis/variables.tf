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

variable "maxmemory_policy" {
  description = "Redis maxmemory-policy. Set to 'noeviction' for BullMQ workloads. When null, the default parameter group is used."
  default     = null
  type        = string
}

variable "parameter_group_family" {
  description = "ElastiCache parameter group family (e.g. redis7, redis6.x). Must match the engine version."
  default     = "redis7"
  type        = string
}

variable "engine_version" {
  description = "Redis OSS engine_version for ElastiCache (e.g. 7.1). Must align with parameter_group_family (use redis7 for 7.x)."
  default     = "7.1"
  type        = string
}
