## AWS Infrastructure

This folder contains all the code necessary to deploy off-chain components to a highly-available
ecs cluster, with its required dependencies. Namely:

- Fully configured load balancing, port forwarding, and TLS
- Autoscaling with ECS on [Fargate](https://aws.amazon.com/fargate/)
- testnet/staging/mainnet environment automatic set up and deployment with GH Actions
- Reusable Infrastructure as Code, modularized as Terraform components

## Scaffolding

```text
 ├── infra           <- Cross-environment infrastructure
 ├── testnet          <- Testnet set up
 └── modules
      ├── service    <- Generic, configurable ECS service
      ├── ecs        <- ECS cluster definition
      ├── iam        <- IAM roles needed for ECS
      ├── redis      <- ElastiCache cluster
      └── networking <- VPCs, Subnets and all those shenanigans

```

## Deployment & Usage

**TODO**