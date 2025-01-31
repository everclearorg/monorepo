locals {

  base_domain              = "everclear.ninja"
  //TODO: Update with a friendly domain name
  default_db_endpoint      = "rds-postgres-cartographer-chimera.c2g2uuqedmjs.eu-west-1.rds.amazonaws.com"
  default_db_url           = "postgresql://${var.postgres_user}:${var.postgres_password}@${local.default_db_endpoint}:5432/everclear"

  lighthouse_intent_config_param_name = "lighthouse-intent-${var.environment}-${var.stage}-config"
  lighthouse_fill_config_param_name = "lighthouse-fill-${var.environment}-${var.stage}-config"
  lighthouse_settlement_config_param_name = "lighthouse-settlement-${var.environment}-${var.stage}-config"
  lighthouse_expired_config_param_name = "lighthouse-expired-${var.environment}-${var.stage}-config"
  lighthouse_invoice_config_param_name = "lighthouse-invoice-${var.environment}-${var.stage}-config"
  monitor_poller_config_param_name = "monitor-poller-${var.environment}-${var.stage}-config"

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
    { name = "DD_ENV", value = "${var.environment}-${var.stage}" },
  ]

  monitor_poller_env_vars = {
    ENVIRONMENT    = var.environment,
    STAGE          = var.stage,
    DD_LOGS_ENABLED   = true,
    DD_ENV         = "${var.environment}-${var.stage}"
    DD_API_KEY        = var.dd_api_key,
    DD_LAMBDA_HANDLER = "packages/agents/monitor/dist/lambda.handler"
  }

  lighthouse_env_vars = {
    ENVIRONMENT       = var.environment,
    STAGE             = var.stage,
    DD_LOGS_ENABLED   = true,
    DD_ENV            = "${var.environment}-${var.stage}",
    DD_API_KEY        = var.dd_api_key,
    DD_LAMBDA_HANDLER = "packages/agents/lighthouse/dist/index.handler"
    # To enable the graph API, uncomment the following line
    # GRAPH_API_KEY     = var.graph_api_key
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
    network = "testnet"
    environment = var.stage
    web3SignerUrl = "https://${module.relayer_web3signer.service_endpoint}"
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.staging.json"
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
    network = "testnet"
    environment = var.stage
    web3SignerUrl = "https://${module.watchtower_web3signer.service_endpoint}"
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.staging.json"
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
    // TODO: The following are the placeholder values for the watchtower config
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
    network = "testnet"
    environment = var.stage
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.staging.json"
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
    # betterUptime = {
    #   requesterEmail = var.betteruptime_requester_email
    #   apiKey = var.betteruptime_api_key
    # }
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
      averageElapsedEpochs = 6
      averageElapsedEpochsAlertAmount = 1000000000
      maxShadowExportDelay = 900
      maxShadowExportLatency = 10
      maxTokenomicsExportDelay = 1800
      maxTokenomicsExportLatency = 10
    }
    shadowTables = [
      "closedepochsprocessed",
      "depositenqueued",
      "depositprocessed",
      "finddepositdomain",
      "findinvoicedomain",
      "invoiceenqueued",
      "matchdeposit",
      "settledeposit",
      "settlementenqueued",
      "settlementqueueprocessed",
      "settlementsent"
    ]
    tokenomicsTables = [
        "bridge_in_error",
        "bridge_updated",
        "bridged_in",
        "bridged_lock",
        "bridged_lock_error",
        "bridged_out",
        "chain_gateway_added",
        "chain_gateway_removed",
        "early_exit",
        "eip712_domain_changed",
        "epoch_rewards_updated",
        "eth_withdrawn",
        "fee_info",
        "gateway_updated",
        "hub_gauge_updated",
        "lock_position",
        "mailbox_updated",
        "message_gas_limit_updated",
        "mint_message_sent",
        "new_lock_position",
        "ownership_transferred",
        "process_error",
        "retry_bridge_out",
        "retry_lock",
        "retry_message",
        "retry_mint",
        "retry_transfer",
        "return_fee_updated",
        "reward_claimed",
        "reward_metadata_updated",
        "rewards_claimed",
        "security_module_updated",
        "user",
        "vote_cast",
        "vote_delegated",
        "withdraw",
        "withdraw_eth"
    ]
  })

  local_lighthouse_config = jsonencode({
    logLevel = "debug"
    everclearConfig = "https://raw.githubusercontent.com/connext/chaindata/main/everclear.testnet.staging.json"
    environment = var.stage 
    network = "testnet"
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
      11155111 = { maxAge = 300, size = 10},
      97 = { maxAge = 300, size = 10 },
      421614 = { maxAge = 300, size = 10 },
      11155420 = { maxAge = 300, size = 10 }
    }
    database = { url = local.default_db_url }
    server = {
      adminToken = var.admin_token_lightouse
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
        ]
      }
      staking = {
        tokens = [
        ]
      }
    }
    safe = {
      txService = "https://transaction-testnet.safe.everclear.org/api"
      safeAddress = "0xd1463D828D8d8097DfD6788f364a2D6fDCBB84D4"
      signer = "${var.lighthouse_web3_signer_private_key}"
      masterCopyAddress = "0x29fcB43b46531BcA003ddC8FCB67FFE91900C762"
      fallbackHandlerAddress = "0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99"
    }
    betterUptime = {
      apiKey = var.betteruptime_api_key
      requesterEmail = var.betteruptime_requester_email
    }
  })
}
