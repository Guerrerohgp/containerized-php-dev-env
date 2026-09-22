param(
    [string]$Domain = $env:PROJECT_DOMAIN,
    [string]$Port = $env:APP_PORT,
    [string]$HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
)
$ErrorActionPreference = 'Stop'
try {
    if (!$Domain) { $Domain = $env:PROJECT_DOMAIN }
    if (!$Domain) { $Domain = 'myapp.test' }
    if (!$Port) { $Port = '80' }
    if ($Domain.Length -gt 253 -or $Domain -notmatch '^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$') {
        throw 'Invalid domain: use a hostname such as myapp.test, without a URL or port.'
    }
    foreach ($label in $Domain.Split('.')) {
        if ($label.Length -lt 1 -or $label.Length -gt 63 -or $label.StartsWith('-') -or $label.EndsWith('-')) {
            throw 'Invalid domain label.'
        }
    }
    if ($Port -notmatch '^[0-9]{1,5}$' -or [int]$Port -lt 1 -or [int]$Port -gt 65535) {
        throw 'APP_PORT must be between 1 and 65535.'
    }
    $Domain = $Domain.ToLowerInvariant()
    $reader = [IO.StreamReader]::new($HostsPath, [Text.UTF8Encoding]::new($false), $true)
    try {
        $content = $reader.ReadToEnd()
        $encoding = $reader.CurrentEncoding
    } finally { $reader.Dispose() }
    $exists = $false
    foreach ($line in ($content -split '\r?\n')) {
        $fields = (($line -split '#', 2)[0].Trim() -split '\s+')
        if ($fields.Length -gt 1 -and $fields[1..($fields.Length - 1)] -contains $Domain) {
            if ($fields[0] -ne '127.0.0.1') { throw "$Domain already points to another address. Resolve that hosts entry first." }
            $exists = $true
        }
    }
    if (!$exists) {
        $backup = "$HostsPath.dev-backup.$([guid]::NewGuid().ToString('N'))"
        Copy-Item -LiteralPath $HostsPath -Destination $backup
        [IO.File]::AppendAllText($HostsPath, "`r`n127.0.0.1`t$Domain # Added by dev hosts`r`n", $encoding)
        Write-Output "Added $Domain. Backup: $backup"
    } else {
        Write-Output "$Domain already points to 127.0.0.1."
    }
    $suffix = if ($Port -eq '80') { '' } else { ':' + $Port }
    Write-Output "Open http://${Domain}$suffix after starting the containers."
} catch {
    Write-Error "Hosts update failed: $_ If access was denied, run dev.bat hosts from a terminal opened as Administrator." -ErrorAction Continue
    exit 1
}
