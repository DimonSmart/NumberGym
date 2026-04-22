Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WorkspaceRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-WorkspaceMembers {
  param(
    [switch]$IncludeFrozen
  )

  $members = @(
    [pscustomobject]@{
      Name = 'trainer_core'
      Path = 'packages/trainer_core'
      Status = 'active'
    }
    [pscustomobject]@{
      Name = 'number_gym_content'
      Path = 'packages/number_gym_content'
      Status = 'active'
    }
    [pscustomobject]@{
      Name = 'number_gym'
      Path = 'apps/number_gym'
      Status = 'active'
    }
  )

  if ($IncludeFrozen) {
    $members += @(
      [pscustomobject]@{
        Name = 'verb_gym_content'
        Path = 'packages/verb_gym_content'
        Status = 'frozen'
      }
      [pscustomobject]@{
        Name = 'verb_gym'
        Path = 'apps/verb_gym'
        Status = 'frozen'
      }
    )
  }

  return $members
}
