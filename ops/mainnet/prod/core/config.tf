locals {

  base_domain              = "everclear.ninja"
  default_db_endpoint      = "rds-postgres-cartographer-chimera.c64s9irwuemi.us-west-2.rds.amazonaws.com"
  default_db_url           = "postgresql://${var.postgres_user}:${var.postgres_password}@${local.default_db_endpoint}:5432/everclear"

  relayer_env_vars = [
    { name = "RELAYER_CONFIG", value = local.local_relayer_config },
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "DD_PROFILING_ENABLED", value = "true" },
    { name = "DD_ENV", value = "${var.environment}-${var.stage}" },
  ]
  relayer_web3signer_env_vars = [
    { name = "WEB3_SIGNER_PRIVATE_KEY", value = var.relayer_web3_signer_private_key },
    { name = "WEB3SIGNER_HTTP_HOST_ALLOWLIST", value = "*" },
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "DD_ENV", value = "${var.environment}-${var.stage}" },
  ]
  
  monitor_env_vars = [
    { name = "MONITOR_CONFIG", value = local.local_monitor_config },
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "GRAPH_API_KEY", value = var.graph_api_key },
    { name = "DD_ENV", value = "${var.environment}-${var.stage}" },
  ]

  monitor_poller_env_vars = {
    MONITOR_CONFIG = local.local_monitor_config,
    ENVIRONMENT    = var.environment,
    STAGE          = var.stage,
    DD_LOGS_ENABLED   = true,
    DD_ENV         = "${var.environment}-${var.stage}"
    DD_API_KEY        = var.dd_api_key,
    DD_LAMBDA_HANDLER = "packages/agents/monitor/dist/lambda.handler"
    GRAPH_API_KEY     = var.graph_api_key 
  }

  lighthouse_env_vars = {
    LIGHTHOUSE_CONFIG = local.local_lighthouse_config,
    ENVIRONMENT       = var.environment,
    STAGE             = var.stage,
    DD_LOGS_ENABLED   = true,
    DD_ENV            = "${var.environment}-${var.stage}",
    DD_API_KEY        = var.dd_api_key,
    DD_LAMBDA_HANDLER = "packages/agents/lighthouse/dist/index.handler"
    GRAPH_API_KEY     = var.graph_api_key 
  }
  
  lighthouse_web3signer_env_vars = [
    { name = "WEB3_SIGNER_PRIVATE_KEY", value = var.lighthouse_web3_signer_private_key },
    { name = "WEB3SIGNER_HTTP_HOST_ALLOWLIST", value = "*" },
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "DD_ENV", value = "${var.environment}-${var.stage}" },
  ]

  watchtower_env_vars = [
    { name = "WATCHTOWER_CONFIG", value = local.local_watchtower_config },
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "GRAPH_API_KEY", value = var.graph_api_key },
    { name = "DD_PROFILING_ENABLED", value = "true" },
    { name = "DD_ENV", value = "${var.environment}-${var.stage}" },
  ]

  watchtower_web3signer_env_vars = [
    { name = "WEB3_SIGNER_PRIVATE_KEY", value = var.watchtower_web3_signer_private_key },
    { name = "WEB3SIGNER_HTTP_HOST_ALLOWLIST", value = "*" },
    { name = "ENVIRONMENT", value = var.environment },
    { name = "STAGE", value = var.stage },
    { name = "DD_ENV", value = "${var.environment}-${var.stage}" },
  ]
}

locals {

  local_relayer_config = jsonencode({
    logLevel = "debug"
    network = "mainnet"
    environment = "production" 
    web3SignerUrl = "https://${module.relayer_web3signer.service_endpoint}"
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.json"
    chains = {
      "1" = {
        providers = [
          "https://eth-mainnet.blastapi.io/${var.blast_key}",
          "https://eth-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "56" = {
        providers = [
          "https://bsc-mainnet.blastapi.io/${var.blast_key}",
          "https://bnb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "42161" = {
        providers = [
          "https://arbitrum-one.blastapi.io/${var.blast_key}",
          "https://arb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "10" = {
        providers = [
          "https://optimism-mainnet.blastapi.io/${var.blast_key}",
          "https://opt-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "8453" = {
        providers = [
          "https://base-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://base-mainnet.blastapi.io/${var.blast_key}"
        ]
      }
      "48900" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=zircuit-mainnet&dkey=${var.drpc_key}",
          "https://zircuit1-mainnet.p2pify.com"
        ]
      }
      "81457" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=blast&dkey=${var.drpc_key}",
          "https://blastl2-mainnet.public.blastapi.io"
        ]
      }
      "59144" = {
        providers = [
          "https://linea-mainnet.blastapi.io/${var.blast_key}",
          "https://linea-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "324" = {
      #   providers = [
      #     "https://1rpc.io/zksync2-era",
      #     "https://zksync-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      "137" = {
        providers = [
          "https://polygon-mainnet.blastapi.io/${var.blast_key}",
          "https://polygon-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "534352" = {
      #   providers = [
      #     "https://scroll.drpc.org",
      #     "https://scroll-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      # "167000" = {
      #   providers = [
      #     "https://taiko.drpc.org",
      #     "https://lb.drpc.org/ogrpc?network=taiko&dkey=${var.drpc_key}"
      #   ]
      # }
      "43114" = {
        providers = [
          "https://ava-mainnet.blastapi.io/${var.blast_key}/ext/bc/C/rpc",
          "https://avalanche-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
    }
    server = {
      port = 8080
      adminToken = var.admin_token_relayer
    }
    poller = {
      port = 8080
      adminToken = var.admin_token_relayer
    }
    redis = {
      host = module.relayer_cache.redis_instance_address
      port = module.relayer_cache.redis_instance_port
    }
    healthUrls = {
      poller = "https://uptime.betterstack.com/api/v1/heartbeat/${var.relayer_poller_heartbeat}"
    }
  })

  local_watchtower_config = jsonencode({
    logLevel = "debug"
    network = "mainnet"
    environment = "production" 
    web3SignerUrl = "https://${module.watchtower_web3signer.service_endpoint}"
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.json"
    chains = {
      "1" = {
        providers = [
          "https://eth-mainnet.blastapi.io/${var.blast_key}",
          "https://eth-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "56" = {
        providers = [
          "https://bsc-mainnet.blastapi.io/${var.blast_key}",
          "https://bnb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "42161" = {
        providers = [
          "https://arbitrum-one.blastapi.io/${var.blast_key}",
          "https://arb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "10" = {
        providers = [
          "https://optimism-mainnet.blastapi.io/${var.blast_key}",
          "https://opt-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "8453" = {
        providers = [
          "https://base-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://base-mainnet.blastapi.io/${var.blast_key}"
        ]
      }
      "48900" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=zircuit-mainnet&dkey=${var.drpc_key}",
          "https://zircuit1-mainnet.p2pify.com"
        ]
      }
      "81457" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=blast&dkey=${var.drpc_key}",
          "https://blastl2-mainnet.public.blastapi.io"
        ]
      }
      "59144" = {
        providers = [
          "https://linea-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://linea-mainnet.blastapi.io/${var.blast_key}"
        ]
      }
      # "324" = {
      #   providers = [
      #     "https://1rpc.io/zksync2-era",
      #     "https://zksync-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      "137" = {
        providers = [
          "https://polygon-mainnet.blastapi.io/${var.blast_key}",
          "https://polygon-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "534352" = {
      #   providers = [
      #     "https://scroll.drpc.org",
      #     "https://scroll-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      # "167000" = {
      #   providers = [
      #     "https://taiko.drpc.org",
      #     "https://lb.drpc.org/ogrpc?network=taiko&dkey=${var.drpc_key}"
      #   ]
      # }
      "43114" = {
        providers = [
          "https://ava-mainnet.blastapi.io/${var.blast_key}/ext/bc/C/rpc",
          "https://avalanche-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
    }
    server = {
      port = 8080
      adminToken = var.admin_token_watchtower
    }
    poller = {
      port = 8081
      adminToken = var.admin_token_watchtower
    }
    redis = {
      host = module.watchtower_cache.redis_instance_address
      port = module.watchtower_cache.redis_instance_port
    }
    reloadConfigInterval = 200000
    assetCheckInterval = 500000
    discordHookUrl = "https://discord.com/api/webhooks/${var.discord_webhook_id}/${var.discord_webhook_token}",
    twilioNumber = "123456"
    twilioAccountSid = ""
    twilioAuthToken = ""
    twilioToPhoneNumbers = []
    betterUptimeApiKey = ""
    betterUptimeRequesterEmail = ""
    failedCheckRetriesLimit = 1
  })

  local_monitor_config = jsonencode({
    logLevel = "debug"
    network = "mainnet"
    environment = "production" 
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.json"
    chains = {
      "1" = {
        providers = [
          "https://eth-mainnet.blastapi.io/${var.blast_key}",
          "https://eth-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "56" = {
        providers = [
          "https://bsc-mainnet.blastapi.io/${var.blast_key}",
          "https://bnb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "42161" = {
        providers = [
          "https://arbitrum-one.blastapi.io/${var.blast_key}",
          "https://arb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "10" = {
        providers = [
          "https://optimism-mainnet.blastapi.io/${var.blast_key}",
          "https://opt-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "8453" = {
        providers = [
          "https://base-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://base-mainnet.blastapi.io/${var.blast_key}"
        ]
      }
      "48900" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=zircuit-mainnet&dkey=${var.drpc_key}",
          "https://zircuit1-mainnet.p2pify.com"
        ]
      }
      "81457" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=blast&dkey=${var.drpc_key}",
          "https://blastl2-mainnet.public.blastapi.io"
        ]
      }
      "59144" = {
        providers = [
          "https://linea-mainnet.blastapi.io/${var.blast_key}",
          "https://linea-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "324" = {
      #   providers = [
      #     "https://1rpc.io/zksync2-era",
      #     "https://zksync-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      "137" = {
        providers = [
          "https://polygon-mainnet.blastapi.io/${var.blast_key}",
          "https://polygon-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "534352" = {
      #   providers = [
      #     "https://scroll.drpc.org",
      #     "https://scroll-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      # "167000" = {
      #   providers = [
      #     "https://taiko.drpc.org",
      #     "https://lb.drpc.org/ogrpc?network=taiko&dkey=${var.drpc_key}"
      #   ]
      # }
      "43114" = {
        providers = [
          "https://ava-mainnet.blastapi.io/${var.blast_key}/ext/bc/C/rpc",
          "https://avalanche-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
    }
    betterUptime = {
      requesterEmail = var.betteruptime_requester_email
      apiKey = var.betteruptime_api_key
    }
    server = {
      port = 8080
      adminToken = var.admin_token_monitor
    }
    redis = {
      host = module.monitor_cache.redis_instance_address
      port = module.monitor_cache.redis_instance_port
    }
    relayers = [
      {
        type   = "Gelato",
        apiKey = "${var.gelato_api_key}",
        url    = "https://relay.gelato.digital"
      },
      {
        type   = "Everclear",
        apiKey = "${var.admin_token_relayer}",
        url    = "https://${module.relayer_server.service_endpoint}"
      }
    ]
    agents = {
      relayer = "https://${module.relayer_server.service_endpoint}/ping"
      monitor = "https://${module.monitor.service_endpoint}/ping"
      lighthouseSigner = "https://${module.lighthouse_web3signer.service_endpoint}/upcheck"
      relayerSigner = "https://${module.relayer_web3signer.service_endpoint}/upcheck"
      watchtowerSigner = "https://${module.watchtower_web3signer.service_endpoint}/upcheck"
    }
    healthUrls = {
      poller = "https://uptime.betterstack.com/api/v1/heartbeat/${var.monitor_poller_heartbeat}"
    }
    database = {
      url = local.default_db_url
    }
    thresholds = {
      maxIntentQueueCount = 15
      maxIntentQueueLatency = 2400
      maxSettlementQueueCount = 15
      maxSettlementQueueLatency = 2400
      maxDepositQueueCount = 15
      maxDepositQueueLatency = 3600
      messageMaxDelay = 1800
      maxDelayedSubgraphBlock = 250
      maxInvoiceProcessingTime = 64800
      minGasOnRelayer = 0.3
      minGasOnGateway = 0.5
      averageElapsedEpochs = 6
      averageElapsedEpochsAlertAmount = 10000
      maxShadowExportDelay = 900
      maxShadowExportLatency = 10
      maxTokenomicsExportDelay = 1800
      maxTokenomicsExportLatency = 10
    }
  })

  local_lighthouse_config = jsonencode({
    logLevel = "debug"
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.json"
    environment = "production"
    network = "mainnet"
    relayers = [
      {
        type   = "Gelato",
        apiKey = "${var.gelato_api_key}",
        url    = "https://relay.gelato.digital"
      },
      {
        type   = "Everclear",
        apiKey = "${var.admin_token_relayer}",
        url    = "https://${module.relayer_server.service_endpoint}"
      }
    ]
    thresholds = {
      1 = { maxAge = 60, size = 1 },
      56 = { maxAge = 60, size = 1 },
      42161 = { maxAge = 60, size = 1 },
      10 = { maxAge = 60, size = 1 },
      8453 = { maxAge = 60, size = 1 },
      48900 = { maxAge = 60, size = 1 },
      25327 = { maxAge = 60, size = 1 },
      81457 = { maxAge = 60, size = 1 },
    }
    chains = {
      "1" = {
        providers = [
          "https://eth-mainnet.blastapi.io/${var.blast_key}",
          "https://eth-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "56" = {
        providers = [
          "https://bsc-mainnet.blastapi.io/${var.blast_key}",
          "https://bnb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "42161" = {
        providers = [
          "https://arbitrum-one.blastapi.io/${var.blast_key}",
          "https://arb-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "10" = {
        providers = [
          "https://optimism-mainnet.blastapi.io/${var.blast_key}",
          "https://opt-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      "8453" = {
        providers = [
          "https://base-mainnet.g.alchemy.com/v2/${var.alchemy_key}",
          "https://base-mainnet.blastapi.io/${var.blast_key}"
        ]
      }
      "48900" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=zircuit-mainnet&dkey=${var.drpc_key}",
          "https://zircuit1-mainnet.p2pify.com"
        ]
      }
      "81457" = {
        providers = [
          "https://lb.drpc.org/ogrpc?network=blast&dkey=${var.drpc_key}",
          "https://blastl2-mainnet.public.blastapi.io"
        ]
      }
      "59144" = {
        providers = [
          "https://linea-mainnet.blastapi.io/${var.blast_key}",
          "https://linea-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "324" = {
      #   providers = [
      #     "https://1rpc.io/zksync2-era",
      #     "https://zksync-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      "137" = {
        providers = [
          "https://polygon-mainnet.blastapi.io/${var.blast_key}",
          "https://polygon-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
      # "534352" = {
      #   providers = [
      #     "https://scroll.drpc.org",
      #     "https://scroll-mainnet.blastapi.io/${var.blast_key}"
      #   ]
      # }
      # "167000" = {
      #   providers = [
      #     "https://taiko.drpc.org",
      #     "https://lb.drpc.org/ogrpc?network=taiko&dkey=${var.drpc_key}"
      #   ]
      # }
      "43114" = {
        providers = [
          "https://ava-mainnet.blastapi.io/${var.blast_key}/ext/bc/C/rpc",
          "https://avalanche-mainnet.g.alchemy.com/v2/${var.alchemy_key}"
        ]
      }
    }
    database = { url = local.default_db_url }
    server = {
      adminToken = var.admin_token_lighthouse
    }
    signer = "https://${module.lighthouse_web3signer.service_endpoint}"
    healthUrls = {
      intent           = "${var.lighthouse_intent_heartbeat}"
      fill             = "${var.lighthouse_fill_heartbeat}"
      settlement       = "${var.lighthouse_settlement_heartbeat}"
      expired          = "${var.lighthouse_expired_heartbeat}"
      invoice          = "${var.lighthouse_invoice_heartbeat}"
      reward           = "${var.lighthouse_reward_heartbeat}"
      reward_metadata  = "${var.lighthouse_reward_metadata_heartbeat}"
    }
    coingecko = "${var.coingecko_api_key}"
    rewards = {
      clearAssetAddress = "0x58b9cb810a68a7f3e1e4f8cb45d1b9b3c79705e8"
      volume = {
        tokens = [
          {
            address = "0x58b9cb810a68a7f3e1e4f8cb45d1b9b3c79705e8"
          }
        ]
      }
      staking = {
        tokens = [
          {
            address = "0x58b9cb810a68a7f3e1e4f8cb45d1b9b3c79705e8"
          },
          {
            address = "0x2e31ebd2eb114943630db6ba8c7f7687bda5835f"
          }
        ]
      }
    }
    safe = {
      txService = "https://transaction.safe.everclear.org/api"
      safeAddress = "0xac7599880cB5b5eCaF416BEE57C606f15DA5beB8"
      signer = "${var.lighthouse_web3_signer_private_key}"
      masterCopyAddress = "0xfb1bffC9d739B8D520DaF37dF666da4C687191EA"
      fallbackHandlerAddress = "0x017062a1dE2FE6b99BE3d9d37841FeD19F573804"
    }
    betterUptime = {
      apiKey = var.betteruptime_api_key
      requesterEmail = var.betteruptime_requester_email
    }
  })
}
