"""Run with: python3 -m unittest discover -s tests -v"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LiteMode(unittest.TestCase):
    def launch(self, settings='', override=None):
        with tempfile.TemporaryDirectory(prefix='dev-lite-test-') as directory:
            fixture = Path(directory)
            (fixture / '.env').write_text(settings)
            shutil.copy(ROOT / 'dev', fixture / 'dev')
            provider = fixture / 'provider'
            provider.write_text(
                '#!' + sys.executable + '\nimport json, os, sys\n'
                'print(json.dumps({"args": sys.argv[1:], "env": '
                '{key: os.environ.get(key) for key in '
                '["DEV_DOCKERFILE", "DEV_IMAGE_SUFFIX", "PHP_VERSION"]}}))\n'
            )
            provider.chmod(0o755)
            env = os.environ.copy()
            for key in ('lite', 'PHP_VERSION', 'DEV_DOCKERFILE', 'DEV_IMAGE_SUFFIX'):
                env.pop(key, None)
            env['DOCKER_COMPOSE'] = './provider compose'
            if override is not None:
                env['lite'] = override
            return subprocess.run(
                [str(fixture / 'dev'), 'ps'],
                cwd=fixture, env=env, text=True, capture_output=True,
            )

    def test_mode_selection(self):
        for settings, override, dockerfile, suffix in [
            ('', None, 'Dockerfile', ''),
            ('lite=false\nPHP_VERSION=7.4\n', None, 'Dockerfile', ''),
            ('lite=true\nPHP_VERSION=8.5\n', None, 'Dockerfile.lite', '-lite'),
            ('lite=false\n', 'true', 'Dockerfile.lite', '-lite'),
            ('lite=true\n', 'false', 'Dockerfile', ''),
        ]:
            with self.subTest(settings=settings, override=override):
                result = self.launch(settings, override)
                self.assertEqual(result.returncode, 0, result.stderr)
                data = json.loads(result.stdout)
                self.assertEqual(data['args'], ['compose', 'ps'])
                self.assertEqual(data['env']['DEV_DOCKERFILE'], dockerfile)
                self.assertEqual(data['env']['DEV_IMAGE_SUFFIX'], suffix)

    def test_invalid_settings_fail_before_compose(self):
        for settings, message in [
            ('lite=true\nPHP_VERSION=7.4\n', 'requires PHP_VERSION=8.5'),
            ('lite=yes\n', 'use true or false'),
        ]:
            with self.subTest(settings=settings):
                result = self.launch(settings)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)
                self.assertEqual(result.stdout, '')

    @unittest.skipUnless(shutil.which('docker'), 'Docker Compose CLI required')
    def test_compose_image_and_build_selection(self):
        for mode, version in [('false', '8.5'), ('true', '8.5'), ('false', '7.4')]:
            with self.subTest(mode=mode, version=version):
                selected = json.loads(self.launch(f'lite={mode}\nPHP_VERSION={version}\n').stdout)
                env = os.environ.copy()
                env.update(selected['env'])
                config = json.loads(subprocess.check_output(
                    ['docker', 'compose', '--env-file', os.devnull,
                     '-f', str(ROOT / 'docker-compose.yml'), 'config', '--format', 'json'],
                    env=env, text=True,
                ))
                app = config['services']['app']
                self.assertEqual(app['build']['dockerfile'], selected['env']['DEV_DOCKERFILE'])
                suffix = '-lite' if mode == 'true' else ''
                self.assertEqual(app['image'], f'sail-{version}{suffix}/app')
                self.assertIn('sail-mysql', config['volumes'])


if __name__ == '__main__':
    unittest.main()
