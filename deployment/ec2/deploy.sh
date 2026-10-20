#!/usr/bin/env bash
set -Eeuo pipefail

release="${1:?Usage: deploy.sh RELEASE_SHA IMAGE_URI}"
image="${2:?Usage: deploy.sh RELEASE_SHA IMAGE_URI}"
if [[ ! "$release" =~ ^[a-f0-9]{40}$ ]]; then
  echo "Release must be a full Git commit SHA" >&2
  exit 2
fi
if [[ ! "$image" =~ ^ghcr\.io/alveoniro98/opspulse:[a-f0-9]{40}$ ]]; then
  echo "Image must be an immutable OpsPulse GHCR commit tag" >&2
  exit 2
fi

app_dir=/opt/opspulse
compose_file="$app_dir/compose.yaml"
env_file="$app_dir/.env"
candidate_file="$app_dir/compose.candidate.yaml"
backup_file="$app_dir/compose.rollback.yaml"
env_backup_file="$app_dir/.env.rollback"
had_previous=false
previous_image=""
previous_release=""

if [[ -f "$compose_file" ]]; then
  if [[ -f "$env_file" ]]; then
    container_id="$(docker compose -f "$compose_file" ps -q app)"
  else
    container_id=""
  fi
  if [[ -n "$container_id" ]]; then
    previous_image="$(docker inspect --format '{{.Config.Image}}' "$container_id")"
    previous_release="$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$container_id" \
      | sed -n 's/^OPSPULSE_RELEASE=//p' | head -n 1)"
    had_previous=true
  fi
  cp "$compose_file" "$backup_file"
  if [[ -f "$env_file" ]]; then
    cp "$env_file" "$env_backup_file"
  fi
fi

rollback() {
  local exit_code=$?
  if (( exit_code != 0 )); then
    echo "Deployment failed; attempting to restore the previous release" >&2
    if [[ "$had_previous" == true && -f "$backup_file" ]]; then
      cp "$backup_file" "$compose_file"
      if [[ -f "$env_backup_file" ]]; then
        cp "$env_backup_file" "$env_file"
      fi
      export OPSPULSE_IMAGE="$previous_image"
      export OPSPULSE_RELEASE="$previous_release"
      if ! docker compose -f "$compose_file" up -d --no-build; then
        echo "Rollback failed; the previous application release may be unavailable" >&2
      fi
    else
      export OPSPULSE_IMAGE="$image"
      export OPSPULSE_RELEASE="$release"
      if ! docker compose -f "$compose_file" down; then
        echo "Failed to stop the incomplete first deployment" >&2
      fi
      rm -f "$compose_file"
      rm -f "$env_file"
    fi
  else
    rm -f "$backup_file" "$env_backup_file"
  fi
  rm -f "$candidate_file"
  exit "$exit_code"
}
trap rollback EXIT

test -f "$candidate_file" || { echo "Candidate Compose file is missing" >&2; exit 1; }
mv "$candidate_file" "$compose_file"
export OPSPULSE_IMAGE="$image"
export OPSPULSE_RELEASE="$release"
printf 'OPSPULSE_IMAGE=%s\nOPSPULSE_RELEASE=%s\n' "$image" "$release" > "$env_file"
chmod 0600 "$env_file"
docker pull "$image"
docker compose -f "$compose_file" up -d --no-build --remove-orphans

for attempt in $(seq 1 18); do
  if curl --fail --silent --show-error --max-time 5 http://127.0.0.1/health; then
    printf '\nRelease %s passed local health verification.\n' "$release"
    exit 0
  fi
  sleep 5
done

echo "Deployment health verification failed after $attempt attempts" >&2
exit 1
