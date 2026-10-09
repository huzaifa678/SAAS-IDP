FROM public.ecr.aws/docker/library/node:22-bookworm-slim@sha256:c3de60bf2f9dd0ac6370e6117950ff62d6e339527e7472301c9c78a017978392 AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 g++ build-essential libsqlite3-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN corepack enable

COPY .yarnrc.yml package.json yarn.lock backstage.json ./
COPY packages/app/package.json packages/app/package.json
COPY packages/backend/package.json packages/backend/package.json

RUN yarn install --immutable

COPY . .
RUN yarn tsc && yarn build:all

FROM public.ecr.aws/docker/library/node:22-bookworm-slim@sha256:c3de60bf2f9dd0ac6370e6117950ff62d6e339527e7472301c9c78a017978392

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv g++ build-essential libsqlite3-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m venv /opt/techdocs && \
    /opt/techdocs/bin/pip install --no-cache-dir --upgrade "setuptools>=78.1.1" && \
    /opt/techdocs/bin/pip install --no-cache-dir mkdocs-techdocs-core
ENV PATH="/opt/techdocs/bin:${PATH}"

RUN corepack enable

RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

USER node
WORKDIR /app

COPY --chown=node:node --from=build /app/.yarn ./.yarn
COPY --chown=node:node --from=build /app/.yarnrc.yml /app/backstage.json /app/package.json /app/yarn.lock ./
COPY --chown=node:node --from=build /app/packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz && \
    yarn workspaces focus --all --production && yarn cache clean

COPY --chown=node:node --from=build /app/packages/backend/dist/bundle.tar.gz ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

COPY --chown=node:node --from=build /app/packages/app/dist ./packages/app/dist

COPY --chown=node:node app-config.yaml app-config.production.yaml ./
COPY --chown=node:node catalog ./catalog

ENV NODE_ENV=production
ENV NODE_OPTIONS="--no-node-snapshot"

EXPOSE 7007
CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
