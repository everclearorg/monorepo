FROM node:18-slim AS build

RUN apt-get update && apt-get install -y git curl bash python3 make gcc g++ && rm -rf /var/lib/apt/lists/*

# Install dbmate for database migrations
ARG DBMATE_VERSION=v2.29.3
ARG DBMATE_SHA256=2bb1554a32d9c0bd544841d3523eae64fd60a58d7720c5d82900043dc5e87a6c
RUN set -eux; \
    curl -fsSL -o /tmp/dbmate \
        https://github.com/amacneil/dbmate/releases/download/${DBMATE_VERSION}/dbmate-linux-amd64; \
    echo "${DBMATE_SHA256}  /tmp/dbmate" | sha256sum -c -; \
    mv /tmp/dbmate /usr/local/bin/dbmate; \
    chmod +x /usr/local/bin/dbmate

WORKDIR /tmp/build

# Copy dependency files first for layer caching
COPY .yarn /tmp/build/.yarn/
COPY .yarnrc.yml /tmp/build/
COPY package.json /tmp/build/
# All workspace package.json files must be present for Yarn 3 resolution
COPY packages/utils/package.json /tmp/build/packages/utils/
COPY packages/adapters/cache/package.json /tmp/build/packages/adapters/cache/
COPY packages/adapters/chainservice/package.json /tmp/build/packages/adapters/chainservice/
COPY packages/adapters/subgraph/package.json /tmp/build/packages/adapters/subgraph/
COPY packages/adapters/web3signer/package.json /tmp/build/packages/adapters/web3signer/
COPY packages/adapters/relayer/package.json /tmp/build/packages/adapters/relayer/
COPY packages/adapters/database/package.json /tmp/build/packages/adapters/database/
COPY packages/agents/cartographer/core/package.json /tmp/build/packages/agents/cartographer/core/
COPY packages/agents/cartographer/poller/package.json /tmp/build/packages/agents/cartographer/poller/
COPY packages/agents/cartographer/handler/package.json /tmp/build/packages/agents/cartographer/handler/
COPY packages/agents/lighthouse/package.json /tmp/build/packages/agents/lighthouse/
COPY packages/agents/monitor/package.json /tmp/build/packages/agents/monitor/
COPY packages/agents/relayer/package.json /tmp/build/packages/agents/relayer/
COPY packages/agents/watchtower/package.json /tmp/build/packages/agents/watchtower/
COPY packages/contracts/package.json /tmp/build/packages/contracts/
COPY packages/subgraph/package.json /tmp/build/packages/subgraph/
COPY yarn.lock /tmp/build/

RUN yarn install

# Copy source
COPY config config/
COPY packages/agents/cartographer/handler /tmp/build/packages/agents/cartographer/handler
COPY packages/agents/cartographer/core /tmp/build/packages/agents/cartographer/core
COPY packages/adapters/subgraph /tmp/build/packages/adapters/subgraph
COPY packages/adapters/database /tmp/build/packages/adapters/database
COPY packages/adapters/chainservice /tmp/build/packages/adapters/chainservice
COPY packages/utils /tmp/build/packages/utils
COPY packages/contracts /tmp/build/packages/contracts
COPY .eslintignore /tmp/build/
COPY .eslintrc.js /tmp/build/

ENV SKIP_SOLIDITY_BUILD=true
RUN yarn workspace @chimera-monorepo/cartographer-handler build

# Runtime stage
FROM node:18-slim AS runtime

ENV NODE_ENV=production
ARG COMMIT_HASH
ENV COMMIT_HASH=${COMMIT_HASH:-unknown}

WORKDIR /app
COPY --from=build /tmp/build /app
COPY --from=build /usr/local/bin/dbmate /usr/local/bin/dbmate

EXPOSE 3000

CMD ["node", "packages/agents/cartographer/handler/dist/index.js"]
