
locals {
  use_replication_group = var.transit_encryption_enabled
}

resource "aws_elasticache_cluster" "redis" {
  count           = local.use_replication_group ? 0 : 1
  cluster_id      = "redis-cluster-${var.environment}-${var.stage}-${var.family}"
  engine          = "redis"
  node_type       = var.node_type
  num_cache_nodes = 1
  # parameter_group_name = "default.redis6.x"
  # engine_version           = "6.x"
  port                     = 6379
  subnet_group_name        = aws_elasticache_subnet_group.default.name
  security_group_ids       = [aws_security_group.redis.id]
  apply_immediately        = true
  snapshot_retention_limit = 0
  tags = {
    Stage       = var.stage
    Environment = var.environment
  }

  lifecycle {
    precondition {
      condition     = var.auth_token == null
      error_message = "Redis auth_token requires transit_encryption_enabled = true."
    }
  }
}

resource "aws_elasticache_replication_group" "redis" {
  count                      = local.use_replication_group ? 1 : 0
  replication_group_id       = "redis-rg-${var.environment}-${var.stage}-${var.family}"
  description                = "Redis replication group for ${var.family} (${var.environment}-${var.stage})"
  node_type                  = var.node_type
  num_cache_clusters         = 1
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
