#!/bin/bash
set -e

# Change UID if requested
if [ -n "${UID+x}" ] && [ "${UID}" != "0" ]; then
    current_uid=$(id -u bitcoin)
    if [ "$current_uid" != "${UID}" ]; then
        usermod -u "${UID}" bitcoin
    fi
fi

# Change primary group if requested
if [ -n "${GID+x}" ] && [ "${GID}" != "0" ]; then
    existing_group=$(getent group "${GID}" | cut -d: -f1)

    if [ -n "$existing_group" ]; then
        # Reuse the existing group
        usermod -g "$existing_group" bitcoin
    else
        current_gid=$(getent group bitcoin | cut -d: -f3)
        if [ "$current_gid" != "${GID}" ]; then
            groupmod -g "${GID}" bitcoin
        fi
    fi
fi

echo "$0: assuming uid:gid for bitcoin:bitcoin of $(id -u bitcoin):$(id -g bitcoin)"

if [ "$(echo "$1" | cut -c1)" = "-" ]; then
  echo "$0: assuming arguments for bitcoind"

  set -- bitcoind "$@"
fi

if [ "$(echo "$1" | cut -c1)" = "-" ] || [ "$1" = "bitcoind" ]; then
  mkdir -p "$BITCOIN_DATA"
  chmod 700 "$BITCOIN_DATA"
  # Fix permissions for home dir.
  chown -R bitcoin:bitcoin "$(getent passwd bitcoin | cut -d: -f6)"
  # Fix permissions for bitcoin data dir.
  chown -R bitcoin:bitcoin "$BITCOIN_DATA"

  echo "$0: setting data directory to $BITCOIN_DATA"

  set -- "$@" -datadir="$BITCOIN_DATA"
fi

if [ "$1" = "bitcoind" ] || [ "$1" = "bitcoin-cli" ] || [ "$1" = "bitcoin-tx" ]; then
  echo
  exec gosu bitcoin "$@"
fi

echo
exec "$@"
