[CmdletBinding()]
param(
  [string]$BaseHref = '/NumberGym/verb-gym/',
  [string]$PagesUrl = 'https://dimonsmart.github.io/NumberGym/verb-gym/',
  [string]$CommitMessage = 'Deploy VerbGym web',
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'publish_github_pages_app.ps1') `
  -AppPath 'apps/verb_gym' `
  -DisplayName 'VerbGym' `
  -BaseHref $BaseHref `
  -PagesUrl $PagesUrl `
  -CommitMessage $CommitMessage `
  -TargetSubdirectory 'verb-gym' `
  -DryRun:$DryRun
