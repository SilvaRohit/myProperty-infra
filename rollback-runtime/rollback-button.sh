#!/usr/bin/env bash
# Rendered by Terraform; invoked only by the dedicated SSM rollback document.
set -Eeuo pipefail
umask 077

readonly ROOT=/opt/property-app-deploy
die() { printf '%s\n' "$*" >&2; exit 1; }
[[ $EUID == 0 ]] || die 'SSM must run this document as root.'
request_id=${SSM_RequestId:-}
[[ "$request_id" =~ ^[0-9]+$ ]] || die 'A numeric GitHub workflow run ID is required.'
[[ -s "$ROOT/release.env" && -s "$ROOT/previous.env" ]] || die 'Current or previous deployment record is missing.'
install -d -m 700 "$ROOT/rollback-requests"

exec 8>"$ROOT/rollback-button.lock"
flock -w 30 8 || die 'Another rollback request is running.'
request="$ROOT/rollback-requests/$request_id"
if [[ -s "$request.success" ]]; then
  printf 'This workflow run already completed its rollback to %s. No additional rollback was performed.\n' "$(cat "$request.success")"
  exit 0
fi

exec 9>"$ROOT/deploy.lock"
flock -w 30 9 || die 'A deployment is running. Retry the workflow after it finishes.'
if [[ ! -s "$request.target" ]]; then
  target=$(sed -n 's/^APP_IMAGE=//p' "$ROOT/previous.env")
  [[ "$target" =~ ^[a-zA-Z0-9][a-zA-Z0-9._:/@-]*$ ]] || die 'Invalid previous image reference.'
  printf '%s\n' "$target" >"$request.target"
fi
target=$(cat "$request.target")
[[ "$target" =~ ^[a-zA-Z0-9][a-zA-Z0-9._:/@-]*$ ]] || die 'Invalid recorded rollback target.'
current=$(sed -n 's/^APP_IMAGE=//p' "$ROOT/release.env")
if [[ "$current" == "$target" ]]; then
  printf '%s\n' "$target" >"$request.success"
  printf 'The recorded rollback target is already current: %s\n' "$target"
  exit 0
fi
previous=$(sed -n 's/^APP_IMAGE=//p' "$ROOT/previous.env")
[[ "$previous" == "$target" ]] || die 'The previous image changed since this request began. Start a new rollback workflow to choose the current previous image.'

# Install the corrected deployment script without an SSH session.
staged=$(mktemp "$ROOT/deploy.sh.XXXXXX")
trap 'rm -f "$staged"' EXIT
printf '%s' '__DEPLOY_SCRIPT_BASE64__' | base64 --decode >"$staged"
bash -n "$staged"
chmod 700 "$staged"
if [[ ! -e "$ROOT/deploy.sh.before-github-rollback" ]]; then
  cp -p "$ROOT/deploy.sh" "$ROOT/deploy.sh.before-github-rollback"
fi
mv "$staged" "$ROOT/deploy.sh"
flock -u 9
exec 9>&-

printf 'Rollback target: %s\n' "$target"
"$ROOT/deploy.sh" --rollback
current=$(sed -n 's/^APP_IMAGE=//p' "$ROOT/release.env")
[[ "$current" == "$target" ]] || die 'Rollback did not leave the requested image current. Inspect the deployment records.'
printf '%s\n' "$target" >"$request.success"
printf 'GitHub rollback completed: %s\n' "$target"
