# Local Setup

- Build Postgres image:

```sh
docker build --tag db:latest --file ./docker/db/Dockerfile .
```

- Run Postgres locally:

```sh
docker run --name cartographer-db --rm -p 5432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=qwerty db
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

# Materialized Views

Checking `pg_cron` scheduled runs:

```
select * from cron.job_run_details
```
