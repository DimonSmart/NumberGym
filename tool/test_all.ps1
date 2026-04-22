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
  $testPath = Join-Path $memberPath 'test'
  if (-not (Test-Path $testPath)) {
    Write-Host "==> skip $($member.Path) (no test directory)"
    continue
  }
  Write-Host "==> flutter test $($member.Path)"
  Push-Location $memberPath
  try {
    flutter test
    if ($LASTEXITCODE -ne 0) {
      throw "flutter test failed for $($member.Path)"
    }
  } finally {
    Pop-Location
  }
}
