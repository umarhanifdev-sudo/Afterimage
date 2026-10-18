param([string]$TargetDirectory = 'C:\Games\AFTERIMAGE-Windows-and-Source\v4')
$ErrorActionPreference = 'Stop'
$sourceDirectory = [IO.Path]::GetFullPath($PSScriptRoot)
if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) {
    throw "Game folder not found: $TargetDirectory. Run this script with -TargetDirectory followed by your extracted game folder."
}
if (-not (Test-Path -LiteralPath (Join-Path $TargetDirectory 'AFTERIMAGE.exe'))) {
    $nested = Join-Path $TargetDirectory 'AFTERIMAGE'
    if (Test-Path -LiteralPath (Join-Path $nested 'AFTERIMAGE.exe')) { $TargetDirectory = $nested }
    else { throw "AFTERIMAGE.exe was not found in $TargetDirectory. No files were changed." }
}
$TargetDirectory = [IO.Path]::GetFullPath($TargetDirectory)
if ($sourceDirectory.TrimEnd('\') -eq $TargetDirectory.TrimEnd('\')) {
    Write-Host 'This folder already contains the downloaded update. Run AFTERIMAGE.exe here.'
    exit 0
}
$running = Get-Process -Name 'AFTERIMAGE' -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -eq (Join-Path $TargetDirectory 'AFTERIMAGE.exe')
}
if ($running) { throw 'Close AFTERIMAGE, then run Update-v4.cmd again. No files were changed.' }
$backupDirectory = Join-Path $TargetDirectory ('Backups\before-v0.9.0-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$relativeFiles = @('AFTERIMAGE.exe','AFTERIMAGE.pck','README.md','CREDITS.md','DEVELOPMENT.md','VALIDATION.txt','BUILD_RESULT.txt','START_HERE.txt','LAST_LOOP.txt','Music\README.txt')
$sourceTree = Join-Path $sourceDirectory 'Source'
Get-ChildItem -LiteralPath $sourceTree -File -Recurse | ForEach-Object {
    $relativeFiles += $_.FullName.Substring($sourceDirectory.Length + 1)
}
# Validate and back up every overwritten file before the first replacement.
$changes = @()
foreach ($relative in $relativeFiles) {
    $from = Join-Path $sourceDirectory $relative
    $to = Join-Path $TargetDirectory $relative
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { throw "Update is incomplete: $relative" }
    if ((Test-Path -LiteralPath $to -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $from -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $to -Algorithm SHA256).Hash)) { continue }
    $changes += [PSCustomObject]@{ Relative=$relative; From=$from; To=$to }
}
foreach ($change in $changes) {
    if (Test-Path -LiteralPath $change.To -PathType Leaf) {
        $backup = Join-Path $backupDirectory $change.Relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
        Copy-Item -LiteralPath $change.To -Destination $backup
    }
}
foreach ($change in $changes) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $change.To) | Out-Null
    Copy-Item -LiteralPath $change.From -Destination $change.To -Force
}
Write-Host "Updated $($changes.Count) files in $TargetDirectory"
if (Test-Path -LiteralPath $backupDirectory) { Write-Host "Replaced files were backed up in $backupDirectory" }
Write-Host 'Run AFTERIMAGE.exe in that folder. Saves remain in the existing Godot user-data location.'
