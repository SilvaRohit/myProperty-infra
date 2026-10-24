#!/usr/bin/env python3
"""Private runtime configuration and archive verification; never evaluate dotenv."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import tempfile
import time

ROOT = Path('/opt/property-app-deploy')
APP = Path('/home/ubuntu/myProperty/code')
PREFIX = 's3://tecerotech-property-147997138960-backups/uploads/'
IMAGE = re.compile(r'147997138960\.dkr\.ecr\.ap-southeast-7\.amazonaws\.com/property-app-dev:sha-[0-9a-f]{40}-run-[0-9]+-[0-9]+')


def parse_dotenv(text):
    values = {}
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        match = re.fullmatch(r'\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)', line)
        if not match or match[1] in values:
            raise ValueError('Invalid or duplicate dotenv entry.')
        key, raw = match[1], match[2].strip()
        if raw.startswith('"'):
            value = json.loads(raw)
            if not isinstance(value, str):
                raise ValueError('Invalid quoted dotenv value.')
        elif raw.startswith("'"):
            quoted = re.fullmatch(r"'([^']*)'", raw)
            if not quoted:
                raise ValueError('Invalid single-quoted dotenv value.')
            value = quoted[1]
        else:
            # Match the Terraform ephemeral-password parser exactly.
            if key == 'DATABASE_PASSWORD' and re.search(r'\s+#', raw):
                raise ValueError('Password entries must not have inline comments.')
            value = re.split(r'\s+#', raw, maxsplit=1)[0].rstrip()
        if any(c in value for c in '\x00\r\n'):
            raise ValueError('Only single-line values are supported.')
        values[key] = value
    for key in ('DATABASE_PASSWORD', 'JWT_SECRET', 'JWT_EXPIRATION_TIME'):
        if not values.get(key):
            raise ValueError('Required runtime setting is missing.')
    return values


def normalize_env(text, host, initialize=False):
    if not re.fullmatch(r'[a-z0-9.-]+\.rds\.amazonaws\.com', host):
        raise ValueError('Invalid RDS endpoint.')
    values = parse_dotenv(text)
    values.update(DATABASE_HOST=host, DATABASE_PORT='5432', DATABASE_NAME='propertyapp',
                  DATABASE_USER='postgres', DATABASE_SSL='true',
                  DATABASE_CA_PATH='/app/certs/global-bundle.pem',
                  DATABASE_SYNCHRONIZE='true' if initialize else 'false', DATABASE_LOGGING='false')
    # The installed Compose file uses env_file format: raw, preserving $ and #.
    return ''.join(f'{key}={value}\n' for key, value in values.items())


@contextlib.contextmanager
def deployment_lock(root):
    with (root / 'deploy.lock').open('a') as handle:
        deadline = time.monotonic() + 300
        while True:
            try:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() > deadline:
                    raise RuntimeError('Deployment lock timeout.') from None
                time.sleep(1)
        yield


def refresh(config, initialize=False, root=ROOT, app=APP):
    with deployment_lock(root):
        response = subprocess.run(['aws', 'secretsmanager', 'get-secret-value',
            '--region', config['region'], '--secret-id', config['secret_arn'],
            '--version-stage', 'AWSCURRENT', '--output', 'json', '--no-cli-pager'],
            capture_output=True, check=False, timeout=60)
        if response.returncode:
            raise RuntimeError('Unable to read the application configuration secret.')
        try:
            normalized = normalize_env(json.loads(response.stdout)['SecretString'],
                                       config['database_host'], initialize)
        except (ValueError, KeyError, TypeError):
            raise RuntimeError('Runtime secret format is invalid; no values were logged.') from None
        descriptor, temporary = tempfile.mkstemp(prefix='.env.candidate.', dir=app)
        try:
            with os.fdopen(descriptor, 'w') as handle:
                handle.write(normalized)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, app / '.env')
        finally:
            Path(temporary).unlink(missing_ok=True)


def validate_prefix(prefix):
    if not prefix.startswith(PREFIX):
        raise ValueError('Use the retained uploads backup bucket.')
    suffix = prefix[len(PREFIX):]
    if not re.fullmatch(r'[A-Za-z0-9._/-]+', suffix) or '..' in suffix.split('/'):
        raise ValueError('Invalid uploads backup prefix.')
    return prefix.rstrip('/')


def validate_archive(archive, checksum):
    match = re.fullmatch(r'([0-9a-fA-F]{64}) [ *]uploads\.tgz\n?', checksum.read_text())
    if not match:
        raise ValueError('Invalid checksum manifest.')
    digest = hashlib.sha256()
    with archive.open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != match[1].lower():
        raise ValueError('Archive checksum mismatch.')
    count = total = 0
    with tarfile.open(archive, 'r:gz') as handle:
        for member in handle:
            path = PurePosixPath(member.name)
            count += 1
            total += member.size
            if path.is_absolute() or '..' in path.parts or '\\' in member.name:
                raise ValueError('Unsafe archive path.')
            if not (member.isfile() or member.isdir()):
                raise ValueError('Links and special files are not supported.')
            if count > 100000 or total > 10 * 1024**3:
                raise ValueError('Archive exceeds the lab restore limits.')


def validate_config(config):
    if config.get('region') != 'ap-southeast-7' or not IMAGE.fullmatch(config.get('image_uri', '')):
        raise ValueError('Unexpected region or image.')
    if not config.get('secret_arn', '').startswith('arn:aws:secretsmanager:ap-southeast-7:147997138960:secret:property-app/dev/config-'):
        raise ValueError('Unexpected configuration secret.')
    if not re.fullmatch(r'[a-z0-9.-]+\.rds\.amazonaws\.com', config.get('database_host', '')):
        raise ValueError('Invalid RDS endpoint.')
    for key in ('initialize_empty_database', 'enable_https', 'enable_backups'):
        if not isinstance(config.get(key), bool):
            raise ValueError('Invalid runtime feature flag.')
    if config.get('uploads_prefix'):
        validate_prefix(config['uploads_prefix'])
    return config


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['check', 'refresh-env', 'bootstrap-schema-env', 'check-archive', 'check-prefix'])
    parser.add_argument('paths', nargs='*')
    args = parser.parse_args()
    if args.action == 'check-prefix':
        if len(args.paths) != 1:
            parser.error('Supply one S3 prefix.')
        print(validate_prefix(args.paths[0]))
        return
    if args.action == 'check-archive':
        if len(args.paths) != 2:
            parser.error('Supply archive and checksum paths.')
        validate_archive(Path(args.paths[0]), Path(args.paths[1]))
        return
    config = validate_config(json.loads((ROOT / 'runtime.json').read_text()))
    if args.action != 'check':
        if os.geteuid() != 0:
            raise RuntimeError('Run as root.')
        if args.action == 'bootstrap-schema-env' and not config['initialize_empty_database']:
            raise RuntimeError('Schema initialization was not enabled for this new host.')
        refresh(config, args.action == 'bootstrap-schema-env')
    print('Runtime configuration verified; secret values were not logged.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, tarfile.TarError, subprocess.SubprocessError):
        raise SystemExit('Runtime operation failed. Check secret format, permissions or archive integrity; secret values were not logged.') from None
