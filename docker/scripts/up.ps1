param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ComposeArgs)
$ErrorActionPreference = 'Stop'
if (!$env:APP_PORT) { $env:APP_PORT = '80' }
if (!$env:SSL_PORT) { $env:SSL_PORT = '443' }
$original = @{ APP_PORT = $env:APP_PORT; SSL_PORT = $env:SSL_PORT }
# Match the launcher's supported executable plus optional 'compose' subcommand.
$provider = $env:DOCKER_COMPOSE -split '\s+'
$executable = $provider[0]
$prefix = @($provider | Select-Object -Skip 1)
while ($true) {
    $log = @()
    $LASTEXITCODE = 1
    $ErrorActionPreference = 'Continue'
    & $executable @prefix up -d @ComposeArgs 2>&1 | ForEach-Object { $log += "$_"; Write-Host "$_" }
    $status = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($status -eq 0) { break }
    $key = $null
    foreach ($candidate in @('APP_PORT', 'SSL_PORT')) {
        $port = [Environment]::GetEnvironmentVariable($candidate)
        $matchesPort = $log | Where-Object {
            $_ -match 'bind|listen|expose privileged port|port is already allocated|ports are not available|access permissions' -and
            ($_ -replace '->.*', '') -match "(^|[^0-9])$([regex]::Escape($port))([^0-9]|$)"
        }
        if ($matchesPort) { $key = $candidate; break }
    }
    if (!$key) { exit $status }
    if ([Console]::IsInputRedirected) {
        Write-Host "Cannot publish $key. Set another port in .env and retry, or run dev.bat up interactively."
        exit $status
    }
    $suggested = if ($key -eq 'APP_PORT') { '8080' } else { '8443' }
    Write-Host "Cannot publish $key=$([Environment]::GetEnvironmentVariable($key)): port occupied or permission denied."
    while ($true) {
        $answer = Read-Host "Replacement for $key [$suggested], or q to cancel"
        if ($answer -eq 'q') { exit $status }
        if (!$answer) { $answer = $suggested }
        $other = if ($key -eq 'APP_PORT') { $env:SSL_PORT } else { $env:APP_PORT }
        if ($answer -match '^[0-9]{1,5}$' -and [int]$answer -ge 1 -and [int]$answer -le 65535 -and
            [int]$answer -ne [int]$other -and [int]$answer -ne [int][Environment]::GetEnvironmentVariable($key)) { break }
        Write-Host 'Choose a different port between 1 and 65535, distinct from the other web port.'
    }
    [Environment]::SetEnvironmentVariable($key, [string][int]$answer)
}
$changed = $false
$content = [IO.File]::ReadAllText((Join-Path $PWD '.env'))
foreach ($key in @('APP_PORT', 'SSL_PORT')) {
    $value = [Environment]::GetEnvironmentVariable($key)
    if ($value -ne $original[$key]) {
        $changed = $true
        if ($content -match "(?m)^${key}=[^\r\n]*") {
            $content = [regex]::Replace($content, "(?m)^${key}=[^\r\n]*", "$key=$value")
        } else { $content += "`r`n$key=$value`r`n" }
    }
}
if ($changed) {
    [IO.File]::WriteAllText((Join-Path $PWD '.env'), $content, [Text.UTF8Encoding]::new($false))
    Write-Host 'Saved accepted web ports to .env.'
}
$domain = if ($env:PROJECT_DOMAIN) { $env:PROJECT_DOMAIN } else { 'localhost' }
$httpSuffix = if ($env:APP_PORT -eq '80') { '' } else { ':' + $env:APP_PORT }
$httpsSuffix = if ($env:SSL_PORT -eq '443') { '' } else { ':' + $env:SSL_PORT }
Write-Host "Application: http://${domain}$httpSuffix (run dev.bat hosts to register the domain)"
Write-Host "HTTPS: https://${domain}$httpsSuffix (requires a trusted certificate)"
exit 0
