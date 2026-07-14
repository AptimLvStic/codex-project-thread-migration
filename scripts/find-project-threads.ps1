param(
  [string]$ProjectPath,

  [switch]$All,

  [string]$CodexHome = $(if ($env:CODEX_HOME) {
      $env:CODEX_HOME
    } elseif ($env:USERPROFILE) {
      Join-Path $env:USERPROFILE ".codex"
    } elseif ($env:HOME) {
      Join-Path $env:HOME ".codex"
    } else {
      ".codex"
    }),

  [switch]$IncludeSubagents,

  [switch]$ActiveOnly
)

$ErrorActionPreference = "Stop"

function Normalize-PathText([string]$PathText) {
  if (-not $PathText) { return $null }
  $trimmed = $PathText -replace '^[\\]{2}\?\\', ''
  try {
    return [System.IO.Path]::GetFullPath($trimmed).TrimEnd("\", "/")
  } catch {
    return $trimmed.TrimEnd("\", "/")
  }
}

function Shorten([string]$Text, [int]$Max = 100) {
  if (-not $Text) { return $null }
  $oneLine = ($Text -replace "\s+", " ").Trim()
  if ($oneLine.Length -le $Max) { return $oneLine }
  return $oneLine.Substring(0, $Max)
}

if ($All -and $ProjectPath) {
  throw "Use either -All or -ProjectPath, not both."
}

$target = if ($All) { $null } elseif ($ProjectPath) { Normalize-PathText $ProjectPath } else { Normalize-PathText (Get-Location).Path }
$sessionIndexPath = Join-Path $CodexHome "session_index.jsonl"
$titles = @{}

if (Test-Path -LiteralPath $sessionIndexPath) {
  Get-Content -LiteralPath $sessionIndexPath -Encoding UTF8 | ForEach-Object {
    try {
      $entry = $_ | ConvertFrom-Json
      if ($entry.id -and $entry.thread_name) { $titles[$entry.id] = [string]$entry.thread_name }
    } catch {}
  }
}

$pinned = @{}
$state = $null
$statePath = Join-Path $CodexHome ".codex-global-state.json"
if (Test-Path -LiteralPath $statePath) {
  try {
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($id in @($state.'pinned-thread-ids')) { if ($id) { $pinned[[string]$id] = $true } }
  } catch {}
}

$roots = @()
$sessions = Join-Path $CodexHome "sessions"
if (Test-Path -LiteralPath $sessions) { $roots += [pscustomobject]@{ Path = $sessions; Archived = $false } }
$archived = Join-Path $CodexHome "archived_sessions"
if (-not $ActiveOnly -and (Test-Path -LiteralPath $archived)) { $roots += [pscustomobject]@{ Path = $archived; Archived = $true } }

$rows = foreach ($root in $roots) {
  Get-ChildItem -LiteralPath $root.Path -Recurse -File -Filter *.jsonl -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_.FullName
    try {
      $metaLine = Get-Content -LiteralPath $file -TotalCount 1 -Encoding UTF8
      if (-not $metaLine) { return }
      $meta = $metaLine | ConvertFrom-Json
      if ($meta.type -ne "session_meta") { return }

      $threadSource = [string]$meta.payload.thread_source
      if (-not $IncludeSubagents -and $threadSource -and $threadSource -ne "user") { return }

      $cwd = Normalize-PathText ([string]$meta.payload.cwd)
      if ($target -and $cwd -ne $target) { return }

      $firstUser = $null
      $lastUser = $null
      Get-Content -LiteralPath $file -Encoding UTF8 | ForEach-Object {
        try { $event = $_ | ConvertFrom-Json } catch { return }
        if ($event.type -eq "event_msg" -and $event.payload.type -eq "user_message") {
          if (-not $firstUser) { $firstUser = [string]$event.payload.message }
          $lastUser = [string]$event.payload.message
        }
      }

      $id = [string]$meta.payload.id
      [pscustomobject]@{
        Id = $id
        Title = if ($titles.ContainsKey($id)) { $titles[$id] } else { $null }
        FallbackTitle = Shorten $firstUser 80
        Cwd = $cwd
        Created = [string]$meta.payload.timestamp
        Updated = $_.LastWriteTime.ToString("s")
        Archived = [bool]$root.Archived
        Pinned = [bool]$pinned[$id]
        ThreadSource = $threadSource
        ModelProvider = [string]$meta.payload.model_provider
        Source = $meta.payload.source
        File = $file
        FirstUser = Shorten $firstUser 120
        LastUser = Shorten $lastUser 120
      }
    } catch {}
  }
}

# A restored pinned thread can exist only in the current app state, with no matching
# historical JSONL file. Keep it in the inventory so the pin is not silently omitted.
if ($All -and $state) {
  foreach ($id in $pinned.Keys) {
    if (@($rows | Where-Object Id -eq $id).Count -gt 0) { continue }

    $description = $null
    $atomState = $state.'electron-persisted-atom-state'
    if ($atomState) {
      $descriptions = $atomState.'thread-descriptions-v1'
      $property = if ($descriptions) { $descriptions.PSObject.Properties[$id] } else { $null }
      if ($property) { $description = [string]$property.Value }
    }

    $rows += [pscustomobject]@{
      Id = $id
      Title = if ($titles.ContainsKey($id)) { $titles[$id] } else { $null }
      FallbackTitle = Shorten $description 80
      Cwd = $null
      Created = $null
      Updated = $null
      Archived = $null
      Pinned = $true
      ThreadSource = 'stateOnly'
      ModelProvider = $null
      Source = 'currentAppState'
      File = $null
      FirstUser = $null
      LastUser = $null
    }
  }
}

$rows | Sort-Object Cwd,Created | ConvertTo-Json -Depth 6
