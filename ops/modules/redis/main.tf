
locals {
  use_replication_group = var.transit_encryption_enabled
}

# BullMQ requires maxmemory-policy = noeviction. The default ElastiCache
# parameter group uses volatile-lru, which can evict keys BullMQ depends on.
resource "aws_elasticache_parameter_group" "redis" {
  count  = var.maxmemory_policy != null ? 1 : 0
  name   = "redis-params-${var.environment}-${var.stage}-${var.family}"
  family = var.parameter_group_family

  parameter {
    name  = "maxmemory-policy"
    value = var.maxmemory_policy
  }

  tags = {
    Stage       = var.stage
    Environment = var.environment
  }
}

resource "aws_elasticache_cluster" "redis" {
  count           = local.use_replication_group ? 0 : 1
  cluster_id      = "redis-cluster-${var.environment}-${var.stage}-${var.family}"
  engine          = "redis"
  node_type       = var.node_type
  num_cache_nodes = 1
  parameter_group_name     = var.maxmemory_policy != null ? aws_elasticache_parameter_group.redis[0].name : null
  engine_version  = var.engine_version
  port                     = 6379
  subnet_group_name        = aws_elasticache_subnet_group.default.name
  security_group_ids       = [aws_security_group.redis.id]
  apply_immediately        = true
  snapshot_retention_limit = 0
  tags = {
    Stage       = var.stage
    Environment = var.environment
  }
}

resource "aws_elasticache_replication_group" "redis" {
  count                      = local.use_replication_group ? 1 : 0
  replication_group_id       = "redis-rg-${var.environment}-${var.stage}-${var.family}"
  description                = "Redis replication group for ${var.family} (${var.environment}-${var.stage})"
  node_type                  = var.node_type
  num_cache_clusters         = 1
  parameter_group_name       = var.maxmemory_policy != null ? aws_elasticache_parameter_group.redis[0].name : null
  engine_version             = var.engine_version
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.default.name
  security_group_ids         = [aws_security_group.redis.id]
  apply_immediately          = true
  snapshot_retention_limit   = 0
  transit_encryption_enabled = true
  auth_token                 = var.auth_token
  tags = {
    Stage       = var.stage
    Environment = var.environment
  }
}

resource "aws_elasticache_subnet_group" "default" {
  name       = "redis-subnet-group-${var.environment}-${var.stage}-${var.family}"
  subnet_ids = var.cache_subnet_group_subnet_ids
  lifecycle {
    create_before_destroy = true
  }
}
