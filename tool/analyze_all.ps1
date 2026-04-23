[CmdletBinding()]
param(
  [switch]$IncludeScaffolds
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'workspace.ps1')

$workspaceRoot = Get-WorkspaceRoot
$members = Get-WorkspaceMembers -IncludeScaffolds:$IncludeScaffolds

foreach ($member in $members) {
  $memberPath = Join-Path $workspaceRoot $member.Path
  Write-Host "==> flutter analyze $($member.Path)"
  Push-Location $memberPath
  try {
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
      throw "flutter analyze failed for $($member.Path)"
    }
  } finally {
    Pop-Location
  }
}
