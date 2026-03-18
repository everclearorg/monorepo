# VPC Interface Endpoint in the consumer VPC.
# Connects to a PrivateLink Endpoint Service in another VPC,
# giving local services a DNS name that routes traffic across VPCs.

resource "aws_security_group" "endpoint" {
  name        = "pl-endpoint-${var.environment}-${var.stage}-${var.family}"
  description = "Allow traffic to PrivateLink endpoint for ${var.family}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    Stage       = var.stage
  }
}

resource "aws_vpc_endpoint" "this" {
  vpc_id              = var.vpc_id
  service_name        = var.endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  private_dns_enabled = false

  security_group_ids = [aws_security_group.endpoint.id]

  tags = {
    Name        = "pl-endpoint-${var.environment}-${var.stage}-${var.family}"
    Environment = var.environment
    Stage       = var.stage
  }
}
