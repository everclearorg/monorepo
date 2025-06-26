# Local Setup

- Build Postgres image:

```sh
docker build --tag db:latest --file ./docker/db/Dockerfile .
```

- Run Postgres locally:

```sh
# Use this command to ensure when `dbmate up` is run the proper schema is generated
yarn workspace @chimera-monorepo/database docker:start:postgres
```

- Run database migrations:

```sh
export DATABASE_URL=postgres://postgres:qwerty@localhost:5432/everclear?sslmode=disable
yarn workspace @chimera-monorepo/database dbmate up
```

- Install [`dbmate`](https://github.com/amacneil/dbmate) (instructions for Mac OS / Unix):

```sh
brew install dbmate
```

- Create `.env` to point at local database (or export DATABASE_URL):

```sh
DATABASE_URL=postgres://postgres:qwerty@localhost:5432/everclear?sslmode=disable
```

# Updating DB Schema

**NOTE:** If you are using goldsky sinks, you will have to create a migration to ensure zapatos types are
properly generated during local development.

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
# See note above re: goldksy sinks
yarn workspace @chimera-monorepo/database zapatos
```

# Materialized Views

Checking `pg_cron` scheduled runs:

```
select * from cron.job_run_details
```
