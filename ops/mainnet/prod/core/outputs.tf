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
