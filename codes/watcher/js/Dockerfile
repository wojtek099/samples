# The instructions for the first stage
FROM node:13-alpine as builder

ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci

# The instructions for second stage
FROM node:13-alpine
LABEL application=watcher-js

WORKDIR /usr/src/app
COPY --from=builder node_modules node_modules

COPY . .

CMD ["node","watcher"]
