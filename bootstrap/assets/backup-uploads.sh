#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

if [[ $EUID -ne 0 ]]; then
  echo "Run this script with sudo."
  exit 1
fi

region="ap-southeast-7"
bucket="tecerotech-property-147997138960-backups"


# Coordinate with the existing deployment script.
exec 9>/opt/property-app-deploy/deploy.lock
flock -w 300 9

# Resolve the active volume only after acquiring the deployment/restore lock.
volume=$(sed -n 's/^UPLOADS_VOLUME=//p' /opt/property-app-deploy/release.env)
project=$(cat /opt/property-app-deploy/project-name)
[[ "$volume" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || exit 1
[[ "$project" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || exit 1
container="${project}-web-1"

# Fail if the existing uploads volume cannot be found.
docker volume inspect "$volume" >/dev/null

# Reuse the application's locally available image.
image_id=$(docker inspect --format '{{.Image}}' "$container")

backup_tmp=$(mktemp -d /var/tmp/property-backup.XXXXXX)
trap 'rm -rf -- "$backup_tmp"' EXIT

backup_id="$(date -u +%Y%m%dT%H%M%SZ)-${backup_tmp##*/}"
destination="s3://${bucket}/uploads/${backup_id}"

echo "Archiving uploads volume..."

docker run --rm \
  --pull=never \
  --network none \
  --read-only \
  --user 0:0 \
  --mount "type=volume,source=${volume},target=/uploads,readonly" \
  --mount "type=bind,source=${backup_tmp},target=/backup" \
  --entrypoint tar \
  "$image_id" \
  -czf /backup/uploads.tgz -C /uploads .

# Check the archive and generate a checksum for restore verification.
tar -tzf "$backup_tmp/uploads.tgz" >/dev/null

(
  cd "$backup_tmp"
  sha256sum uploads.tgz > uploads.tgz.sha256
)

echo "Uploading archive and checksum..."

aws s3 cp "$backup_tmp/uploads.tgz" \
  "${destination}/uploads.tgz" \
  --region "$region" \
  --only-show-errors

aws s3 cp "$backup_tmp/uploads.tgz.sha256" \
  "${destination}/uploads.tgz.sha256" \
  --region "$region" \
  --only-show-errors

echo "Backup completed: ${destination}/"
