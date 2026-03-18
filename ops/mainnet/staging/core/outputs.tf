output "relayer-service-endpoint" {
  value = module.relayer_server.service_endpoint
}

output "relayer-dns" {
  value = module.relayer.dns_name
}

output "rmq-management-endpoint" {
  value = module.centralised_message_queue.aws_mq_broker_console
}

output "rmq-amqps-endpoint" {
  value = module.centralised_message_queue.aws_mq_amqp_endpoint
}

# output "lighthouse_queue_redis_url" {
#   value     = "rediss://:${var.lighthouse_queue_redis_auth_token}@${module.lighthouse_queue_cache.redis_instance_address}:${module.lighthouse_queue_cache.redis_instance_port}"
#   sensitive = true
# }

# output "lighthouse_queue_endpoint_service_name" {
#   value = module.lighthouse_queue_privatelink.endpoint_service_name
# }

# output "lighthouse_queue_redis_port" {
#   value = module.lighthouse_queue_cache.redis_instance_port
# }

# output "lighthouse_queue_redis_auth_token" {
#   value     = var.lighthouse_queue_redis_auth_token
#   sensitive = true
# }

# output "lighthouse_queue_redis_address" {
#   value = module.lighthouse_queue_cache.redis_instance_address
# }
