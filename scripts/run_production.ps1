# Runs the app in Chrome using production values from the root .env file.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_production.ps1
#
# Add -Agents to let agents sign in on this local copy only, for testing them
# before Release 2 (docs/TEST_WALKTHROUGH.md 6B). The live site stays closed
# to agents. The app opens at http://localhost:8080.
#
# The publishable key is public by design: it is embedded in the web app.
# Never put a Supabase service_role key in .env or in --dart-define.

param([switch]$Agents)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$envPath = Join-Path $root ".env"

if (-not (Test-Path $envPath)) {
  throw "Missing .env file at $envPath"
}

$values = @{}
foreach ($rawLine in Get-Content $envPath) {
  $line = $rawLine.Trim()
  if ($line.Length -eq 0 -or $line.StartsWith("#")) {
    continue
  }

  $parts = $line -split "=", 2
  if ($parts.Count -ne 2) {
    continue
  }

  $key = $parts[0].Trim()
  $value = $parts[1].Trim()
  if (
    ($value.StartsWith('"') -and $value.EndsWith('"')) -or
    ($value.StartsWith("'") -and $value.EndsWith("'"))
  ) {
    $value = $value.Substring(1, $value.Length - 2)
  }

  $values[$key] = $value
}

$required = @("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", "ADMIN_EMAIL")
foreach ($key in $required) {
  if (-not $values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($values[$key])) {
    throw "Please set $key in .env"
  }
}

$defineKeys = @(
  "SUPABASE_URL",
  "SUPABASE_PUBLISHABLE_KEY",
  "ADMIN_EMAIL",
  "CLOUDINARY_CLOUD_NAME",
  "CLOUDINARY_UPLOAD_PRESET",
  "TURNSTILE_SITE_KEY",
  "UPI_ID",
  "UPI_PAYEE"
)

$defines = @()
foreach ($key in $defineKeys) {
  if ($values.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($values[$key])) {
    $defines += "--dart-define=$key=$($values[$key])"
  }
}
if ($Agents) {
  $defines += "--dart-define=AGENTS_MAY_SIGN_IN=true"
}

Push-Location $root
try {
  flutter run -d chrome --web-port 8080 @defines
} finally {
  Pop-Location
}
