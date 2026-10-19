#!/usr/bin/env bash
set -Eeuo pipefail

action="${1:-help}"
case "$action" in
  status)
    docker compose ps
    ;;
  logs)
    docker compose logs --tail=100 --follow app
    ;;
  disk)
    df -h
    docker system df
    ;;
  restart)
    docker compose restart app
    ;;
  health)
    "$(dirname "$0")/health-check.sh" "${2:-http://127.0.0.1}"
    ;;
  ports)
    ss -lnt
    ;;
  dns)
    if [[ -z "${2:-}" ]]; then
      echo "Usage: $0 dns HOSTNAME" >&2
      exit 2
    fi
    getent ahosts "$2"
    ;;
  *)
    echo "Usage: $0 {status|logs|disk|restart|health [URL]|ports|dns HOSTNAME}" >&2
    exit 2
    ;;
esac
