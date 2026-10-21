# NexBoot container image
# Multi-stage: web (vite) -> static Go build -> Ubuntu runtime with ZFS/iSCSI/DHCP deps.
# The upstream binary embeds the web UI via go:embed, so web must build before Go.

FROM node:22-alpine AS web
WORKDIR /src/web
COPY web/ ./
RUN npm ci && npm run build

FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# go:embed expects web/dist to exist before compiling.
COPY --from=web /src/web/dist ./web/dist
RUN VERSION=$(cat VERSION 2>/dev/null || echo dev) && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath \
      -ldflags "-X main.version=${VERSION}" -o /out/ndiskless ./cmd/ndiskless

FROM ubuntu:24.04
# Runtime deps per upstream README: dnsmasq (DHCP/PXE), targetcli-fb (iSCSI LIO),
# zfsutils-linux (ZFS pools), keepalived (HA VRRP), qemu-utils (image conversion), curl.
# Requires privileged container + host network to actually function.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl dnsmasq dnsmasq-utils qemu-utils \
      targetcli-fb zfsutils-linux keepalived iproute2 util-linux \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/ndiskless /usr/local/bin/ndiskless

# State: SQLite store, ZFS pool state, TFTP assets, config
RUN mkdir -p /var/lib/ndiskless /srv/tftp /etc/ndiskless
VOLUME ["/var/lib/ndiskless", "/srv/tftp"]

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -sf http://127.0.0.1:8080/healthz || exit 1

# DHCP/iSCSI/ZFS need root; upstream runs as a system service.
ENTRYPOINT ["/usr/local/bin/ndiskless"]
