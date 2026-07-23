param(
  [string]$Client = "LibeRation/inst/assets/favicon.svg",
  [string]$Server = "LibeRties/inst/admin-assets/favicon.svg",
  [string]$LibeRator = "LibeRator/inst/assets/favicon.svg",
  [string]$LibeRtAD = "LibeRtAD/inst/assets/favicon.svg",
  [string]$LibeRality = "LibeRality/inst/assets/favicon.svg",
  [string[]]$Library = @(
    "LibeRary/inst/shiny/www/favicon.svg",
    "LibeRary/inst/shiny-ingest/www/favicon.svg"
  ),
  [switch]$LibraryOnly,
  [switch]$LibeRatorOnly,
  [switch]$LibeRtADOnly,
  [switch]$LibeRalityOnly
)

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path

function Write-DoveSvg {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Colour,
    [Parameter(Mandatory = $true)][string]$Eye
  )

  $target = [IO.Path]::GetFullPath((Join-Path $root $Path))
  if (-not $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Favicon target must remain inside the repository: $Path"
  }
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" id="$Id" width="128" height="128" viewBox="0 0 128 128" role="img" aria-labelledby="$Id-title">
  <title id="$Id-title">$Label</title>
  <circle cx="64" cy="64" r="57" fill="$Colour"/>
  <path d="M29 72c17-4 24-17 30-36 6 13 15 20 32 21-8 5-13 10-17 18 10-4 18-4 26 0-13 2-23 8-31 19-11-9-22-14-40-14 6-2 11-5 15-9-6 2-11 2-15 1Z" fill="#fff"/>
  <circle cx="72" cy="54" r="2.5" fill="$Eye"/>
</svg>
"@
  [IO.File]::WriteAllText($target, $svg, [Text.UTF8Encoding]::new($false))
}

if ($LibraryOnly) {
  foreach ($path in $Library) {
    Write-DoveSvg $path "liberary-dove" "LibeRary" "#236a45" "#184e34"
  }
  return
}
if ($LibeRatorOnly) {
  Write-DoveSvg $LibeRator "liberator-dove" "LibeRator" "#19787b" "#124f53"
  return
}
if ($LibeRtADOnly) {
  Write-DoveSvg $LibeRtAD "libertad-dove" "LibeRtAD" "#9875b6" "#4d3c5d"
  return
}
if ($LibeRalityOnly) {
  Write-DoveSvg $LibeRality "liberality-dove" "LibeRality" "#b7791f" "#6d4611"
  return
}

Write-DoveSvg $Client "liberation-dove" "LibeRation" "#4d7fa8" "#23384d"
Write-DoveSvg $Server "liberties-dove" "LibeRties" "#b84a54" "#7f2830"
Write-DoveSvg $LibeRator "liberator-dove" "LibeRator" "#19787b" "#124f53"
Write-DoveSvg $LibeRtAD "libertad-dove" "LibeRtAD" "#9875b6" "#4d3c5d"
Write-DoveSvg $LibeRality "liberality-dove" "LibeRality" "#b7791f" "#6d4611"
foreach ($path in $Library) {
  Write-DoveSvg $path "liberary-dove" "LibeRary" "#236a45" "#184e34"
}
