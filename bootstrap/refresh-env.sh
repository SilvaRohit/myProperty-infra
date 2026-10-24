#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
exec python3 /opt/property-app-deploy/runtime.py refresh-env
