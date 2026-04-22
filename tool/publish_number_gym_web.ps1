[CmdletBinding()]
param(
  [string]$BaseHref = '/NumberGym/',
  [string]$PagesUrl = 'https://dimonsmart.github.io/NumberGym/',
  [string]$CommitMessage = 'Deploy NumberGym web',
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

$workspaceRoot = Get-WorkspaceRoot
$appPath = Join-Path $workspaceRoot 'apps/number_gym'
$buildWebPath = Join-Path $appPath 'build/web'
$tempRoot = [System.IO.Path]::GetTempPath()
$deployCopyPath = Join-Path $tempRoot ("numbergym_web_" + [System.Guid]::NewGuid().ToString('N'))
$worktreePath = Join-Path $tempRoot ("numbergym_gh_pages_" + [System.Guid]::NewGuid().ToString('N'))

try {
  Write-Host "[1/6] Build apps/number_gym for Web..."
  Push-Location $appPath
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

  Write-Host "[2/6] Prepare GitHub Pages helper files..."
  New-Item -ItemType File -Path (Join-Path $buildWebPath '.nojekyll') -Force | Out-Null
  Copy-Item -LiteralPath $indexPath -Destination (Join-Path $buildWebPath '404.html') -Force

  Write-Host "[3/6] Copy build output to temp directory..."
  Copy-Item -LiteralPath $buildWebPath -Destination $deployCopyPath -Recurse -Force

  Write-Host "[4/6] Prepare gh-pages worktree..."
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

  Write-Host "[5/6] Sync build output to gh-pages worktree..."
  Get-ChildItem -LiteralPath $worktreePath -Force |
    Where-Object { $_.Name -ne '.git' } |
    ForEach-Object {
      Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
  Copy-Item -LiteralPath (Join-Path $deployCopyPath '*') -Destination $worktreePath -Recurse -Force

  if ($DryRun) {
    Write-Host "[6/6] Dry run complete. Build and deploy sync succeeded."
    Write-Host "Dry-run URL target: $PagesUrl"
    return
  }

  Write-Host "[6/6] Commit and push gh-pages..."
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

  Write-Host ''
  Write-Host 'DONE.'
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
