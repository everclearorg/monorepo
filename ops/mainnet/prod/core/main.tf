terraform {
  backend "s3" {
    bucket = "everclear-chimera-mainnet-core"
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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  repository_url_prefix = "${local.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/"
}

module "centralised_message_queue" {
  source              = "../../../modules/amq"
  stage               = var.stage
  environment         = var.environment
  sg_id               = module.network.ecs_task_sg
  vpc_id              = module.network.vpc_id
  zone_id             = data.aws_route53_zone.primary.zone_id
  publicly_accessible = true
  subnet_ids          = module.network.public_subnets
  rmq_mgt_user        = var.rmq_mgt_user
  rmq_mgt_password    = var.rmq_mgt_password
}


module "relayer" {
  source                   = "../../../modules/service"
  stage                    = var.stage
  environment              = var.environment
  domain                   = var.domain
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.public_subnets
  docker_image             = "${local.repository_url_prefix}chimera-relayer:${var.full_image_name_relayer}"
  container_family         = "relayer"
  health_check_path        = "/ping"
  container_port           = 8080
  loadbalancer_port        = 80
  cpu                      = 8192
  memory                   = 16384
  instance_count           = 1
  timeout                  = 180
  internal_lb              = false
  ingress_cdir_blocks      = [module.network.vpc_cdir_block]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_mainnet
  container_env_vars       = concat(local.relayer_env_vars, [{ name = "RELAYER_SERVICE", value = "poller" }])
}

module "relayer_server" {
  source                   = "../../../modules/service"
  stage                    = var.stage
  environment              = var.environment
  domain                   = var.domain
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.public_subnets
  docker_image             = "${local.repository_url_prefix}chimera-relayer:${var.full_image_name_relayer}"
  container_family         = "relayer-server"
  health_check_path        = "/ping"
  container_port           = 8080
  loadbalancer_port        = 80
  cpu                      = 1024
  memory                   = 4096
  instance_count           = 1
  timeout                  = 180
  internal_lb              = false
  ingress_cdir_blocks      = [module.network.vpc_cdir_block]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_mainnet
  container_env_vars       = concat(local.relayer_env_vars, [{ name = "RELAYER_SERVICE", value = "server" }])
}

module "relayer_web3signer" {
  source                   = "../../../modules/service"
  stage                    = var.stage
  environment              = var.environment
  domain                   = var.domain
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.private_subnets
  docker_image             = "ghcr.io/connext/web3signer:latest"
  container_family         = "relayer-web3signer"
  health_check_path        = "/upcheck"
  container_port           = 9000
  loadbalancer_port        = 80
  cpu                      = 256
  memory                   = 512
  instance_count           = 1
  timeout                  = 180
  internal_lb              = true
  ingress_cdir_blocks      = [module.network.vpc_cdir_block]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_mainnet
  container_env_vars       = local.relayer_web3signer_env_vars
}

module "watchtower" {
  source                   = "../../../modules/service"
  stage                    = var.stage
  environment              = var.environment
  domain                   = var.domain
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.public_subnets
  docker_image             = "${local.repository_url_prefix}chimera-watchtower:${var.full_image_name_watchtower}"
  container_family         = "watchtower"
  health_check_path        = "/ping"
  container_port           = 8080
  loadbalancer_port        = 80
  cpu                      = 1024 
  memory                   = 2048 
  instance_count           = 1
  timeout                  = 180
  internal_lb              = false
  ingress_cdir_blocks      = [module.network.vpc_cdir_block]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_mainnet
  container_env_vars       = local.watchtower_env_vars
}

module "watchtower_web3signer" {
  source                   = "../../../modules/service"
  stage                    = var.stage
  environment              = var.environment
  domain                   = var.domain
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.private_subnets
  docker_image             = "ghcr.io/connext/web3signer:latest"
  container_family         = "watchtower-web3signer"
  health_check_path        = "/upcheck"
  container_port           = 9000
  loadbalancer_port        = 80
  cpu                      = 256
  memory                   = 512
  instance_count           = 1
  timeout                  = 180
  internal_lb              = true
  ingress_cdir_blocks      = [module.network.vpc_cdir_block]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_mainnet
  container_env_vars       = local.watchtower_web3signer_env_vars
}

module "monitor" {
  source                   = "../../../modules/service"
  stage                    = var.stage
  environment              = var.environment
  domain                   = var.domain
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.public_subnets
  docker_image             = "${local.repository_url_prefix}chimera-monitor:${var.full_image_name_monitor}"
  container_family         = "monitor"
  health_check_path        = "/ping"
  container_port           = 8080
  loadbalancer_port        = 80
  cpu                      = 8192
  memory                   = 16384
  instance_count           = 1
  timeout                  = 180
  internal_lb              = false
  ingress_cdir_blocks      = [module.network.vpc_cdir_block]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_mainnet
  container_env_vars       = concat(local.monitor_env_vars, [{ name = "MONITOR_SERVICE", value = "server" }])
}


module "lighthouse_intent_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-lighthouse"
  docker_image_tag    = var.lighthouse_image_tag
  container_family    = "lighthouse-intent"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.lighthouse_intent_config_param_name
  container_env_vars  = merge(local.lighthouse_env_vars, {
    LIGHTHOUSE_SERVICE = "intent"
    CONFIG_PARAMETER_NAME = local.lighthouse_intent_config_param_name
  })
  schedule_expression    = "rate(1 minute)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_lighthouse_config
}

module "lighthouse_fill_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-lighthouse"
  docker_image_tag    = var.lighthouse_image_tag
  container_family    = "lighthouse-fill"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.lighthouse_fill_config_param_name
  container_env_vars  = merge(local.lighthouse_env_vars, {
    LIGHTHOUSE_SERVICE = "fill"
    CONFIG_PARAMETER_NAME = local.lighthouse_fill_config_param_name
  })
  schedule_expression    = "rate(3 minutes)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_lighthouse_config
}

module "lighthouse_settlement_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-lighthouse"
  docker_image_tag    = var.lighthouse_image_tag
  container_family    = "lighthouse-settlement"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.lighthouse_settlement_config_param_name
  container_env_vars  = merge(local.lighthouse_env_vars, {
    LIGHTHOUSE_SERVICE = "settlement"
    CONFIG_PARAMETER_NAME = local.lighthouse_settlement_config_param_name
  })
  schedule_expression    = "rate(1 minute)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_lighthouse_config
}

module "lighthouse_expired_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-lighthouse"
  docker_image_tag    = var.lighthouse_image_tag
  container_family    = "lighthouse-expired"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.lighthouse_expired_config_param_name
  container_env_vars  = merge(local.lighthouse_env_vars, {
    LIGHTHOUSE_SERVICE = "expired"
    CONFIG_PARAMETER_NAME = local.lighthouse_expired_config_param_name
  })
  schedule_expression    = "rate(10 minutes)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_lighthouse_config
}

module "lighthouse_invoice_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-lighthouse"
  docker_image_tag    = var.lighthouse_image_tag
  container_family    = "lighthouse-invoice"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.lighthouse_invoice_config_param_name
  container_env_vars  = merge(local.lighthouse_env_vars, {
    LIGHTHOUSE_SERVICE = "invoice"
    CONFIG_PARAMETER_NAME = local.lighthouse_invoice_config_param_name
  })
  schedule_expression    = "rate(1 minute)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_lighthouse_config
}

module "lighthouse_reward_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-lighthouse"
  docker_image_tag    = var.lighthouse_image_tag
  container_family    = "lighthouse-reward"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.lighthouse_reward_config_param_name
  container_env_vars  = merge(local.lighthouse_env_vars, {
    LIGHTHOUSE_SERVICE = "reward"
    CONFIG_PARAMETER_NAME = local.lighthouse_reward_config_param_name
  })
  schedule_expression    = "rate(1 day)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_lighthouse_config
}

module "lighthouse_reward_metadata_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-lighthouse"
  docker_image_tag    = var.lighthouse_image_tag
  container_family    = "lighthouse-reward_metadata"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.lighthouse_reward_metadata_config_param_name
  container_env_vars  = merge(local.lighthouse_env_vars, {
    LIGHTHOUSE_SERVICE = "reward_metadata"
    CONFIG_PARAMETER_NAME = local.lighthouse_reward_metadata_config_param_name
  })
  schedule_expression    = "rate(1 day)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_lighthouse_config
}

module "monitor_poller_cron" {
  source              = "../../../modules/lambda"
  ecr_repository_name = "chimera-monitor-poller"
  docker_image_tag    = var.full_image_name_monitor_poller
  container_family    = "monitor-poller"
  environment         = var.environment
  stage               = var.stage
  config_param_name   = local.monitor_poller_config_param_name
  container_env_vars  = merge(local.monitor_poller_env_vars, {
    MONITOR_SERVICE = "poller"
    CONFIG_PARAMETER_NAME = local.monitor_poller_config_param_name
  })
  schedule_expression    = "rate(10 minutes)"
  timeout                = 300
  memory_size            = 2048
  lambda_in_vpc          = true
  subnet_ids             = module.network.private_subnets
  lambda_security_groups = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  config                 = local.local_monitor_config
}


module "lighthouse_web3signer" {
  source                   = "../../../modules/service"
  stage                    = var.stage
  environment              = var.environment
  domain                   = var.domain
  region                   = var.region
  dd_api_key               = var.dd_api_key
  zone_id                  = data.aws_route53_zone.primary.zone_id
  execution_role_arn       = data.aws_iam_role.ecr_admin_role.arn
  cluster_id               = module.ecs.ecs_cluster_id
  vpc_id                   = module.network.vpc_id
  lb_subnets               = module.network.private_subnets
  docker_image             = "ghcr.io/connext/web3signer:latest"
  container_family         = "lighthouse-web3signer"
  health_check_path        = "/upcheck"
  container_port           = 9000
  loadbalancer_port        = 80
  cpu                      = 256
  memory                   = 512
  instance_count           = 1
  timeout                  = 180
  internal_lb              = true
  ingress_cdir_blocks      = [module.network.vpc_cdir_block]
  ingress_ipv6_cdir_blocks = []
  service_security_groups  = flatten([module.network.allow_all_sg, module.network.ecs_task_sg])
  cert_arn                 = var.certificate_arn_mainnet
  container_env_vars       = local.lighthouse_web3signer_env_vars
}

module "network" {
  source      = "../../../modules/networking"
  stage       = var.stage
  environment = var.environment
  domain      = var.domain
  cidr_block  = var.cidr_block
}

module "sgs" {
  source         = "../../../modules/sgs/core"
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

module "relayer_cache" {
  source                        = "../../../modules/redis"
  stage                         = var.stage
  environment                   = var.environment
  family                        = "relayer"
  sg_id                         = module.network.ecs_task_sg
  vpc_id                        = module.network.vpc_id
  cache_subnet_group_subnet_ids = module.network.public_subnets
  node_type                     = "cache.t3.small"
  public_redis                  = true
}

module "monitor_cache" {
  source                        = "../../../modules/redis"
  stage                         = var.stage
  environment                   = var.environment
  family                        = "monitor"
  sg_id                         = module.network.ecs_task_sg
  vpc_id                        = module.network.vpc_id
  cache_subnet_group_subnet_ids = module.network.public_subnets
  node_type                     = "cache.t3.small"
  public_redis                  = true
}

module "watchtower_cache" {
  source                        = "../../../modules/redis"
  stage                         = var.stage
  environment                   = var.environment
  family                        = "watchtower"
  sg_id                         = module.network.ecs_task_sg
  vpc_id                        = module.network.vpc_id
  cache_subnet_group_subnet_ids = module.network.public_subnets
  node_type                     = "cache.t3.small"
  public_redis                  = true
}
