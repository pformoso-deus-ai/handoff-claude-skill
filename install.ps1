# handoff skill installer (Windows / PowerShell)
#
# Usage:
#   iwr -useb https://raw.githubusercontent.com/pformoso-deus-ai/handoff-claude-skill/main/install.ps1 | iex
#
# To install a specific branch, tag, or commit, set $env:HANDOFF_REF first:
#   $env:HANDOFF_REF = 'v0.1'
#   iwr -useb https://raw.githubusercontent.com/pformoso-deus-ai/handoff-claude-skill/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$repo = 'pformoso-deus-ai/handoff-claude-skill'
$ref = if ($env:HANDOFF_REF) { $env:HANDOFF_REF } else { 'main' }
$skillName = 'handoff'
$skillDir = Join-Path $env:USERPROFILE ".claude\skills\$skillName"

# Files to install: source path in repo -> path relative to skill dir.
# Add entries here when the skill grows beyond a single SKILL.md.
$files = @(
  @{ src = 'handoff/SKILL.md'; dst = 'SKILL.md' }
)

$firstInstall = -not (Test-Path (Join-Path $skillDir 'SKILL.md'))

New-Item -ItemType Directory -Force -Path $skillDir | Out-Null

$base = "https://raw.githubusercontent.com/$repo/$ref"

foreach ($f in $files) {
  $url = "$base/$($f.src)"
  $target = Join-Path $skillDir $f.dst
  $targetDir = Split-Path $target -Parent

  if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
  }

  Write-Host "downloading $($f.src) -> $target"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $target
}

Write-Host ""
Write-Host "Installed handoff skill to $skillDir"

if ($firstInstall) {
  Write-Host ""
  Write-Host "First-time install detected. Restart Claude Code (or close and reopen any"
  Write-Host "session) so the file watcher picks up the new skill directory. After that,"
  Write-Host "edits to the skill hot-reload mid-session."
} else {
  Write-Host ""
  Write-Host "Update applied. Open sessions hot-reload - no restart needed."
}
