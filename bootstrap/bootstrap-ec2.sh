#!/usr/bin/env bash
# First-boot installer. Existing EC2 deployments must not be adopted here.
set -Eeuo pipefail
umask 077
readonly SOURCE=/opt/property-app-rebuild ROOT=/opt/property-app-deploy APP=/home/ubuntu/myProperty/code
die() { printf '%s\n' "$*" >&2; exit 1; }
[[ $EUID == 0 && -s "$SOURCE/config.json" ]] || die 'Root and bootstrap configuration are required.'
if [[ -d "$ROOT" && ! -f "$SOURCE/started" ]]; then die 'Existing deployment found; refusing fresh-host setup.'; fi
if [[ -f "$SOURCE/completed" ]]; then
  curl -fsS --max-time 10 http://127.0.0.1:5173/ >/dev/null
  printf '%s\n' 'Bootstrap already completed; nothing was changed.'
  exit 0
fi
if command -v docker >/dev/null && [[ ! -f "$SOURCE/started" ]]; then
  [[ -z "$(docker ps -aq)" ]] || die 'Existing containers found; refusing adoption.'
fi
[[ "$(uname -m)" == x86_64 ]] || die 'Use the pinned Ubuntu x86_64 AMI.'
source /etc/os-release
[[ "$ID" == ubuntu ]] || die 'Use Ubuntu.'
[[ "$(df --output=size -BG / | tail -1 | tr -dc '0-9')" -ge 20 ]] || die 'The root filesystem must be expanded on the 30 GiB disk.'
install -d -m 700 "$ROOT"
touch "$SOURCE/started"
install -m 600 "$SOURCE/config.json" "$ROOT/runtime.json"
install -m 600 "$SOURCE/runtime.py" "$ROOT/runtime.py"
python3 "$ROOT/runtime.py" check
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=5 -o DPkg::Lock::Timeout=180 update
apt-get -o Acquire::Retries=5 -o DPkg::Lock::Timeout=180 install -y ca-certificates curl gnupg unzip python3 util-linux
work=$(mktemp -d /var/tmp/property-bootstrap.XXXXXX)
auth=''
cleanup() { rm -rf -- "$work"; if [[ -n "$auth" ]]; then rm -rf -- "$auth"; fi; }
trap cleanup EXIT
download() { curl -fsSL --retry 5 --retry-delay 3 "$1" -o "$2"; }
if ! command -v aws >/dev/null; then
  download https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip "$work/aws.zip"
  unzip -q "$work/aws.zip" -d "$work"
  "$work/aws/install" --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin
fi
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin AWS_DEFAULT_REGION=ap-southeast-7 AWS_PAGER=''
if ! command -v docker >/dev/null; then
  install -d -m 755 /etc/apt/keyrings
  download https://download.docker.com/linux/ubuntu/gpg /etc/apt/keyrings/docker.asc
  chmod 644 /etc/apt/keyrings/docker.asc
  printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' "$VERSION_CODENAME" >/etc/apt/sources.list.d/docker.list
  apt-get -o Acquire::Retries=5 update
  apt-get -o Acquire::Retries=5 install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
python3 - "$(docker compose version --short)" <<'PY'
import re,sys
match=re.search(r'(\d+)\.(\d+)\.(\d+)',sys.argv[1])
if not match or tuple(map(int,match.groups())) < (2,30,0):
    raise SystemExit('Docker Compose 2.30+ is required for raw env files.')
PY
if systemctl cat snap.amazon-ssm-agent.amazon-ssm-agent.service >/dev/null 2>&1; then
  systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service
else
  if ! systemctl cat amazon-ssm-agent.service >/dev/null 2>&1; then
    download https://s3.ap-southeast-7.amazonaws.com/amazon-ssm-ap-southeast-7/latest/debian_amd64/amazon-ssm-agent.deb "$work/ssm.deb"
    dpkg -i "$work/ssm.deb"
  fi
  systemctl enable --now amazon-ssm-agent.service
fi
install -d -m 755 /home/ubuntu/myProperty "$APP" "$APP/certs"
download https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem "$work/ca.pem"
install -m 644 "$work/ca.pem" "$APP/certs/global-bundle.pem"
for name in compose.yml check-db.mjs empty-db.mjs; do install -m 600 "$SOURCE/$name" "$ROOT/$name"; done
for name in deploy.sh refresh-env.sh restore-uploads.sh backup-uploads.sh; do install -m 700 "$SOURCE/$name" "$ROOT/$name"; done
mapfile -t config < <(python3 - "$ROOT/runtime.json" <<'PY'
import json,sys
c=json.load(open(sys.argv[1]))
for key in ['image_uri','uploads_prefix','initialize_empty_database','enable_https','enable_backups']:
    v=c[key]; print(str(v).lower() if isinstance(v,bool) else v)
PY
)
[[ ${#config[@]} == 5 ]] || die 'Invalid runtime configuration.'
image=${config[0]}; prefix=${config[1]}; initialize=${config[2]}; https=${config[3]}; backups=${config[4]}
ready=false
for attempt in $(seq 1 20); do
  if "$ROOT/refresh-env.sh"; then ready=true; break; fi
  sleep 10
done
[[ "$ready" == true ]] || die 'Unable to load runtime configuration.'
auth=$(mktemp -d "$ROOT/docker-auth.bootstrap.XXXXXX")
export DOCKER_CONFIG="$auth"
aws ecr get-login-password --region ap-southeast-7 | docker login --username AWS --password-stdin 147997138960.dkr.ecr.ap-southeast-7.amazonaws.com >/dev/null
timeout 900 docker pull "$image"
rm -rf -- "$auth"
unset DOCKER_CONFIG
docker volume create code_uploads_data >/dev/null
printf '%s\n' code >"$ROOT/project-name"
printf 'APP_IMAGE=%s\nUPLOADS_VOLUME=code_uploads_data\n' "$image" >"$ROOT/release.env"
dc() { docker compose --project-name code --env-file "$ROOT/release.env" --file "$ROOT/compose.yml" "$@"; }
healthy() {
  for attempt in $(seq 1 60); do
    if curl -fsS --max-time 3 http://127.0.0.1:5173/ >/dev/null; then return 0; fi
    sleep 3
  done
  return 1
}
if [[ "$initialize" == true && ! -f "$SOURCE/schema-initialized" ]]; then
  # Only a newly created, completely empty public schema is eligible.
  schema_state=$(dc run --rm --no-deps --pull never -T --entrypoint node web --input-type=module <"$ROOT/empty-db.mjs")
  if [[ "$schema_state" == empty ]]; then
    python3 "$ROOT/runtime.py" bootstrap-schema-env
    "$ROOT/deploy.sh" "$image"
    touch "$SOURCE/schema-initialized"
    "$ROOT/refresh-env.sh"
    dc up -d --no-build --pull never --force-recreate web
    healthy
  elif [[ "$schema_state" == ready ]]; then
    # Replacing only EC2 must reuse an initialized database without schema sync.
    "$ROOT/deploy.sh" "$image"
  else
    die 'Database schema state is unexpected; no automatic synchronization was attempted.'
  fi
else
  "$ROOT/deploy.sh" "$image"
fi
# Initial deployment has no previous successful image on this host.
rm -f "$ROOT/previous.env"
if [[ -n "$prefix" && ! -f "$SOURCE/uploads-restored" ]]; then
  "$ROOT/restore-uploads.sh" "$prefix"
  touch "$SOURCE/uploads-restored"
fi
if [[ ! -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]]; then
  download https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb "$work/cw.deb"
  dpkg -i "$work/cw.deb"
fi
install -m 600 "$SOURCE/cloudwatch-agent.json" /opt/aws/amazon-cloudwatch-agent/etc/property-app.json
python3 -m json.tool /opt/aws/amazon-cloudwatch-agent/etc/property-app.json >/dev/null
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/property-app.json
systemctl enable amazon-cloudwatch-agent
install -m 644 "$SOURCE/property-uploads-backup.service" /etc/systemd/system/property-uploads-backup.service
install -m 644 "$SOURCE/property-uploads-backup.timer" /etc/systemd/system/property-uploads-backup.timer
systemctl daemon-reload
if [[ "$backups" == true ]]; then systemctl enable --now property-uploads-backup.timer; fi
if ! command -v caddy >/dev/null; then
  download https://dl.cloudsmith.io/public/caddy/stable/gpg.key "$work/caddy.key"
  gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg "$work/caddy.key"
  download https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt /etc/apt/sources.list.d/caddy-stable.list
  chmod 644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
  apt-get -o Acquire::Retries=5 update
  apt-get -o Acquire::Retries=5 install -y caddy
fi
if [[ "$https" == true ]]; then
  printf 'property.tecerotech.com {\n  reverse_proxy 127.0.0.1:5173\n}\n' >/etc/caddy/Caddyfile
else
  printf 'http://127.0.0.1:8080 {\n  reverse_proxy 127.0.0.1:5173\n}\n' >/etc/caddy/Caddyfile
fi
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable --now caddy
systemctl reload caddy
touch "$SOURCE/completed"
printf '%s\n' 'Property lab first-boot setup completed. No DNS records were changed.'
