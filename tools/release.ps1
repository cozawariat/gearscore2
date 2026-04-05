[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [switch]$Ci,

    [switch]$AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$tocPath = Join-Path $repoRoot "GearScore2.toc"
$changelogPath = Join-Path $repoRoot "CHANGELOG.md"
$distDir = Join-Path $repoRoot "dist"
$stagingDir = Join-Path $distDir "staging"
$packageRoot = Join-Path $stagingDir "GearScore2"

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-ReleaseNotes {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionTag,

        [Parameter(Mandatory = $true)]
        [string]$ChangelogFile
    )

    $fallback = @"
## $VersionTag

Release notes for $VersionTag were not found in CHANGELOG.md.

Edit CHANGELOG.md and the GitHub Release body before publishing the final release.
"@

    if (-not (Test-Path -LiteralPath $ChangelogFile)) {
        return $fallback
    }

    $lines = Get-Content -LiteralPath $ChangelogFile
    $escapedVersion = [regex]::Escape($VersionTag)
    $startPattern = "^##\s+\[$escapedVersion\](?:\s+-\s+.+)?$"
    $nextSectionPattern = "^##\s+\["

    $startIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match $startPattern) {
            $startIndex = $index
            break
        }
    }

    if ($startIndex -lt 0) {
        return $fallback
    }

    $bodyLines = New-Object System.Collections.Generic.List[string]
    for ($index = $startIndex + 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match $nextSectionPattern) {
            break
        }
        $bodyLines.Add($lines[$index])
    }

    $sectionBody = ($bodyLines -join "`r`n").Trim()
    if ([string]::IsNullOrWhiteSpace($sectionBody)) {
        return $fallback
    }

    return @"
## $VersionTag

$sectionBody
"@
}

function Remove-IfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Get-TocPackageEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TocFile
    )

    $entries = New-Object System.Collections.Generic.List[string]
    $lines = Get-Content -LiteralPath $TocFile

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed.StartsWith("##")) {
            continue
        }
        if ($trimmed.StartsWith("#")) {
            continue
        }

        $entries.Add(($trimmed -replace '\\', [System.IO.Path]::DirectorySeparatorChar))
    }

    return $entries
}

if ($Version -notmatch '^v(\d+)\.(\d+)\.(\d+)$') {
    throw "Version must match semantic tag format vX.Y.Z."
}

$addonVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
$packageName = "GearScore2-$Version.zip"
$packagePath = Join-Path $distDir $packageName
$notesPath = Join-Path $distDir "release-notes-$Version.md"

if (-not (Test-Path -LiteralPath $tocPath)) {
    throw "Missing GearScore2.toc at $tocPath"
}

if (-not $Ci -and -not $AllowDirty) {
    $statusLines = @(& git -C $repoRoot status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read git status."
    }
    if ($statusLines.Count -gt 0) {
        throw "Working tree is dirty. Commit or stash changes first, or rerun with -AllowDirty."
    }
}

$tocContent = Get-Content -LiteralPath $tocPath -Raw
$versionMatches = [regex]::Matches($tocContent, '(?m)^## Version:\s+.*$')
if ($versionMatches.Count -ne 1) {
    throw "GearScore2.toc must contain exactly one '## Version:' line."
}

$updatedToc = [regex]::Replace($tocContent, '(?m)^## Version:\s+.*$', "## Version: $addonVersion", 1)
Write-Utf8File -Path $tocPath -Content $updatedToc

New-Item -ItemType Directory -Path $distDir -Force | Out-Null
Remove-IfExists -Path $stagingDir
Remove-IfExists -Path $packagePath
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

$packageEntries = New-Object System.Collections.Generic.List[string]
$packageEntries.Add("GearScore2.toc")
foreach ($entry in (Get-TocPackageEntries -TocFile $tocPath)) {
    $packageEntries.Add($entry)
}

foreach ($entry in $packageEntries) {
    $sourcePath = Join-Path $repoRoot $entry
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing package entry: $entry"
    }

    $destinationPath = Join-Path $packageRoot $entry
    $destinationDir = Split-Path -Path $destinationPath -Parent
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

Compress-Archive -Path $packageRoot -DestinationPath $packagePath -Force

$releaseNotes = Get-ReleaseNotes -VersionTag $Version -ChangelogFile $changelogPath
Write-Utf8File -Path $notesPath -Content $releaseNotes

Write-Host "Prepared release $Version"
Write-Host "Addon version: $addonVersion"
Write-Host "Package: $packagePath"
Write-Host "Release notes: $notesPath"
