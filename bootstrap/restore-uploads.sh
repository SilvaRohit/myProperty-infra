#!/usr/bin/env bash
# Restore into a new volume, then switch it into service; keep the old volume.
set -Eeuo pipefail
umask 077
readonly ROOT=/opt/property-app-deploy
[[ $EUID == 0 && $# == 1 ]] || { echo 'Usage: sudo restore-uploads.sh S3_BACKUP_PREFIX' >&2; exit 1; }
prefix=$(python3 "$ROOT/runtime.py" check-prefix "$1")
exec 9>"$ROOT/deploy.lock"
flock -w 300 9
image=$(sed -n 's/^APP_IMAGE=//p' "$ROOT/release.env")
old_volume=$(sed -n 's/^UPLOADS_VOLUME=//p' "$ROOT/release.env")
project=$(cat "$ROOT/project-name")
[[ "$image" =~ ^147997138960\.dkr\.ecr\.ap-southeast-7\.amazonaws\.com/property-app-dev:sha-[0-9a-f]{40}-run-[0-9]+-[0-9]+$ ]]
[[ "$old_volume" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ && "$project" =~ ^[a-z0-9][a-z0-9_-]*$ ]]
work=$(mktemp -d /var/tmp/property-restore.XXXXXX)
candidate=$(mktemp "$ROOT/restore-candidate.XXXXXX")
trap 'rm -rf -- "$work"; rm -f -- "$candidate"' EXIT
aws s3 cp "${prefix}/uploads.tgz" "$work/uploads.tgz" --region ap-southeast-7 --only-show-errors
aws s3 cp "${prefix}/uploads.tgz.sha256" "$work/uploads.tgz.sha256" --region ap-southeast-7 --only-show-errors
python3 "$ROOT/runtime.py" check-archive "$work/uploads.tgz" "$work/uploads.tgz.sha256"
new_volume="property_restore_$(date -u +%Y%m%d%H%M%S)_${RANDOM}"
docker volume create "$new_volume" >/dev/null
docker run --rm --pull never --network none --read-only --user 0:0 \
  --mount "type=volume,source=$new_volume,target=/restore" \
  --mount "type=bind,source=$work,target=/backup,readonly" \
  --entrypoint tar "$image" -xzf /backup/uploads.tgz -C /restore --no-same-owner
docker run --rm --pull never --network none --read-only --user 0:0 \
  --mount "type=volume,source=$new_volume,target=/restore" \
  --entrypoint chown "$image" -R node:node /restore
printf 'APP_IMAGE=%s\nUPLOADS_VOLUME=%s\n' "$image" "$new_volume" >"$candidate"
dc() { local file=$1; shift; docker compose --project-name "$project" --env-file "$file" --file "$ROOT/compose.yml" "$@"; }
healthy() {
  for attempt in $(seq 1 40); do
    if curl -fsS --max-time 3 http://127.0.0.1:5173/ >/dev/null; then return 0; fi
    sleep 3
  done
  return 1
}
if dc "$candidate" up -d --no-build --pull never web && healthy; then
  cp "$ROOT/release.env" "$ROOT/uploads-before-restore.env"
  mv "$candidate" "$ROOT/release.env"
  printf 'Uploads restored. Active volume: %s; retained former volume: %s\n' "$new_volume" "$old_volume"
else
  dc "$ROOT/release.env" up -d --no-build --pull never web
  echo 'Restore cutover failed; the former volume was selected again. Inspect the application.' >&2
  exit 1
fi
