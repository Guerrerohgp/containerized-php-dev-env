"""Native CMD regression checks; run with Python unittest on Windows."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == 'nt', 'Requires Windows CMD')
class WindowsDevTests(unittest.TestCase):
    def launch(self, command, provider=None):
        with tempfile.TemporaryDirectory(prefix='dev-cmd-') as directory:
            fixture = Path(directory)
            shutil.copy(ROOT / 'dev.bat', fixture / 'dev.bat')
            system32 = Path(os.environ['SystemRoot']) / 'System32'
            env = dict(os.environ, PATH=str(system32))
            env.pop('DOCKER_COMPOSE', None)
            for key in ('lite', 'PHP_VERSION', 'DEV_LITE_OVERRIDE'):
                env.pop(key, None)
            if provider:
                env['DOCKER_COMPOSE'] = provider
            return subprocess.run(
                [str(system32 / 'cmd.exe'), '/d', '/c', 'dev.bat ' + command],
                cwd=fixture, env=env, capture_output=True, text=True,
            )

    def test_missing_provider_reports_error_without_cmd_parse_failure(self):
        result = self.launch('ps')
        self.assertEqual(result.returncode, 1)
        self.assertIn('No container compose tool installed (podman-compose or docker-compose).', result.stdout)
        self.assertNotIn('unexpected', (result.stdout + result.stderr).lower())

    def test_composer_forwards_dot_destination(self):
        result = self.launch('composer create-project laravel/laravel .', 'echo')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('exec app dev-composer create-project laravel/laravel .', result.stdout)


if __name__ == '__main__':
    unittest.main()
