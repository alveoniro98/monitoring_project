#!/usr/bin/env bash
set -Eeuo pipefail

release="${1:?Usage: deploy-ec2.sh RELEASE_ID}"
if [[ ! "$release" =~ ^[A-Za-z0-9._-]{1,80}$ ]]; then
  echo "Release identifier contains unsupported characters" >&2
  exit 2
fi

rollback_available=false
previous_release=""
container_id="$(docker compose ps -q app)"
if [[ -n "$container_id" ]]; then
  previous_release="$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$container_id" | sed -n 's/^OPSPULSE_RELEASE=//p' | head -n 1)"
fi
if docker image inspect opspulse:local >/dev/null 2>&1; then
  docker image tag opspulse:local opspulse:rollback
  rollback_available=true
fi

rollback() {
  local exit_code=$?
  if (( exit_code != 0 )) && [[ "$rollback_available" == true ]]; then
    echo "Deployment failed; restoring previous image" >&2
    docker image tag opspulse:rollback opspulse:local
    export OPSPULSE_BIND_ADDRESS=0.0.0.0
    export OPSPULSE_HOST_PORT=80
    export OPSPULSE_RELEASE="$previous_release"
    docker compose up -d --no-build
  fi
  exit "$exit_code"
}
trap rollback EXIT

export OPSPULSE_BIND_ADDRESS=0.0.0.0
export OPSPULSE_HOST_PORT=80
export OPSPULSE_RELEASE="$release"
docker compose up -d --build --remove-orphans

for attempt in $(seq 1 12); do
  if curl --fail --silent --show-error --max-time 5 http://127.0.0.1/health; then
    printf '\nDeployment %s passed local health verification.\n' "$release"
    exit 0
  fi
  sleep 5
done

echo "Deployment health verification failed after $attempt attempts" >&2
exit 1
