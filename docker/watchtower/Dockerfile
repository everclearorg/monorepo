FROM node:18-slim AS node

# ----------------------------------------
# Builds Docker container for watchtower package.

# ----------------------------------------

FROM node AS build
RUN apt-get update && apt-get install -y \
    git curl bash \
    python3 python3-pip make gcc g++ python3-dev \
    && rm -rf /var/lib/apt/lists/*
# Install node-gyp (needed for native dependencies)
RUN npm install -g node-gyp
# Install Foundry (needed for Solidity contract builds)
# Pin installer script to specific commit hash and verify SHA256 checksum for supply chain security
# Pin Foundry to specific version (v1.5.1) for reproducible builds
# The installer script downloads foundryup, which then handles binary verification via GitHub attestations
ARG FOUNDRY_INSTALLER_COMMIT=d9f47a72b446c7006254be185f175efd1c7a81a2
ARG FOUNDRY_INSTALLER_SHA256=e103bb7839e0c8c65263c7971d0b6bf94ffbe2e81dff89c6b3ecb6ce2d76b71c
ARG FOUNDRY_VERSION=v1.5.1
RUN set -eux; \
    curl -fsSL -o /tmp/foundry-install.sh \
        https://raw.githubusercontent.com/foundry-rs/foundry/${FOUNDRY_INSTALLER_COMMIT}/foundryup/install; \
    echo "${FOUNDRY_INSTALLER_SHA256}  /tmp/foundry-install.sh" | sha256sum -c -; \
    bash /tmp/foundry-install.sh; \
    /root/.foundry/bin/foundryup -i ${FOUNDRY_VERSION}; \
    rm -f /tmp/foundry-install.sh

ENV HOME=/tmp/build \
    PATH=/root/.foundry/bin:/tmp/build/node_modules/.bin:./node_modules/.bin:${PATH}

WORKDIR /tmp/build

ARG TEMP_DEPS_DIR

# ----- Copy only the files that affect yarn install -----
# Allows docker to use cache and skip install if dependencies are unchanged.
# Assumes that ./packages/*/package.json files have been copied to TEMP_DEPS_DIR
# with that same directory structure. build.sh does this.
COPY .yarn /tmp/build/.yarn/
COPY .yarnrc.yml /tmp/build/
COPY package.json /tmp/build/
COPY packages/agents/watchtower/package.json /tmp/build/packages/agents/watchtower/
COPY packages/adapters/cache/package.json /tmp/build/packages/adapters/cache/
COPY packages/adapters/subgraph/package.json /tmp/build/packages/adapters/subgraph/
COPY packages/adapters/web3signer/package.json /tmp/build/packages/adapters/web3signer/
COPY packages/adapters/chainservice/package.json /tmp/build/packages/adapters/chainservice/
COPY packages/contracts/package.json /tmp/build/packages/contracts/
COPY packages/utils/package.json /tmp/build/packages/utils/
COPY yarn.lock /tmp/build/

# ----- Install dependencies -----
# Install dependencies exactly as in the yarn.lock file - no updates.
RUN yarn install

# ----- Copy source and all other files that affect lint, test, build -----
COPY config config/
COPY packages/agents/watchtower /tmp/build/packages/agents/watchtower
COPY packages/adapters/cache /tmp/build/packages/adapters/cache
COPY packages/adapters/subgraph /tmp/build/packages/adapters/subgraph
COPY packages/adapters/web3signer /tmp/build/packages/adapters/web3signer
COPY packages/adapters/chainservice /tmp/build/packages/adapters/chainservice
COPY packages/contracts /tmp/build/packages/contracts/
COPY packages/utils /tmp/build/packages/utils
COPY .eslintignore /tmp/build/
COPY .eslintrc.js /tmp/build/

# ----- Lint, test and build -----
RUN yarn build

# ----------------------------------------
# Copy files to the deployment image.
# ----------------------------------------

FROM node AS runtime

ENV NODE_ENV=production 

ARG COMMIT_HASH
ENV COMMIT_HASH=${COMMIT_HASH:-unknown}

# ----- Copy files required at runtime by the app -----
COPY --from=build --chown=node:node /tmp/build /home/node

# This user is created in the base image with uid and gid = 1000.
USER node

WORKDIR /home/node/packages/agents/watchtower

EXPOSE 8080

CMD ["node", "--trace-warnings", "dist/index.js"]