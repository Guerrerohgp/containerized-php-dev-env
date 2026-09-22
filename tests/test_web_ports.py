"""Exercise startup retries with a fake engine; never bind real host ports."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.name == 'nt', 'Bash startup helper')
class WebPortTests(unittest.TestCase):
    def launch(self, mode, answers=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            initial = '# keep me\nAPP_PORT=80\nSSL_PORT=443\nOTHER=value\n'
            (root / '.env').write_text(initial)
            provider = root / 'compose'
            provider.write_text('''#!/bin/sh
printf '%s %s\\n' "$APP_PORT" "$SSL_PORT" >> calls
if [ "$MODE" = unrelated ]; then echo 'image download failed'; exit 7; fi
if [ "$MODE" = both ] && [ "$APP_PORT" = 80 ]; then
    echo 'Bind for 0.0.0.0:80 failed: port is already allocated'; exit 1
fi
if [ "$MODE" = both ] && [ "$SSL_PORT" = 443 ]; then
    echo 'rootlessport cannot expose privileged port 443'; exit 1
fi
exit 0
''')
            provider.chmod(0o755)
            env = dict(os.environ, DOCKER_COMPOSE=str(provider), MODE=mode,
                       APP_PORT='80', SSL_PORT='443', PROJECT_DOMAIN='myapp.test')
            command = ['bash', str(ROOT / 'docker/scripts/up.sh')]
            if answers is None:
                result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=10)
            else:
                import pty
                master, slave = pty.openpty()
                try:
                    process = subprocess.Popen(command, cwd=root, env=env, stdin=slave,
                                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                    os.write(master, answers.encode())
                    stdout, stderr = process.communicate(timeout=10)
                    result = subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
                finally:
                    os.close(master)
                    os.close(slave)
            return result, initial, (root / '.env').read_text(), (root / 'calls').read_text()

    def test_standard_ports_no_prompt_or_env_rewrite(self):
        result, initial, saved, calls = self.launch('success')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('http://myapp.test ', result.stdout)
        self.assertIn('https://myapp.test ', result.stdout)
        self.assertEqual(initial, saved)
        self.assertEqual(calls, '80 443\n')

    def test_noninteractive_failure_preserves_settings(self):
        result, initial, saved, calls = self.launch('both')
        self.assertEqual(result.returncode, 1)
        self.assertIn('interactively', result.stderr)
        self.assertEqual(initial, saved)

    def test_unrelated_failure_is_not_retried(self):
        result, initial, saved, calls = self.launch('unrelated')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(initial, saved)
        self.assertEqual(calls, '80 443\n')

    def test_prompt_validates_retries_and_saves_only_on_success(self):
        result, initial, saved, calls = self.launch('both', 'bad\n443\n\n\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(saved, initial.replace('APP_PORT=80', 'APP_PORT=8080').replace('SSL_PORT=443', 'SSL_PORT=8443'))
        self.assertEqual(calls, '80 443\n8080 443\n8080 8443\n')
        self.assertIn('http://myapp.test:8080', result.stdout)

    def test_cancel_does_not_save_partial_choices(self):
        result, initial, saved, calls = self.launch('both', '\nq\n')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(initial, saved)


@unittest.skipUnless(os.name == 'nt', 'Requires Windows PowerShell')
class WindowsWebPortTests(unittest.TestCase):
    def test_startup_and_noninteractive_port_conflict(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                initial = 'APP_PORT=80\nSSL_PORT=443\n'
                (root / '.env').write_text(initial)
                (root / 'compose.cmd').write_text(
                    '@echo off\n' + ('echo Ports are not available: listen tcp 0.0.0.0:80: bind: permission denied\nexit /b 1\n'
                                    if fail else 'echo %*\nexit /b 0\n'))
                env = dict(os.environ, DOCKER_COMPOSE='compose.cmd',
                           PATH=str(root) + os.pathsep + os.environ['PATH'],
                           APP_PORT='80', SSL_PORT='443', PROJECT_DOMAIN='myapp.test')
                result = subprocess.run(
                    ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
                     str(ROOT / 'docker/scripts/up.ps1'), '--force-recreate', 'app'],
                    cwd=root, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode, 1 if fail else 0, result.stdout + result.stderr)
                self.assertIn('interactively' if fail else 'up -d --force-recreate app', result.stdout)
                self.assertEqual((root / '.env').read_text(), initial)
