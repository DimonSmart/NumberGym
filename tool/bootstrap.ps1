[CmdletBinding()]
param(
  [switch]$IncludeFrozen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'workspace.ps1')

$workspaceRoot = Get-WorkspaceRoot
$members = Get-WorkspaceMembers -IncludeFrozen:$IncludeFrozen

foreach ($member in $members) {
  $memberPath = Join-Path $workspaceRoot $member.Path
  Write-Host "==> flutter pub get $($member.Path)"
  Push-Location $memberPath
  try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) {
      throw "flutter pub get failed for $($member.Path)"
    }
  } finally {
    Pop-Location
  }
}
