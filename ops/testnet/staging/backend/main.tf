terraform {
  backend "s3" {
    bucket = "connext-chimera-testnet-staging-backend"
    key    = "state"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

data "aws_iam_role" "ecr_admin_role" {
  name = "erc_admin_role"
}


data "aws_route53_zone" "primary" {
  zone_id = "Z03634792TWUEHHQ5L0YX"
}

locals {
  db_alarm_emails = ["preetham@proximalabs.io", "wang@proximalabs.io", "layne@proximalabs.io"]
}

module "cartographer_db" {
  domain                = "cartographer"
  source                = "../../../modules/db"
  identifier            = "rds-postgres-cartographer-${var.environment}"
  instance_class        = "db.t4g.large"
  allocated_storage     = 150
  max_allocated_storage = 180

  name     = "everclear" // db name
  username = var.postgres_user
  password = var.postgres_password
  port     = "5432"

  maintenance_window = "Mon:00:00-Mon:03:00"

  tags = {
    Environment = var.environment
    Domain      = var.domain
  }

  vpc_id = module.network.vpc_id

  hosted_zone_id             = data.aws_route53_zone.primary.zone_id
  stage                      = var.stage
  environment                = var.environment
  db_security_group_id       = module.sgs.rds_sg_id
  db_subnet_group_subnet_ids = module.network.public_subnets
  publicly_accessible        = true
}

module "cartographer-db-alarms" {
  source                                  = "../../../modules/db-alarms"
  db_instance_name                        = module.cartographer_db.db_instance_name
  db_instance_id                          = module.cartographer_db.db_instance_id
  is_replica                              = false
  enable_cpu_utilization_alarm            = true
  enable_free_storage_space_too_low_alarm = true
  enable_transaction_logs_disk_usage_alarm = true
  stage                                   = var.stage
  environment                             = var.environment
  sns_topic_subscription_emails           = local.db_alarm_emails
}

module "cartographer_db_replica" {
  domain              = "cartographer"
  source              = "../../../modules/db-replica"
  replicate_source_db = module.cartographer_db.db_instance_identifier
  depends_on          = [module.cartographer_db]
  replica_identifier  = "rds-postgres-cartographer-replica-${var.environment}"
  instance_class      = "db.t4g.large"
  allocated_storage   = 25
  max_allocated_storage = 180

  name     = module.cartographer_db.db_instance_name
  username = module.cartographer_db.db_instance_username
  password = module.cartographer_db.db_instance_password
  port     = module.cartographer_db.db_instance_port

  engine_version = module.cartographer_db.db_instance_engine_version

  maintenance_window      = module.cartographer_db.db_maintenance_window
  backup_retention_period = module.cartographer_db.db_backup_retention_period
  backup_window           = module.cartographer_db.db_backup_window

  tags = {
    Environment = var.environment
    Domain      = var.domain
  }

  parameter_group_name = "rds-postgres"

  hosted_zone_id        = data.aws_route53_zone.primary.zone_id
  stage                 = var.stage
  environment           = var.environment
  db_security_group_ids = module.cartographer_db.db_instance_vpc_security_group_ids
  db_subnet_group_name  = module.cartographer_db.db_subnet_group_name
  publicly_accessible   = module.cartographer_db.db_publicly_accessible
}

module "cartographer-db-replica-alarms" {
  source                                  = "../../../modules/db-alarms"
  db_instance_name                        = module.cartographer_db.db_instance_name
  db_instance_id                          = module.cartographer_db.db_instance_id
  is_replica                              = true
  enable_cpu_utilization_alarm            = true
  enable_free_storage_space_too_low_alarm = true
  enable_transaction_logs_disk_usage_alarm = true
  stage                                   = var.stage
  environment                             = var.environment
  sns_topic_subscription_emails           = local.db_alarm_emails
}

module "postgrest" {
  source                   = "../../../modules/service"
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.public_subnets
  internal_lb              = false
  docker_image             = "postgrest/postgrest:v12.0.2"
  container_family         = "postgrest"
  container_port           = 3000
  loadbalancer_port        = 80
  cpu                      = 1024
  memory                   = 2048
  instance_count           = 2
  timeout                  = 180
  environment              = var.environment
  stage                    = var.stage
  ingress_cdir_blocks      = ["0.0.0.0/0"]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_testnet
  container_env_vars       = local.postgrest_env_vars
  domain                   = var.domain
}

module "cartographer-depositors-lambda-cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-cartographer"
  docker_image_tag    = var.cartographer_image_tag
  container_family    = "cartographer-depositors"
  environment         = var.environment
  stage               = var.stage
  container_env_vars  = merge(local.cartographer_env_vars, { CARTOGRAPHER_SERVICE = "depositors" })
  schedule_expression = "rate(1 minute)"
  memory_size         = 1024
}

module "cartographer-intents-lambda-cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-cartographer"
  docker_image_tag    = var.cartographer_image_tag
  container_family    = "cartographer-intents"
  environment         = var.environment
  stage               = var.stage
  container_env_vars  = merge(local.cartographer_env_vars, { CARTOGRAPHER_SERVICE = "intents" })
  schedule_expression = "rate(1 minute)"
  memory_size         = 1024
}

module "cartographer-invoices-lambda-cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-cartographer"
  docker_image_tag    = var.cartographer_image_tag
  container_family    = "cartographer-invoices"
  environment         = var.environment
  stage               = var.stage
  container_env_vars  = merge(local.cartographer_env_vars, { CARTOGRAPHER_SERVICE = "invoices" })
  schedule_expression = "rate(1 minute)"
  memory_size         = 1024
}

module "cartographer-monitor-lambda-cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-cartographer"
  docker_image_tag    = var.cartographer_image_tag
  container_family    = "cartographer-monitor"
  environment         = var.environment
  stage               = var.stage
  container_env_vars  = merge(local.cartographer_env_vars, { CARTOGRAPHER_SERVICE = "monitor" })
  schedule_expression = "rate(1 minute)"
  memory_size         = 1024
}


module "network" {
  source      = "../../../modules/networking"
  cidr_block  = var.cidr_block
  environment = var.environment
  stage       = var.stage
  domain      = var.domain

}

module "sgs" {
  source         = "../../../modules/sgs/backend"
  environment    = var.environment
  stage          = var.stage
  domain         = var.domain
  ecs_task_sg_id = module.network.ecs_task_sg
  vpc_cdir_block = module.network.vpc_cdir_block
  vpc_id         = module.network.vpc_id
}


module "ecs" {
  source                  = "../../../modules/ecs"
  stage                   = var.stage
  environment             = var.environment
  domain                  = var.domain
  ecs_cluster_name_prefix = "connext-ecs"
}
