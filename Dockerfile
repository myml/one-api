### Stage 0: Install dependencies ###
FROM node:16 AS builder-web

COPY ./web/default/package.json /web/default/
COPY ./web/default/yarn.lock /web/default/
WORKDIR /web/default
RUN yarn install --registry=https://registry.npmmirror.com

COPY ./web/default/ /web/default/
COPY ./VERSION ./
RUN DISABLE_ESLINT_PLUGIN='true' REACT_APP_VERSION=$(cat ./VERSION) yarn build 

### Stage 1: Build the React app ###
FROM golang:alpine AS builder-go

RUN apk add --no-cache \
    gcc \
    musl-dev \
    sqlite-dev \
    build-base

ENV GO111MODULE=on \
    CGO_ENABLED=1 \
    GOOS=linux

WORKDIR /build

ADD go.mod go.sum ./
RUN GOPROXY=https://goproxy.cn go mod download

COPY . .
COPY --from=builder-web /web/default/build ./web/build/default

RUN go build -trimpath -ldflags "-s -w -X 'github.com/songquanpeng/one-api/common.Version=$(cat VERSION)' -linkmode external -extldflags '-static'" -o one-api

### Stage 2: Copy the compiled binary to the final image ###
FROM alpine:latest

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder-go /build/one-api /

EXPOSE 3000

WORKDIR /data

ENTRYPOINT ["/one-api"]