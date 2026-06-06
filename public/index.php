<?php
$projectName = getenv('PROJECT_NAME') ?: 'myapp';
$projectDomain = getenv('PROJECT_DOMAIN') ?: 'myapp.test';
$phpVersion = PHP_VERSION;
$mailpitEnabled = getenv('MAILPIT_ENABLED') !== false ? strtolower(getenv('MAILPIT_ENABLED')) === 'true' : true;
$mailpitPort = getenv('FORWARD_MAILPIT_DASHBOARD_PORT') ?: '8025';
$appPort = getenv('APP_PORT') ?: '80';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($projectName) ?> - PHP Development Environment</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #e2e8f0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
        .container { max-width: 640px; width: 100%; padding: 2rem; }
        .logo { text-align: center; margin-bottom: 2rem; }
        .logo h1 { font-size: 2.5rem; font-weight: 700; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
        .logo p { color: #94a3b8; margin-top: 0.5rem; font-size: 1.1rem; }
        .card { background: #1e293b; border-radius: 12px; padding: 1.5rem; margin-bottom: 1rem; border: 1px solid #334155; }
        .card h2 { font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; color: #64748b; margin-bottom: 1rem; }
        .info-row { display: flex; justify-content: space-between; align-items: center; padding: 0.5rem 0; border-bottom: 1px solid #334155; }
        .info-row:last-child { border-bottom: none; }
        .info-row .label { color: #94a3b8; }
        .info-row .value { color: #e2e8f0; font-weight: 500; font-family: 'SF Mono', 'Fira Code', monospace; font-size: 0.9rem; }
        .badge { display: inline-block; padding: 0.15rem 0.5rem; border-radius: 9999px; font-size: 0.75rem; font-weight: 600; }
        .badge-green { background: #064e3b; color: #34d399; }
        .badge-blue { background: #1e3a5f; color: #60a5fa; }
        .links { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
        .link { display: block; padding: 1rem; background: #1e293b; border: 1px solid #334155; border-radius: 8px; text-decoration: none; color: #e2e8f0; text-align: center; transition: all 0.2s; }
        .link:hover { border-color: #667eea; background: #1e293b; transform: translateY(-1px); }
        .link .icon { font-size: 1.5rem; margin-bottom: 0.25rem; }
        .link .text { font-size: 0.85rem; color: #94a3b8; }
        .footer { text-align: center; margin-top: 2rem; color: #475569; font-size: 0.8rem; }
        .footer a { color: #667eea; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <h1><?= htmlspecialchars($projectName) ?></h1>
            <p>PHP Development Environment</p>
        </div>

        <div class="card">
            <h2>Environment</h2>
            <div class="info-row">
                <span class="label">PHP Version</span>
                <span class="value"><?= htmlspecialchars($phpVersion) ?></span>
            </div>
            <div class="info-row">
                <span class="label">Domain</span>
                <span class="value"><?= htmlspecialchars($projectDomain) ?></span>
            </div>
            <div class="info-row">
                <span class="label">Server</span>
                <span class="value"><?= htmlspecialchars($_SERVER['SERVER_SOFTWARE'] ?? 'Nginx') ?></span>
            </div>
            <div class="info-row">
                <span class="label">Status</span>
                <span class="badge badge-green">Running</span>
            </div>
        </div>

        <div class="card">
            <h2>Services</h2>
            <div class="info-row">
                <span class="label">MySQL</span>
                <span class="value"><?= htmlspecialchars(getenv('DB_DATABASE') ?: 'myapp') ?> <span class="badge badge-blue">:<?= htmlspecialchars(getenv('FORWARD_DB_PORT') ?: '3306') ?></span></span>
            </div>
            <div class="info-row">
                <span class="label">PostgreSQL</span>
                <span class="value"><?= htmlspecialchars(getenv('POSTGRES_DB') ?: 'myapp') ?> <span class="badge badge-blue">:<?= htmlspecialchars(getenv('FORWARD_POSTGRES_PORT') ?: '5432') ?></span></span>
            </div>
            <div class="info-row">
                <span class="label">Redis</span>
                <span class="value"><span class="badge badge-blue">:<?= htmlspecialchars(getenv('FORWARD_REDIS_PORT') ?: '6379') ?></span></span>
            </div>
            <?php if ($mailpitEnabled): ?>
            <div class="info-row">
                <span class="label">Mailpit</span>
                <span class="value"><a href="http://localhost:<?= htmlspecialchars($mailpitPort) ?>" style="color: #667eea; text-decoration: none;">Dashboard :<?= htmlspecialchars($mailpitPort) ?></a></span>
            </div>
            <?php endif; ?>
        </div>

        <div class="card">
            <h2>Quick Links</h2>
            <div class="links">
                <a href="http://localhost:<?= htmlspecialchars($mailpitPort) ?>" class="link">
                    <div class="icon">&#9993;</div>
                    <div class="text">Mailpit</div>
                </a>
                <a href="?phpinfo=1" class="link">
                    <div class="icon">&#9432;</div>
                    <div class="text">phpinfo()</div>
                </a>
            </div>
        </div>

        <div class="footer">
            <p>Powered by <a href="https://github.com/Guerrerohgp/phplocaldocker">Plod</a> &mdash; Replace this page with your project files.</p>
        </div>
    </div>
</body>
</html>
<?php if (isset($_GET['phpinfo'])) { phpinfo(); exit; } ?>
