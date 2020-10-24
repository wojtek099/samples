# syntax = docker/dockerfile:1.0-experimental

FROM node:lts-alpine as builder
LABEL application=platform-ui

ARG ENV

RUN apk add --no-cache git openssh
RUN mkdir -p -m 0600 ~/.ssh && ssh-keyscan bitbucket.org >> ~/.ssh/known_hosts

COPY package*.json /app/
WORKDIR /app
RUN --mount=type=ssh npm ci

COPY . ./
RUN node node_modules/@angular/cli/bin/ng build --configuration=$ENV

FROM nginx:alpine
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/dist/jp-platform-ui /usr/share/nginx/jp-platform-ui

