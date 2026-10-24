import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runtime', Path(__file__).resolve().parents[1] / 'bootstrap/runtime.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)
HOST = 'property-app-db.example.ap-southeast-7.rds.amazonaws.com'
ENV = "DATABASE_PASSWORD='test-$literal#value'\nJWT_SECRET=unit-test-only\nJWT_EXPIRATION_TIME=1h\nDATABASE_LOGGING=true\n"


class BootstrapTests(unittest.TestCase):
    def test_literal_secret_and_endpoint_override(self):
        value = runtime.normalize_env(ENV, HOST)
        self.assertIn('DATABASE_PASSWORD=test-$literal#value\n', value)
        self.assertIn(f'DATABASE_HOST={HOST}\n', value)
        self.assertIn('DATABASE_SSL=true\n', value)
        self.assertIn('DATABASE_SYNCHRONIZE=false\n', value)
        self.assertIn('DATABASE_LOGGING=false\n', value)

    def test_initialization_requires_explicit_argument(self):
        self.assertIn('DATABASE_SYNCHRONIZE=true\n', runtime.normalize_env(ENV, HOST, True))

    def test_shell_syntax_is_literal(self):
        value = runtime.normalize_env(ENV.replace('unit-test-only', '$(touch /tmp/not-executed)`id`'), HOST)
        self.assertIn('JWT_SECRET=$(touch /tmp/not-executed)`id`\n', value)

    def test_duplicate_password_is_rejected(self):
        with self.assertRaises(ValueError):
            runtime.normalize_env(ENV + 'DATABASE_PASSWORD=second\n', HOST)

    def test_inline_password_comment_is_rejected(self):
        with self.assertRaises(ValueError):
            runtime.normalize_env(ENV.replace("'test-$literal#value'", 'value # comment'), HOST)

    def test_multiline_value_is_rejected(self):
        with self.assertRaises(ValueError):
            runtime.normalize_env(ENV.replace('unit-test-only', '"first\\nsecond"'), HOST)

    def test_endpoint_injection_is_rejected(self):
        with self.assertRaises(ValueError):
            runtime.normalize_env(ENV, HOST + '\nINJECT=true')

    def test_refresh_is_private_atomic_and_silent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'app'
            app.mkdir()
            result = subprocess.CompletedProcess([], 0, json.dumps({'SecretString': ENV}).encode(), b'')
            output = io.StringIO()
            with patch.object(runtime.subprocess, 'run', return_value=result), contextlib.redirect_stdout(output):
                runtime.refresh({'region': 'ap-southeast-7', 'secret_arn': 'test', 'database_host': HOST}, root=root, app=app)
            self.assertEqual(output.getvalue(), '')
            self.assertEqual((app / '.env').stat().st_mode & 0o777, 0o600)
            self.assertEqual(list(app.glob('.env.candidate.*')), [])

    def test_failed_refresh_preserves_current_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = root / 'app'
            app.mkdir()
            (app / '.env').write_text('keep')
            result = subprocess.CompletedProcess([], 1, b'', b'do-not-log')
            with patch.object(runtime.subprocess, 'run', return_value=result), self.assertRaises(RuntimeError):
                runtime.refresh({'region': 'ap-southeast-7', 'secret_arn': 'test'}, root=root, app=app)
            self.assertEqual((app / '.env').read_text(), 'keep')

    def archive(self, directory, name='documents/test.txt', kind=None):
        archive = Path(directory) / 'uploads.tgz'
        with tarfile.open(archive, 'w:gz') as handle:
            member = tarfile.TarInfo(name)
            if kind:
                member.type = kind
                member.linkname = '/etc/passwd'
                handle.addfile(member)
            else:
                member.size = 4
                handle.addfile(member, io.BytesIO(b'test'))
        checksum = Path(directory) / 'uploads.tgz.sha256'
        checksum.write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  uploads.tgz\n')
        return archive, checksum

    def test_safe_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime.validate_archive(*self.archive(directory))

    def test_archive_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(ValueError):
            runtime.validate_archive(*self.archive(directory, '../outside'))

    def test_archive_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(ValueError):
            runtime.validate_archive(*self.archive(directory, 'link', tarfile.SYMTYPE))

    def test_checksum_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, checksum = self.archive(directory)
            archive.write_bytes(archive.read_bytes() + b'changed')
            with self.assertRaises(ValueError):
                runtime.validate_archive(archive, checksum)

    def test_prefix_stays_in_backup_bucket(self):
        for value in ['s3://other-bucket/uploads/test', runtime.PREFIX + '../other']:
            with self.assertRaises(ValueError):
                runtime.validate_prefix(value)


if __name__ == '__main__':
    unittest.main()
