#!/usr/bin/env bash
# Container entrypoint for ndiskless (NexBoot).
# Generates /etc/ndiskless/ndiskless.env idempotently (mimicking upstream
# install-go.sh write_env) then execs the server in the foreground.
set -euo pipefail

ENV_DIR=/etc/ndiskless
ENV_FILE=$ENV_DIR/ndiskless.env
DATA_DIR=${NDISKLESS_DATA_DIR:-/var/lib/ndiskless}
IMPORT_DIR=${NDISKLESS_IMPORT_DIR:-$DATA_DIR/imports}
POOL=${NDISKLESS_POOL:-tank}
ADDR=${NDISKLESS_ADDR:-:8080}
DNSMASQ_CONF=${NDISKLESS_DNSMASQ_CONF:-/etc/dnsmasq.d/ndiskless.conf}
BOOT_URL=${NDISKLESS_BOOT_URL:-}
BOOTSTRAP_USERNAME=${NDISKLESS_BOOTSTRAP_USERNAME:-admin}
CHAP_SECRET=${NDISKLESS_CHAP_SECRET:-}

mkdir -p "$ENV_DIR" "$DATA_DIR" "$IMPORT_DIR" /srv/tftp /etc/dnsmasq.d

# Load host kernel modules (needs privileged + host modules present).
modprobe zfs 2>/dev/null || echo "WARN: modprobe zfs failed - host kernel may lack ZFS support"
modprobe zfs 2>/dev/null || true

random_hex() { openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p; }

# Idempotency: preserve existing credentials across container restarts.
if [ -n "$NDISKLESS_BOOTSTRAP_PASSWORD" ] || ! grep -q '^NDISKLESS_BOOTSTRAP_PASSWORD=' "$ENV_FILE" 2>/dev/null; then
  BOOTSTRAP_PASSWORD=${NDISKLESS_BOOTSTRAP_PASSWORD:-$(random_hex)}
  FRESH_BOOTSTRAP=1
fi

if [ -z "$JWT_SECRET" ]; then
  if grep -q '^NDISKLESS_JWT_SECRET=' "$ENV_FILE" 2>/dev/null; then
    JWT_SECRET=$(sed -n 's/^NDISKLESS_JWT_SECRET=//p' "$ENV_FILE" | head -1)
  else
    JWT_SECRET=$(random_hex)
  fi
fi

if [ -z "$CHAP_SECRET" ]; then
  if grep -q '^NDISKLESS_CHAP_SECRET=' "$ENV_FILE" 2>/dev/null; then
    CHAP_SECRET=$(sed -n 's/^NDISKLESS_CHAP_SECRET=//p' "$ENV_FILE" | head -1)
  else
    CHAP_SECRET=$(random_hex)
  fi
fi

umask 077
cat > "$ENV_FILE" <<EOF
NDISKLESS_ADDR=$ADDR
NDISKLESS_DB_DSN=file:$DATA_DIR/ndiskless.db
NDISKLESS_POOL=$POOL
NDISKLESS_IMPORT_DIR=$IMPORT_DIR
NDISKLESS_DNSMASQ_CONF=$DNSMASQ_CONF
NDISKLESS_BOOT_URL=$BOOT_URL
NDISKLESS_BOOTSTRAP_USERNAME=$BOOTSTRAP_USERNAME
NDISKLESS_BOOTSTRAP_PASSWORD=$BOOTSTRAP_PASSWORD
NDISKLESS_JWT_SECRET=$JWT_SECRET
NDISKLESS_CHAP_SECRET=$CHAP_SECRET
EOF
chmod 600 "$ENV_FILE"

if [ "${FRESH_BOOTSTRAP:-0}" = "1" ]; then
  echo "=================================================="
  echo " NexBoot initial admin password: $BOOTSTRAP_PASSWORD"
  echo " (user: $BOOTSTRAP_USERNAME, persisted in $ENV_FILE)"
  echo "=================================================="
fi

exec /usr/local/bin/ndiskless
