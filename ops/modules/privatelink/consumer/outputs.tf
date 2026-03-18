output "endpoint_dns_name" {
  description = "First DNS name of the VPC endpoint (regional entry per AWS convention)"
  value       = aws_vpc_endpoint.this.dns_entry[0].dns_name
}

output "endpoint_dns_entries" {
  description = "All DNS entries for the VPC endpoint — use to select a specific zonal or regional entry"
  value       = aws_vpc_endpoint.this.dns_entry[*].dns_name
}

output "endpoint_id" {
  description = "ID of the VPC endpoint"
  value       = aws_vpc_endpoint.this.id
}
