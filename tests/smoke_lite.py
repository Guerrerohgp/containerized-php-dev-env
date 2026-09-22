"""Run: python3 tests/smoke_lite.py IMAGE [--engine podman] [--compare FULL_IMAGE]."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('image')
parser.add_argument('--engine', default='docker', choices=['docker', 'podman'])
parser.add_argument('--compare', help='Verify module parity and a smaller size than this full image')
args = parser.parse_args()


def run(*command):
    return subprocess.check_output([args.engine, *command], text=True).strip()


modules = json.loads(run('run', '--rm', '--entrypoint', 'php', args.image,
                         '-r', 'echo json_encode(get_loaded_extensions());'))
required = {'bcmath', 'curl', 'dom', 'gd', 'imap', 'intl', 'mbstring', 'mysqli',
            'pdo_mysql', 'pdo_pgsql', 'pdo_sqlite', 'pgsql', 'redis', 'SimpleXML',
            'soap', 'sqlite3', 'tidy', 'xdebug', 'xml', 'xmlreader', 'xmlwriter',
            'zip', 'Zend OPcache'}
assert required.issubset(modules), required.difference(modules)
subprocess.run([args.engine, 'run', '--rm', '--entrypoint', 'sh', args.image, '-ec', '''
    . /etc/os-release
    test "$ID" = alpine
    for tool in gcc g++ make phpize docker-php-ext-install python3 supervisord; do
        if command -v "$tool"; then echo "Unexpected build tool: $tool"; exit 1; fi
    done
    php-fpm -t
    nginx -t
    bash --version
    node --version
    npm --version
    npx --version
    composer --version
    wp --allow-root --info
    git --version
    sqlite3 --version
'''], check=True)

with tempfile.TemporaryDirectory(prefix='lite-smoke-') as directory:
    root = Path(directory)
    root.chmod(0o755)
    public = root / 'public'
    public.mkdir(mode=0o755)
    (public / 'index.php').write_text('''<?php
echo json_encode([
    PHP_MAJOR_VERSION, PHP_MINOR_VERSION, ini_get('post_max_size'),
    ini_get('upload_max_filesize'), ini_get('max_execution_time'),
    getenv('LITE_SMOKE_TEST'), get_loaded_extensions(),
    (new NumberFormatter('fr_FR', NumberFormatter::DECIMAL))->format(1.5)
]);
''')
    container = run('run', '-d', '-e', 'XDEBUG_MODE=off',
                    '-e', 'LITE_SMOKE_TEST=visible',
                    '-v', str(root) + ':/var/www/html:ro,z', args.image)
    def check_http():
        for attempt in range(30):
            response = subprocess.run([args.engine, 'exec', container, 'curl', '-fsS',
                                       'http://localhost/smoke-route'], text=True, capture_output=True)
            if response.returncode == 0:
                data = json.loads(response.stdout)
                assert data[:6] == [8, 5, '100M', '100M', '300', 'visible'], data
                assert required.issubset(data[6]), required.difference(data[6])
                assert data[7] == '1,5', 'Full ICU locale data is missing'
                return
            time.sleep(1)
        print(run('logs', container))
        raise RuntimeError('HTTP smoke test timed out')

    try:
        check_http()
        assert run('exec', container, 'cat', '/proc/1/comm') == 's6-svscan'
        for service in ('php-fpm', 'nginx'):
            path = '/run/service/' + service
            old_pid = run('exec', container, '/command/s6-svstat', '-o', 'pid', path)
            assert old_pid.isdigit() and old_pid != '0', old_pid
            run('exec', container, 'sh', '-c', 'kill -KILL "$1"', 'sh', old_pid)
            for attempt in range(30):
                new_pid = run('exec', container, '/command/s6-svstat', '-o', 'pid', path)
                if new_pid.isdigit() and new_pid not in ('0', old_pid):
                    break
                time.sleep(1)
            else:
                raise RuntimeError(service + ' did not restart')
            check_http()
            print('PASS: s6 restarted ' + service + ' after SIGKILL')
        assert '/smoke-route' in run('logs', container), 'HTTP logs are missing'
        run('stop', '--time', '10', container)
        assert run('inspect', '--format', '{{.State.ExitCode}}', container) == '0'
        print('PASS: graceful container shutdown')
    finally:
        run('rm', '-f', container)

if args.compare:
    full_modules = json.loads(run('run', '--rm', '--entrypoint', 'php', args.compare,
                                 '-r', 'echo json_encode(get_loaded_extensions());'))
    assert set(modules) == set(full_modules), (modules, full_modules)
    lite_size = int(run('image', 'inspect', args.image, '--format', '{{.Size}}'))
    full_size = int(run('image', 'inspect', args.compare, '--format', '{{.Size}}'))
    assert lite_size < full_size, (lite_size, full_size)
    print(f'Image size: {full_size / 1e6:.1f} MB -> {lite_size / 1e6:.1f} MB '
          f'({100 * (1 - lite_size / full_size):.1f}% smaller)')
print('PASS: PHP 8.5 modules, development tools, build-tool exclusion, ICU locales, Nginx/FPM HTTP, s6 restarts, and shutdown')
