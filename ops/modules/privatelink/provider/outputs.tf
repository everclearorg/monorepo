output "endpoint_service_name" {
  description = "Service name of the VPC Endpoint Service — pass this to the consumer module"
  value       = aws_vpc_endpoint_service.this.service_name
}

output "nlb_arn" {
  description = "ARN of the internal NLB"
  value       = aws_lb.this.arn
}
