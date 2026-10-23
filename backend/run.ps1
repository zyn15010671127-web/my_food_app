param([int]$Port = 8010, [switch]$SkipInstall, [switch]$Reload)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $pythonPath)) {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 -m venv .venv
    } else {
        & python -m venv .venv
    }
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create Python environment. Install Python 3.12 or later.' }
}
if (-not $SkipInstall) {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'wheelhouse')) {
        & $pythonPath -m pip install --no-index --find-links wheelhouse -r requirements-lock.txt
    } else {
        & $pythonPath -m pip install -r requirements-lock.txt
    }
    if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed. Check the network or use the offline package.' }
}
if (-not (Test-Path -LiteralPath '.env')) {
    Copy-Item -LiteralPath '.env.example' -Destination '.env'
}
& $pythonPath scripts/init_db.py
if ($LASTEXITCODE -ne 0) { throw 'Database initialization failed. See the message above.' }
Write-Host "API docs: http://127.0.0.1:$Port/docs"
Write-Host 'Demo: demo_user / DemoPass123!'
Write-Host 'Admin: admin / AdminDemo123!'
$serverArgs = @('-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', "$Port")
if ($Reload) { $serverArgs += '--reload' }
& $pythonPath @serverArgs
exit $LASTEXITCODE
