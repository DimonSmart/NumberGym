[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$AppPath,

  [Parameter(Mandatory = $true)]
  [string]$DisplayName,

  [Parameter(Mandatory = $true)]
  [string]$BaseHref,

  [Parameter(Mandatory = $true)]
  [string]$PagesUrl,

  [Parameter(Mandatory = $true)]
  [string]$CommitMessage,

  [string]$TargetSubdirectory = '',

  [string[]]$PreservePaths = @(),

  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'workspace.ps1')

function Invoke-Git {
  param(
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  Push-Location $WorkingDirectory
  try {
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "git $($Arguments -join ' ') failed."
    }
  } finally {
    Pop-Location
  }
}

function Remove-DirectoryIfExists {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return
  }

  Remove-Item -LiteralPath $Path -Recurse -Force
}

function Get-NormalizedTargetSubdirectory {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return ''
  }

  return ($Path.Replace('\', '/').Trim('/'))
}

function Get-NormalizedPreservePaths {
  param([string[]]$Paths)

  if ($null -eq $Paths) {
    return @()
  }

  return @(
    $Paths |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { $_.Replace('\', '/').Trim('/') } |
      Where-Object { $_.Length -gt 0 } |
      Select-Object -Unique
  )
}

$workspaceRoot = Get-WorkspaceRoot
$appRoot = Join-Path $workspaceRoot $AppPath
if (-not (Test-Path $appRoot)) {
  throw "Missing app path: $appRoot"
}

$normalizedTargetSubdirectory = Get-NormalizedTargetSubdirectory -Path $TargetSubdirectory
$normalizedPreservePaths = Get-NormalizedPreservePaths -Paths $PreservePaths
$buildWebPath = Join-Path $appRoot 'build/web'
$tempRoot = [System.IO.Path]::GetTempPath()
$safeAppName = $DisplayName.ToLowerInvariant().Replace(' ', '_')
$deployCopyPath = Join-Path $tempRoot ("${safeAppName}_web_" + [System.Guid]::NewGuid().ToString('N'))
$worktreePath = Join-Path $tempRoot ("${safeAppName}_gh_pages_" + [System.Guid]::NewGuid().ToString('N'))

try {
  Write-Host "[1/6] Build $AppPath for Web..."
  Push-Location $appRoot
  try {
    & flutter build web --release --base-href $BaseHref
    if ($LASTEXITCODE -ne 0) {
      throw 'flutter build web failed.'
    }
  } finally {
    Pop-Location
  }

  $indexPath = Join-Path $buildWebPath 'index.html'
  if (-not (Test-Path $indexPath)) {
    throw "Missing expected build output: $indexPath"
  }

  Write-Host "[2/6] Prepare temporary deploy payload..."
  if ([string]::IsNullOrEmpty($normalizedTargetSubdirectory)) {
    Copy-Item -LiteralPath $indexPath -Destination (Join-Path $buildWebPath '404.html') -Force
  }
  Copy-Item -LiteralPath $buildWebPath -Destination $deployCopyPath -Recurse -Force

  Write-Host "[3/6] Prepare gh-pages worktree..."
  Invoke-Git -WorkingDirectory $workspaceRoot -Arguments @('fetch', 'origin')

  Push-Location $workspaceRoot
  try {
    & git show-ref --verify --quiet refs/heads/gh-pages
    $hasLocalGhPages = ($LASTEXITCODE -eq 0)
    if (-not $hasLocalGhPages) {
      & git ls-remote --exit-code --heads origin gh-pages *> $null
      $hasRemoteGhPages = ($LASTEXITCODE -eq 0)
    } else {
      $hasRemoteGhPages = $false
    }
  } finally {
    Pop-Location
  }

  if ($hasLocalGhPages) {
    Invoke-Git -WorkingDirectory $workspaceRoot -Arguments @('worktree', 'add', '-f', $worktreePath, 'gh-pages')
  } elseif ($hasRemoteGhPages) {
    Invoke-Git -WorkingDirectory $workspaceRoot -Arguments @('fetch', 'origin', 'gh-pages')
    Invoke-Git -WorkingDirectory $workspaceRoot -Arguments @('worktree', 'add', '-f', '-b', 'gh-pages', $worktreePath, 'origin/gh-pages')
  } else {
    Invoke-Git -WorkingDirectory $workspaceRoot -Arguments @('worktree', 'add', '-f', '-b', 'gh-pages', $worktreePath)
  }

  Write-Host "[4/6] Sync payload into gh-pages..."

  if ([string]::IsNullOrEmpty($normalizedTargetSubdirectory)) {
    $preservedRootNames = @(
      '.git'
      $normalizedPreservePaths |
        ForEach-Object { ($_ -split '/')[0] } |
        Where-Object { $_.Length -gt 0 } |
        Select-Object -Unique
    )

    Get-ChildItem -LiteralPath $worktreePath -Force |
      Where-Object { $preservedRootNames -notcontains $_.Name } |
      ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
      }
    $deployTargetPath = $worktreePath
  } else {
    $deployTargetPath = Join-Path $worktreePath $normalizedTargetSubdirectory
    Remove-DirectoryIfExists -Path $deployTargetPath
    New-Item -ItemType Directory -Path $deployTargetPath -Force | Out-Null
  }

  Copy-Item -LiteralPath (Join-Path $deployCopyPath '*') -Destination $deployTargetPath -Recurse -Force
  New-Item -ItemType File -Path (Join-Path $worktreePath '.nojekyll') -Force | Out-Null

  if ($DryRun) {
    Write-Host "[5/6] Dry run complete. Build and deploy sync succeeded."
    Write-Host "Dry-run URL target: $PagesUrl"
    return
  }

  Write-Host "[5/6] Commit and push gh-pages..."
  Invoke-Git -WorkingDirectory $worktreePath -Arguments @('add', '-A')

  Push-Location $worktreePath
  try {
    & git diff --cached --quiet
    $hasChanges = ($LASTEXITCODE -ne 0)
  } finally {
    Pop-Location
  }

  if (-not $hasChanges) {
    Write-Host 'No changes to deploy.'
    Write-Host "Site URL: $PagesUrl"
    return
  }

  Invoke-Git -WorkingDirectory $worktreePath -Arguments @('commit', '-m', $CommitMessage)
  Invoke-Git -WorkingDirectory $worktreePath -Arguments @('push', '-u', 'origin', 'gh-pages')

  Write-Host "[6/6] Deploy finished."
  Write-Host "Site URL: $PagesUrl"
} finally {
  if (Test-Path $worktreePath) {
    Push-Location $workspaceRoot
    try {
      & git worktree remove --force $worktreePath *> $null
    } finally {
      Pop-Location
    }
  }
  Remove-DirectoryIfExists -Path $deployCopyPath
}
