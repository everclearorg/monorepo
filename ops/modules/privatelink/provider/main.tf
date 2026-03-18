# NLB + VPC Endpoint Service in the provider VPC.
# Exposes a TCP service over PrivateLink so consumers in other VPCs can reach it.

# Service endpoints are typically DNS names; resolve to IP for the NLB target group.
# NOTE: IPs are resolved at apply-time only. If the underlying service changes IPs
# (e.g. ElastiCache failover), the NLB will still point at stale IPs until the next
# Terraform apply. Mitigations:
#   - The NLB health check (below) will mark stale targets as unhealthy.
#   - Schedule periodic `terraform apply` or trigger on health-check alarms.
data "dns_a_record_set" "target" {
  host = var.target_address
}

resource "aws_lb" "this" {
  name                             = "pl-nlb-${var.environment}-${var.stage}-${var.family}"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  enable_cross_zone_load_balancing = true

  tags = {
    Environment = var.environment
    Stage       = var.stage
  }
}

resource "aws_lb_target_group" "this" {
  name        = "pl-tg-${var.environment}-${var.stage}-${var.family}"
  port        = var.target_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = var.target_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Environment = var.environment
    Stage       = var.stage
  }
}

resource "aws_lb_target_group_attachment" "this" {
  for_each         = toset(data.dns_a_record_set.target.addrs)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = each.value
  port             = var.target_port
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.target_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.this.arn]

  tags = {
    Name        = "pl-svc-${var.environment}-${var.stage}-${var.family}"
    Environment = var.environment
    Stage       = var.stage
  }
}

resource "aws_vpc_endpoint_service_allowed_principal" "this" {
  for_each                = toset(var.allowed_principal_arns)
  vpc_endpoint_service_id = aws_vpc_endpoint_service.this.id
  principal_arn           = each.value
}
