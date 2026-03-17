
output "redis_instance_arn" {
  description = "ARN of the created elastic cache cluster"
  value = local.use_replication_group ? aws_elasticache_replication_group.redis[0].arn : aws_elasticache_cluster.redis[0].arn
}

output "redis_instance_address" {
  description = "The redis address"
  value = local.use_replication_group ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : aws_elasticache_cluster.redis[0].cache_nodes[0].address
}

output "redis_instance_port" {
  description = "The database port"
  value = local.use_replication_group ? aws_elasticache_replication_group.redis[0].port : aws_elasticache_cluster.redis[0].cache_nodes[0].port
}
