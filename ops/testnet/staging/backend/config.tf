
locals {
  cartographer_env_vars = {
    CARTOGRAPHER_CONFIG = local.local_cartographer_config,
    DATABASE_URL        = "postgres://${var.postgres_user}:${var.postgres_password}@${module.cartographer_db.db_instance_endpoint}/everclear",
    ENVIRONMENT         = var.environment,
    EVERCLEAR_CONFIG    = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.staging.json",
    STAGE               = var.stage,
    DD_ENV              = "${var.environment}-${var.stage}",
    DD_LOGS_ENABLED     = true,
    DD_API_KEY          = var.dd_api_key
    DD_LAMBDA_HANDLER   = "packages/agents/cartographer/poller/dist/index.handler"
  }

  postgrest_env_vars = [
    { name = "PGRST_ADMIN_SERVER_PORT", value = "3001" },
    { name = "PGRST_DB_URI", value = "postgres://${var.postgres_user}:${var.postgres_password}@${module.cartographer_db_replica.db_instance_endpoint}/everclear" },
    { name = "PGRST_DB_SCHEMA", value = "public" },
    { name = "PGRST_DB_ANON_ROLE", value = "query" },
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "PGRST_DB_AGGREGATES_ENABLED", value = "true" }
  ]

  local_cartographer_config = jsonencode({
    logLevel = "debug"
    environment = var.stage
    databaseUrl = "postgres://${var.postgres_user}:${var.postgres_password}@${module.cartographer_db.db_instance_endpoint}/everclear"
    healthUrls = {
      intents     = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_intents_heartbeat}"
      invoices     = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_invoices_heartbeat}"
      depositors  = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_depositors_heartbeat}"
      monitor     = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_monitor_heartbeat}"
    }
    chains = {
      "11155111" = {
        providers = [
          "https://eth-sepolia.blastapi.io/${var.blast_key}"
        ]
      }
      "97" = {
        providers = [
          "https://bsc-testnet.blastapi.io/${var.blast_key}"
        ]
      }
      "421614" = {
        providers = [
          "https://arbitrum-sepolia.blastapi.io/${var.blast_key}"
        ]
      }
      "11155420" = {
        providers = [
          "https://optimism-sepolia.blastapi.io/${var.blast_key}"
        ]
      }
    }
  })
}
