output "endpoint_dns_name" {
  description = "DNS name of the VPC endpoint — use as the host for cross-VPC clients"
  value       = aws_vpc_endpoint.this.dns_entry[0].dns_name
}

output "endpoint_id" {
  description = "ID of the VPC endpoint"
  value       = aws_vpc_endpoint.this.id
}
