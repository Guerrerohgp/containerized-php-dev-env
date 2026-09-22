"""Contract tests for startup and application command forwarding; no Docker daemon needed."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DevTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.bin = self.work / 'bin'
        self.bin.mkdir()
        self.log = self.work / 'calls'
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', CALLS=str(self.log))
        for name in ('dev-exec', 'configure-web', 'compose'):
            stub = self.bin / name
            stub.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps([os.path.basename(sys.argv[0]), *sys.argv[1:]]) + '\\n')
sys.exit(int(os.environ.get('COMPOSER_STATUS', '0')) if sys.argv[0].endswith('dev-exec') else 0)
''')
            stub.chmod(0o755)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def composer(self, *args, status=0):
        return subprocess.run(['bash', str(ROOT / 'docker/php/dev-composer'), *args],
                              env=dict(self.env, COMPOSER_STATUS=str(status)), capture_output=True)

    def test_wordpress_refreshes_only_after_success(self):
        args = ['core', 'download', '--locale=es_ES']
        for status in (0, 7):
            with self.subTest(status=status):
                self.log.unlink(missing_ok=True)
                result = subprocess.run(
                    ['bash', str(ROOT / 'docker/php/dev-wp'), *args],
                    env=dict(self.env, COMPOSER_STATUS=str(status)), capture_output=True)
                self.assertEqual(result.returncode, status)
                expected = [['dev-exec', 'wp', *args]]
                if status == 0:
                    expected.append(['configure-web'])
                self.assertEqual(self.calls(), expected)

    def test_wordpress_routes_through_wrapper(self):
        shutil.copy(ROOT / 'dev', self.work / 'dev')
        result = subprocess.run(
            ['bash', str(self.work / 'dev'), 'wp', 'core', 'download'],
            env=dict(self.env, DOCKER_COMPOSE='compose'), capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [['compose', 'exec', '-T', 'app', 'dev-wp', 'core', 'download']])

    def test_podman_namespace_selection(self):
        shutil.copy(ROOT / 'dev', self.work / 'dev')
        (self.work / '.env').write_text('WWWUSER=1234\nWWWGROUP=2345\n')
        for name, body in {
            'uname': '#!/bin/sh\necho Linux\n',
            'podman': '#!/bin/sh\necho "$TEST_ROOTLESS"\n',
            'podman-compose': "#!/usr/bin/env python3\nimport os\nprint(os.environ.get('COMPOSE_FILE', ''))\n",
        }.items():
            stub = self.bin / name
            stub.write_text(body)
            stub.chmod(0o755)
        for rootless, existing, expected in [
            ('true', '', 'docker-compose.yml:docker-compose.podman.yml'),
            ('false', '', ''),
            ('true', 'custom.yml', 'custom.yml:docker-compose.podman.yml'),
        ]:
            with self.subTest(rootless=rootless, existing=existing):
                env = dict(self.env, DOCKER_COMPOSE='podman-compose',
                           TEST_ROOTLESS=rootless, COMPOSE_FILE=existing,
                           COMPOSE_PATH_SEPARATOR=':')
                result = subprocess.run(['bash', str(self.work / 'dev'), 'ps'],
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)

    def test_default_destination(self):
        self.assertEqual(self.composer('create-project', 'laravel/laravel').returncode, 0)
        self.assertEqual(self.calls(), [['dev-exec', 'composer', 'create-project', 'laravel/laravel', '.'], ['configure-web']])

    def test_options_and_explicit_destination(self):
        args = ['create-project', '--stability', 'dev', 'vendor/project', 'my app', '^1.0']
        self.assertEqual(self.composer(*args).returncode, 0)
        self.assertEqual(self.calls()[0], ['dev-exec', 'composer', *args])

    def test_options_without_destination(self):
        args = ['create-project', '--prefer-dist', '--stability', 'stable', 'vendor/project']
        self.composer(*args)
        self.assertEqual(self.calls()[0], ['dev-exec', 'composer', *args, '.'])

    def test_failed_install_does_not_activate(self):
        self.assertEqual(self.composer('create-project', 'vendor/project', status=7).returncode, 7)
        self.assertEqual(len(self.calls()), 1)

    def test_other_commands_unchanged(self):
        self.composer('require', 'vendor/package:^2.0')
        self.assertEqual(self.calls()[0], ['dev-exec', 'composer', 'require', 'vendor/package:^2.0'])

    def test_web_root_selection(self):
        app = self.work / 'src'
        app.mkdir()
        config = self.work / 'nginx.conf'
        config.write_text('    root /var/www/html/public;\n')
        nginx = self.bin / 'nginx'
        nginx.write_text('#!/bin/sh\nexit 0\n')
        nginx.chmod(0o755)
        script = (ROOT / 'docker/php/configure-web').read_text()
        script = script.replace('/var/www/html', str(app))
        script = script.replace('/etc/nginx/sites-available/default', str(config))
        script = script.replace('/run/nginx.pid', str(self.work / 'nginx.pid'))
        for folder, expected in [(None, '/var/www/welcome'), ('index.php', str(app)), ('web', str(app / 'web')), ('public', str(app / 'public'))]:
            if folder == 'index.php':
                (app / folder).touch()
            elif folder:
                (app / folder).mkdir()
            result = subprocess.run(['bash', '-c', script], env=dict(self.env, APP_DOCUMENT_ROOT=''), capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(config.read_text().strip(), f'root {expected};')
        result = subprocess.run(['bash', '-c', script], env=dict(self.env, APP_DOCUMENT_ROOT='../outside'), capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_first_up_is_repeatable_and_src_empty(self):
        shutil.copy(ROOT / 'dev', self.work / 'dev')
        shutil.copy(ROOT / '.env.example', self.work / '.env.example')
        scripts = self.work / 'docker/scripts'
        scripts.mkdir(parents=True)
        shutil.copy(ROOT / 'docker/scripts/up.sh', scripts / 'up.sh')
        certs = self.work / 'docker/ssl/certs'
        certs.mkdir(parents=True)
        generator = certs.parent / 'generate-certs.sh'
        generator.write_text('printf cert > docker/ssl/certs/server.crt\nprintf key > docker/ssl/certs/server.key\n')
        env = dict(self.env, DOCKER_COMPOSE='compose')
        env.pop('SUDO_UID', None)
        env.pop('SUDO_GID', None)
        for _ in range(2):
            result = subprocess.run(['bash', str(self.work / 'dev'), 'up'], env=env, cwd='/', capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            if _ == 0:
                original = (self.work / '.env').read_bytes()
        self.assertEqual((self.work / '.env').read_bytes(), original)
        self.assertEqual(list((self.work / 'src').iterdir()), [])
        self.assertEqual(self.calls(), [['compose', 'up', '-d'], ['compose', 'up', '-d']])


if __name__ == '__main__':
    unittest.main()
