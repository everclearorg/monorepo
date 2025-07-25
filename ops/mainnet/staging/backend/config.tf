locals {

  cartographer_depositors_config_param_name = "cartographer-depositors-${var.environment}-${var.stage}-config"
  cartographer_intents_config_param_name = "cartographer-intents-${var.environment}-${var.stage}-config"
  cartographer_invoices_config_param_name = "cartographer-invoices-${var.environment}-${var.stage}-config"
  cartographer_monitor_config_param_name = "cartographer-monitor-${var.environment}-${var.stage}-config"

  cartographer_env_vars = {
    DATABASE_URL        = "postgres://${var.postgres_user}:${var.postgres_password}@${module.cartographer_db.db_instance_endpoint}/everclear",
    ENVIRONMENT         = var.environment,
    EVERCLEAR_CONFIG    = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.mainnet.staging.json",
    STAGE               = var.stage,
    DD_ENV              = "${var.environment}-${var.stage}",
    DD_LOGS_ENABLED     = true,
    DD_API_KEY          = var.dd_api_key
    DD_LAMBDA_HANDLER   = "packages/agents/cartographer/poller/dist/index.handler"
    GRAPH_API_KEY       = var.graph_api_key 
  }

  postgrest_env_vars = [
    { name = "PGRST_ADMIN_SERVER_PORT", value = "3001" },
    { name = "PGRST_DB_URI", value = "postgres://${var.postgres_user}:${var.postgres_password}@${module.cartographer_db.db_instance_endpoint}/everclear" },
    { name = "PGRST_DB_SCHEMA", value = "public" },
    { name = "PGRST_DB_ANON_ROLE", value = "query" },
    { name = "PGRST_JWT_SECRET", value = "${var.postgrest_jwt_secret}"},
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "PGRST_DB_AGGREGATES_ENABLED", value = "true" }
  ]

  local_cartographer_config = jsonencode({
    logLevel = "debug"
    environment = "production" 
    databaseUrl = "postgres://${var.postgres_user}:${var.postgres_password}@${module.cartographer_db.db_instance_endpoint}/everclear"
    healthUrls = {
      intents     = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_intents_heartbeat}"
      invoices     = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_invoices_heartbeat}"
      depositors  = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_depositors_heartbeat}"
      monitor     = "https://uptime.betterstack.com/api/v1/heartbeat/${var.cartographer_monitor_heartbeat}"
    }
    hub = {
      domain = "25327",
      providers = [
        "https://rpc.everclear.raas.gelato.cloud/${var.gelato_everclear_rpc_key}"
      ]
    }
    chains = {
      "1" = {
        providers = [
          "https://eth-mainnet.blastapi.io/${var.blast_key}",
          "https://eth-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "10" = {
        providers = [
          "https://optimism-mainnet.blastapi.io/${var.blast_key}",
          "https://opt-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "42161" = {
      #   providers = [
      #     "https://arbitrum-one.blastapi.io/${var.blast_key}",
      #     "https://arb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
      #   ]
      # }
      "8453" = {
        providers = [
          "https://base-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://base-mainnet.blastapi.io/${var.blast_key}"
        ]
      }
      "1399811149" = {
        providers = [
          "https://api.mainnet-beta.solana.com"
        ],
        network = "solana"
      }
      "728126428" = {
        providers = [
          "https://api.trongrid.io?apiKey=${var.trongrid_api_key}"
        ],
        network = "tron"
      }
    }
  })
}
