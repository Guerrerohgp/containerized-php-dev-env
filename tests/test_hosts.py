"""Hosts helpers are tested only against temporary files, never system hosts."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HostsTests(unittest.TestCase):
    def test_hosts_helpers(self):
        engines = []
        if os.name != 'nt' and shutil.which('bash'):
            engines.append(('bash', ['bash', str(ROOT / 'docker/scripts/hosts.sh')]))
        powershell = shutil.which('pwsh') or shutil.which('powershell.exe')
        if powershell:
            engines.append(('powershell', [powershell, '-NoProfile', '-File', str(ROOT / 'docker/scripts/hosts.ps1')]))
        if not engines:
            self.skipTest('No supported shell installed')
        for engine, command in engines:
            with self.subTest(engine=engine), tempfile.TemporaryDirectory() as directory:
                hosts = Path(directory) / 'hosts'
                original = b'127.0.0.1 localhost\n192.0.2.5 other.test # keep this\n'
                hosts.write_bytes(original)

                def invoke(domain='myapp.test', port='8080'):
                    args = [domain, port, str(hosts)] if engine == 'bash' else ['-Domain', domain, '-Port', port, '-HostsPath', str(hosts)]
                    return subprocess.run(command + args, capture_output=True, text=True)

                result = invoke()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('http://myapp.test:8080', result.stdout)
                updated = hosts.read_bytes()
                self.assertTrue(updated.startswith(original))
                backups = list(Path(directory).glob('hosts.dev-backup.*'))
                self.assertEqual(len(backups), 1)
                self.assertEqual(backups[0].read_bytes(), original)
                self.assertEqual(invoke('MYAPP.TEST').returncode, 0)
                self.assertEqual(hosts.read_bytes(), updated)
                self.assertNotEqual(invoke('other.test').returncode, 0)
                for invalid in ('https://myapp.test', 'myapp.test:8080', '-bad.test', 'a..test', 'bad\nname', 'a' * 64 + '.test'):
                    self.assertNotEqual(invoke(invalid).returncode, 0, invalid)
                self.assertNotEqual(invoke(port='65536').returncode, 0)
                self.assertEqual(hosts.read_bytes(), updated)
                hosts.write_text('127.0.0.1 localhost myapp.test # alias\n')
                self.assertEqual(invoke().returncode, 0)
                self.assertEqual(hosts.read_text(), '127.0.0.1 localhost myapp.test # alias\n')

    @unittest.skipIf(os.name == 'nt', 'Bash launcher test')
    def test_launcher_uses_env_without_container_engine(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy(ROOT / 'dev', root / 'dev')
            (root / '.env').write_text('PROJECT_DOMAIN=project.test\nAPP_PORT=9090\nlite=invalid\n')
            scripts = root / 'docker/scripts'
            scripts.mkdir(parents=True)
            (scripts / 'hosts.sh').write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            env = dict(os.environ, DOCKER_COMPOSE='missing-engine')
            for args, domain in [([], 'project.test'), (['custom.test'], 'custom.test')]:
                result = subprocess.run(['bash', str(root / 'dev'), 'hosts', *args], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), [domain, '9090'])
