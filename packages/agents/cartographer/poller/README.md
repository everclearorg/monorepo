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

## PostgREST development & JWT authentication

The Cartographer exposes its data via [PostgREST](https://postgrest.org/en/stable/) which expects a signed JWT so that the API can map the request to a Postgres role. A small helper script, `make-jwt.sh`, is provided for **local-only** development to mint such tokens.

### 1. Generate a JWT

```sh
# If you already have a secret in an env var
PGRST_JWT_SECRET="my_super_secret" yarn make-jwt
# Or pass the secret as the first positional argument
./scripts/make-jwt.sh my_super_secret
```

The command will print an HS256-signed token whose payload contains the role `api`.  Copy this token and use it as the `Authorization: Bearer <token>` header when querying PostgREST.

### 2. Start PostgREST (dev)

Set the same secret as an environment variable and launch PostgREST via the convenience yarn script:

```sh
PGRST_JWT_SECRET="my_super_secret" yarn docker:start:postgrest:dev
```

The script will:

1. Pull the official `postgrest/postgrest` image if necessary.
2. Forward the container port **3000** to your host.
3. Pass the database connection string for the local Postgres instance (assumed to be running on `host.docker.internal`).
4. Inject your `PGRST_JWT_SECRET` value into the container, enabling JWT verification.

You can now query the API at `http://localhost:3000` with the JWT generated earlier.

---

If you need additional claims inside the token, open `scripts/make-jwt.sh` and adjust the `payload` JSON before generating the JWT.
