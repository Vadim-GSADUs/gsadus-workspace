Write-Host ('PROFILE path: ' + $PROFILE)
Write-Host ('Exists: ' + (Test-Path $PROFILE))
if (Test-Path $PROFILE) {
    Get-Content $PROFILE | Select-Object -First 20
}
Write-Host '--- available wip functions ---'
Get-Command *wip* -ErrorAction SilentlyContinue | Format-Table Name, CommandType
