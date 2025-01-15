# Cartographer

The Cartographer is a service that stores intent data to a persistent datastore. The data schema is bespoke for Everclear cross-chain intents and can facilitate use cases such as:

- Querying current state of intents (i.e. to get the status).
- Get intent history for a user.
- Network-wide analytics.

# Architecture

The Cartographer consists of multiple microservices:

- **Poller**: The poller service is responsible for querying subgraphs and storing intent data to a persistent datastore.
- **Postgrest**: The postgrest service is responsible for querying the persistent datastore and returning intent data through the REST API.

# Local Development

Refer to the individual microservice READMEs for more information.
