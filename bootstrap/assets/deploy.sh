#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

readonly ROOT=/opt/property-app-deploy
readonly REPO=147997138960.dkr.ecr.ap-southeast-7.amazonaws.com/property-app-dev
readonly REGISTRY=147997138960.dkr.ecr.ap-southeast-7.amazonaws.com
readonly REGION=ap-southeast-7

die() { printf '%s\n' "$*" >&2; exit 1; }
[[ $EUID == 0 ]] || die 'Run this script with sudo.'
[[ $# == 1 ]] || die 'Usage: deploy.sh IMAGE_URI | --rollback'
[[ -s "$ROOT/release.env" && -s "$ROOT/project-name" ]] || die 'Run bootstrap-ec2.sh first.'

exec 9>"$ROOT/deploy.lock"
flock -w 30 9 || die 'Another deployment is running; retry after it finishes.'
project=$(cat "$ROOT/project-name")
[[ "$project" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die 'Invalid Compose project name.'
volume=$(sed -n 's/^UPLOADS_VOLUME=//p' "$ROOT/release.env")
[[ "$volume" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || die 'Invalid uploads volume name.'
unset APP_IMAGE UPLOADS_VOLUME COMPOSE_FILE COMPOSE_PROJECT_NAME

rollback_requested=false
if [[ $1 == --rollback ]]; then
  [[ -s "$ROOT/previous.env" ]] || die 'No previous successful image is recorded.'
  image=$(sed -n 's/^APP_IMAGE=//p' "$ROOT/previous.env")
  rollback_requested=true
else
  image=$1
  tag=${image#"$REPO:"}
  [[ "$image" == "$REPO:"* && "$tag" =~ ^sha-[0-9a-f]{40}-run-([0-9]+)-[0-9]+$ ]] || die 'Only versioned images from property-app-dev are allowed.'
  run_id=${BASH_REMATCH[1]}
  if [[ -s "$ROOT/highest-run-id" ]]; then
    highest=$(cat "$ROOT/highest-run-id")
    [[ "$highest" =~ ^[0-9]+$ ]] || die 'Invalid recorded workflow run.'
    (( 10#$run_id >= 10#$highest )) || die 'Refusing an older workflow run. Use --rollback for an intentional rollback.'
  fi
fi
[[ "$image" =~ ^[a-zA-Z0-9][a-zA-Z0-9._:/@-]*$ ]] || die 'Invalid image reference.'

dc() {
  local release=$1
  shift
  timeout 120 docker compose --project-name "$project" --env-file "$release" --file "$ROOT/compose.yml" "$@"
}
healthy() {
  local i status
  for i in $(seq 1 30); do
    status=$(curl --silent --max-time 2 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:5173/ || true)
    if [[ "$status" == 200 ]]; then
      sleep 2
      status=$(curl --silent --max-time 2 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:5173/ || true)
      [[ "$status" == 200 ]] && return 0
    fi
    sleep 2
  done
  return 1
}

candidate=$(mktemp "$ROOT/candidate.XXXXXX")
docker_auth=$(mktemp -d "$ROOT/docker-auth.XXXXXX")
switched=false
cleanup() { rm -f "$candidate"; rm -rf "$docker_auth"; }
recover() {
  local status=$?
  trap - ERR INT TERM
  if [[ "$switched" == true ]]; then
    printf '%s\n' 'New image failed. Attempting to restore the previous image.' >&2
    if dc "$ROOT/release.env" up -d --no-build --pull never web && healthy; then
      printf '%s\n' 'Previous image restored; deployment remains failed.' >&2
    else
      printf '%s\n' 'Restore failed. Check EC2 and the application locally.' >&2
    fi
  fi
  exit "${status:-1}"
}
trap cleanup EXIT
trap recover ERR
trap 'false' INT TERM

printf 'APP_IMAGE=%s\nUPLOADS_VOLUME=%s\n' "$image" "$volume" >"$candidate"
dc "$candidate" config --quiet
docker volume inspect "$volume" >/dev/null

if [[ "$image" == "$REPO:"* ]]; then
  export DOCKER_CONFIG="$docker_auth"
  aws ecr get-login-password --region "$REGION" |
    docker login --username AWS --password-stdin "$REGISTRY" >/dev/null
  timeout 420 docker pull "$image"
elif [[ "$rollback_requested" == true ]]; then
  # The first adopted release may be an EC2-built image such as code-web.
  # It exists only in the local Docker engine and must not be pulled from a registry.
  docker image inspect "$image" >/dev/null 2>&1 ||
    die "Previous local image '$image' is not available on EC2. The running release was not changed."
  printf 'Using existing local rollback image: %s\n' "$image"
else
  die 'Only images from property-app-dev can be deployed.'
fi

# A failed database preflight leaves the running app untouched.
dc "$candidate" run --rm --no-deps --pull never -T --entrypoint node web --input-type=module <"$ROOT/check-db.mjs"
dc "$candidate" run --rm --no-deps --pull never -T --user 0 --entrypoint sh web -c 'chown node:node /app/uploads'

switched=true
dc "$candidate" up -d --no-build --pull never web
healthy

cp "$ROOT/release.env" "$ROOT/previous.env"
mv "$candidate" "$ROOT/release.env"
switched=false
if [[ "$rollback_requested" == false ]]; then
  printf '%s\n' "$run_id" >"$ROOT/highest-run-id"
fi
printf 'Deployment succeeded: %s\n' "$image"
