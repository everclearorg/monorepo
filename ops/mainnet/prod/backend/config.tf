locals {

  cartographer_depositors_config_param_name = "cartographer-depositors-${var.environment}-${var.stage}-config"
  cartographer_intents_config_param_name = "cartographer-intents-${var.environment}-${var.stage}-config"
  cartographer_invoices_config_param_name = "cartographer-invoices-${var.environment}-${var.stage}-config"
  cartographer_monitor_config_param_name = "cartographer-monitor-${var.environment}-${var.stage}-config"

  cartographer_env_vars = {
    DATABASE_URL        = "postgres://${var.postgres_user}:${var.postgres_password}@${module.cartographer_db.db_instance_endpoint}/everclear",
    ENVIRONMENT         = var.environment,
    EVERCLEAR_CONFIG    = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.json",
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
          "https://eth-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "56" = {
        providers = [
          "https://bnb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "42161" = {
        providers = [
          "https://arb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "10" = {
        providers = [
          "https://opt-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "8453" = {
        providers = [
          "https://base-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "239" = {
        providers = [
          "https://rpc.ankr.com/tac/${var.ankr_key}",
          "https://rpc.tac.build"
        ]
      }
      "48900" = {
        providers = [
          "https://lb.drpc.live/zircuit-mainnet/${var.drpc_key}",
          "https://zircuit1-mainnet.p2pify.com"
        ]
      }
      "81457" = {
        providers = [
          "https://blast-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "59144" = {
        providers = [
          "https://linea-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "324" = {
        providers = [
          "https://zksync-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      },
      "137" = {
        providers = [
          "https://polygon-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "534352" = {
        providers = [
          "https://scroll-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "167000" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=taiko&dkey=${var.drpc_key}"
        ]
      }
      #      "33139" = {
      #        providers = [
      #          "https://apechain-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
      #        ]
      #      }
      "43114" = {
        providers = [
          "https://avax-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      },
      "34443" = {
        providers = [
          "https://mainnet.mode.network"
        ]
      },
      "130" = {
        providers = [
          "https://unichain-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      },
      "2020" = {
        providers = [
          "https://ronin-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://api.roninchain.com/rpc"
        ]
      },
      "1399811149" = {
        providers = [
          "https://mainnet.helius-rpc.com/?api-key=${var.helius_key}",
          "https://api.mainnet-beta.solana.com"
        ],
        network = "solana"
      },
      "80094" = {
        providers = [
          "https://berachain-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://rpc.berachain.com"
        ]
      },
      "5000" = {
        providers = [
          "https://mantle-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://mantle.drpc.org"
        ]
      },
      "146" = {
        providers = [
          "https://sonic-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://sonic.drpc.org"
        ]
      },
      "57073" = {
        providers = [
          "https://ink-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://ink.drpc.org"
        ]
      },
      "100" = {
        providers = [
          "https://gnosis-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      },
      "239" = {
        providers = [
          "https://rpc.ankr.com/tac",
          "https://rpc.tac.build"
        ]
      },
      "728126428" = {
        providers = [
          "https://api.trongrid.io?apiKey=${var.trongrid_api_key}"
        ],
        network = "tron"
      }
    }
  })
}
