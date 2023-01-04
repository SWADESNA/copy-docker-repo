FROM node:14-alpine3.15 AS base
LABEL maintainer bosun olanrewaju <bosunolanrewaju@gmail.com>

# # This is necessary to run Puppeteer on Docker
RUN set -x
RUN apk update
RUN apk upgrade
RUN apk add --no-cache g++ make py3-pip git udev ttf-freefont

WORKDIR /server

RUN npm install -g typescript@3.9.9

COPY package.json yarn.lock tsconfig.json tslint.json /server/
RUN yarn install --production --immutable

COPY src /server/src
COPY config /server/config

RUN yarn build

# After installing node modules, update maxmind db
ARG MAXMIND_LICENSE_KEY
ENV MAXMIND_LICENSE_KEY=${MAXMIND_LICENSE_KEY}
ARG IS_JOB_SERVICE
ENV IS_JOB_SERVICE=${IS_JOB_SERVICE}
ARG SKIP_MAXMIND=0
RUN if [ "$IS_JOB_SERVICE" = "true" ] || [ "$SKIP_MAXMIND" = "1" ] || [ -z "$MAXMIND_LICENSE_KEY" ] ; then echo "Skipping Maxmind DB update" ; else node ./node_modules/geoip-lite/scripts/updatedb.js license_key=${MAXMIND_LICENSE_KEY} ; fi

# Production
FROM node:14-alpine3.15 AS prod
ENV CHROME_BIN="/usr/bin/chromium-browser" \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD="true"

RUN apk add --no-cache chromium dumb-init

RUN mkdir -p /server/tmp-uploads
RUN chown node:node /server

USER node

WORKDIR /server

COPY --chown=node:node .sequelizerc database.js newrelic.js ng_banks_list.json package.json Jakefile console.js swagger.yaml /server/
COPY --chown=node:node --from=base /server/node_modules /server/node_modules
COPY --chown=node:node --from=base /server/lib /server/lib
COPY --chown=node:node migrations /server/migrations
COPY --chown=node:node config /server/config
COPY --chown=node:node jakelib /server/jakelib
COPY --chown=node:node public /server/public

EXPOSE 5000
ENV NODE_OPTIONS="--max-old-space-size=5120"

CMD ["dumb-init", "node", "lib/app.js"]
