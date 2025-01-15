# Local Setup

- Create `config.json` to indicate chains and optionally override subgraph URLs:

```json
{
  "logLevel": "debug",
  "chains": {
    "1": {},
    "10": {},
    "420": {}
  },
  "environment": "staging",
  "databaseUrl": "postgres://postgres:postgres@localhost:5432/everclear"
}
```

- To run against staging subgraphs for example:

```json
{
  "service": "< intents | depositors | monitor>",
  "logLevel": "debug",
  "environment": "staging",
  "database": {
    "url": "<your db url>"
  }
}
```

## Run poller:

<!-- ```sh
yarn workspace @chimera-monorepo/cartographer start
```

If you'd like to run a different poller, you can specify which one you'd
like to run by setting the `SERVICE` env var, e.g.L

SERVICE=intents yarn workspace @chimera-monorepo/cartographer start -->

#### We need to follow certain steps to run the poller:

- Open a terminal in the repository root and run the following command to start a PostgreSQL database server in a Docker container:

  ```sh
  docker run -p 5432:5432 -e POSTGRES_PASSWORD=qwerty -d postgres
  ```

- Make sure that you have a PostgreSQL server running on your local machine. If you don't, please follow the instructions provided in the README to start a PostgreSQL server in a Docker container. To connect to the database, use the following connection string:

  ```url
  postgres://postgres:qwerty@localhost:5432/everclear?sslmode=disable
  ```

- For running the DB mate, you need to set up a `DATABASE_URL` environment variable using the following command:

  ```sh
  export DATABASE_URL=postgres://postgres:qwerty@localhost:5432/everclear?sslmode=disable
  ```

  This command is used to determine which database to use

- For setting up the schema and interfaces for a database -
  ```sh
  yarn workspace @chimera-monorepo/database dbmate up
  ```

Great! You are now all set up to run the cartographer poller✨.

Each poller can be run separately, full list of pollers to start is in the `package.json` and, as an example to execute intents, run the following command in project root -

```sh
yarn workspace @chimera-monorepo/cartographer start:intents
```

# Updating DB Schema

In order to update the database schema, create a new migration:

```sh
yarn workspace @chimera-monorepo/database dbmate new migration_name
```

Edit the migration file and run the migration:

```sh
yarn workspace @chimera-monorepo/database dbmate up
```

Create the Typescript schema using [Zapatos](https://jawj.github.io/zapatos/):

```sh
yarn workspace @chimera-monorepo/database zapatos
```
