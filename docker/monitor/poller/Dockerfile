FROM public.ecr.aws/lambda/nodejs:18 as node

# ----------------------------------------
# Builds lambda compatible Docker container for monitor package.

# ----------------------------------------

FROM node as build
RUN yum update -y
RUN yum install -y git
# Install Python and other dependencies
RUN yum install -y python3 python3-pip make gcc gcc-c++ python3-devel
# Install Forge CLI
RUN npm install -g node-gyp @arcblock/forge-cli
RUN npm install --global yarn@1.22.5 

ENV HOME=/tmp/build \
    PATH=/tmp/build/node_modules/.bin:./node_modules/.bin:${PATH}

WORKDIR /tmp/build

ARG TEMP_DEPS_DIR

# ----- Copy only the files that affect yarn install -----
# Allows docker to use cache and skip install if dependencies are unchanged.
# Assumes that ./packages/*/package.json files have been copied to TEMP_DEPS_DIR
# with that same directory structure. build.sh does this.
COPY .yarn /tmp/build/.yarn/
COPY .yarnrc.yml /tmp/build/
COPY package.json /tmp/build/
COPY packages/agents/monitor/package.json /tmp/build/packages/agents/monitor/
COPY packages/agents/relayer/package.json /tmp/build/packages/agents/relayer/
COPY packages/adapters/cache/package.json /tmp/build/packages/adapters/cache/
COPY packages/adapters/database/package.json /tmp/build/packages/adapters/database/
COPY packages/adapters/subgraph/package.json /tmp/build/packages/adapters/subgraph/
COPY packages/adapters/chainservice/package.json /tmp/build/packages/adapters/chainservice/
COPY packages/adapters/web3signer/package.json /tmp/build/packages/adapters/web3signer/
COPY packages/adapters/relayer/package.json /tmp/build/packages/adapters/relayer/
COPY packages/contracts/package.json /tmp/build/packages/contracts/
COPY packages/utils/package.json /tmp/build/packages/utils/
COPY yarn.lock /tmp/build/

# ----- Install dependencies -----
# Install dependencies exactly as in the yarn.lock file - no updates.
RUN YARN_ENABLE_SCRIPTS=0 yarn install 

# ----- Copy source and all other files that affect lint, test, build -----
COPY config config/
COPY packages/agents/monitor /tmp/build/packages/agents/monitor
COPY packages/agents/relayer /tmp/build/packages/agents/relayer
COPY packages/adapters/cache /tmp/build/packages/adapters/cache
COPY packages/adapters/database /tmp/build/packages/adapters/database
COPY packages/adapters/subgraph /tmp/build/packages/adapters/subgraph
COPY packages/adapters/chainservice /tmp/build/packages/adapters/chainservice
COPY packages/adapters/relayer /tmp/build/packages/adapters/relayer
COPY packages/adapters/web3signer /tmp/build/packages/adapters/web3signer
COPY packages/contracts /tmp/build/packages/contracts/
COPY packages/utils /tmp/build/packages/utils
COPY .eslintignore /tmp/build/
COPY .eslintrc.js /tmp/build/

# ----- Lint, test and build -----
RUN yarn build

# ----------------------------------------
# Copy files to the deployment image.
# ----------------------------------------

FROM node as runtime

ENV NODE_ENV=production \
    PORT=8080
ARG COMMIT_HASH
ENV COMMIT_HASH ${COMMIT_HASH:-unknown}

# ----- Copy files required at runtime by the app -----
WORKDIR ${LAMBDA_TASK_ROOT}
COPY --from=build /tmp/build ${LAMBDA_TASK_ROOT}
COPY --from=public.ecr.aws/datadog/lambda-extension:60 /opt/extensions/ /opt/extensions

EXPOSE 8080
CMD ["packages/agents/monitor/dist/index.handler"]