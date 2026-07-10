param(
  [string]$Server = "root@8.163.115.183",
  [string]$RemoteDir = "/opt/guoguo/public/worksheets",
  [string]$BaseUrl = "http://8.163.115.183/guoguo/worksheets/",
  [string]$LocalDir = "dist\worksheets_upload",
  [string]$IdentityFile = "$env:USERPROFILE\.ssh\guoguo_server_ed25519"
)

$ErrorActionPreference = "Stop"

python tool\build_worksheet_cloud_package.py --base-url $BaseUrl --out $LocalDir

$IdentityArgs = @()
if (Test-Path $IdentityFile) {
  $IdentityArgs = @("-i", $IdentityFile)
}

ssh @IdentityArgs $Server "mkdir -p '$RemoteDir/generated' '$RemoteDir/images'"
scp @IdentityArgs "$LocalDir\index.json" "${Server}:$RemoteDir/index.json"
scp @IdentityArgs "$LocalDir\generated\*.json" "${Server}:$RemoteDir/generated/"
scp @IdentityArgs -r "$LocalDir\images\*" "${Server}:$RemoteDir/images/"

Write-Host "Worksheet package uploaded to $BaseUrl"
