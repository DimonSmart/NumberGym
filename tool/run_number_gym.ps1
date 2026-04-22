[CmdletBinding()]
param(
  [string]$DeviceId,
  [switch]$Release,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$ExtraArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'workspace.ps1')

$workspaceRoot = Get-WorkspaceRoot
$appPath = Join-Path $workspaceRoot 'apps/number_gym'

$flutterArgs = @('run')
if ($Release) {
  $flutterArgs += '--release'
}
if ($DeviceId) {
  $flutterArgs += @('-d', $DeviceId)
}
if ($ExtraArgs) {
  $flutterArgs += $ExtraArgs
}

Push-Location $appPath
try {
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) {
    throw "flutter $($flutterArgs -join ' ') failed."
  }
} finally {
  Pop-Location
}
