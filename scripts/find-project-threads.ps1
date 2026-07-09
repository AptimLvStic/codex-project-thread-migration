param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

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
  try {
    return [System.IO.Path]::GetFullPath($PathText).TrimEnd("\", "/")
  } catch {
    return $PathText.TrimEnd("\", "/")
  }
}

function Shorten([string]$Text, [int]$Max = 100) {
  if (-not $Text) { return $null }
  $oneLine = ($Text -replace "\s+", " ").Trim()
  if ($oneLine.Length -le $Max) { return $oneLine }
  return $oneLine.Substring(0, $Max)
}

$target = Normalize-PathText $ProjectPath
$sessionIndexPath = Join-Path $CodexHome "session_index.jsonl"
$titles = @{}

if (Test-Path -LiteralPath $sessionIndexPath) {
  Get-Content -LiteralPath $sessionIndexPath -Encoding UTF8 | ForEach-Object {
    try {
      $entry = $_ | ConvertFrom-Json
      if ($entry.id -and $entry.thread_name) {
        $titles[$entry.id] = [string]$entry.thread_name
      }
    } catch {}
  }
}

$roots = @()
$sessions = Join-Path $CodexHome "sessions"
if (Test-Path -LiteralPath $sessions) {
  $roots += [pscustomobject]@{ Path = $sessions; Archived = $false }
}

$archived = Join-Path $CodexHome "archived_sessions"
if (-not $ActiveOnly -and (Test-Path -LiteralPath $archived)) {
  $roots += [pscustomobject]@{ Path = $archived; Archived = $true }
}

$rows = foreach ($root in $roots) {
  Get-ChildItem -LiteralPath $root.Path -Recurse -File -Filter *.jsonl -ErrorAction SilentlyContinue | ForEach-Object {
    $file = $_.FullName
    try {
      $metaLine = Get-Content -LiteralPath $file -TotalCount 1 -Encoding UTF8
      if (-not $metaLine) { return }
      $meta = $metaLine | ConvertFrom-Json
      if ($meta.type -ne "session_meta") { return }

      $cwd = Normalize-PathText ([string]$meta.payload.cwd)
      if ($cwd -ne $target) { return }

      $threadSource = [string]$meta.payload.thread_source
      if (-not $IncludeSubagents -and $threadSource -and $threadSource -ne "user") { return }

      $firstUser = $null
      $lastUser = $null
      Get-Content -LiteralPath $file -Encoding UTF8 | ForEach-Object {
        try { $o = $_ | ConvertFrom-Json } catch { return }
        if ($o.type -eq "event_msg" -and $o.payload.type -eq "user_message") {
          if (-not $firstUser) { $firstUser = [string]$o.payload.message }
          $lastUser = [string]$o.payload.message
        }
      }

      $id = [string]$meta.payload.id
      $title = if ($titles.ContainsKey($id)) { $titles[$id] } else { $null }
      $fallback = Shorten $firstUser 60

      [pscustomobject]@{
        Id = $id
        Title = $title
        FallbackTitle = $fallback
        Cwd = $cwd
        Created = [string]$meta.payload.timestamp
        Updated = $_.LastWriteTime.ToString("s")
        Archived = [bool]$root.Archived
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

$rows | Sort-Object Created | ConvertTo-Json -Depth 6
