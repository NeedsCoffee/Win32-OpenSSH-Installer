$owner     = 'PowerShell'
$repo      = 'Win32-OpenSSH'
$pattern   = 'OpenSSH-Win64'
$type      = 'zip'
$target    = $env:ProgramFiles
$installer = 'install-sshd.ps1'
# -----------------------------------------------------
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  # Relaunch as an elevated process:
  Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
  exit
}

$splat = @{
    Uri = "https://api.github.com/repos/$owner/$repo/releases/latest"
    Headers = @{Accept='application/vnd.github.v3+json'}
    Method = 'Get'
}
Write-Host "Querying github API for latest release"
Write-Host "Uri:"$splat['Uri']
Try {
    $latest_release = Invoke-RestMethod @splat
} Catch {
    $_ | Write-Error
    break
}
if(-not $latest_release){
    Write-Host "No release found."
    break
} else {
    Write-Host "Name:"$latest_release.name
    Write-Host "Id:"$latest_release.id
}
$asset = $latest_release.assets | Where-Object name -match ($pattern+'\.'+$type+'$')
$id = $asset.id
$downloaduri = $asset.browser_download_url
$outpath = Join-Path -Path $env:TEMP -ChildPath ($repo+'_'+$id)
if(-not (Test-Path $outpath)){New-Item $outpath -ItemType Directory | Out-Null}
$outfile = Join-Path -Path $outpath -ChildPath $asset.name
Write-Host "Downloading latest release"
Write-Host "Asset url:"$downloaduri
Write-Host "Saving to:"$outfile
Try {
    Invoke-WebRequest -Uri $downloaduri -OutFile $outfile
} Catch {
    $_ | Write-Error
}
if(Test-Path $outfile){
    Write-Host "Downloaded."
} else {
    Write-Host "Download missing!"
    break
}

Write-Host "Stopping sshd and ssh-agent services"
Get-Service | Where-Object Name -in "ssh-agent","sshd" | Stop-Service -Force
Write-Host "Killing sshd and ssh-agent processes"
Get-Process | Where-Object Name -in "ssh-agent","sshd" | Stop-Process -Force

try {
    Expand-Archive -DestinationPath $target -Path $outfile -Force
    $expansionTarget = Join-Path -Path $target -ChildPath ($outfile | Get-Item).BaseName
    Write-Host "Expanded to:"$expansionTarget
    Remove-Item -Path $outpath -Recurse -Force
    Write-Host "Archive deleted."
} catch {
    $_ | Write-Error
    break
}

$installfile = Join-Path -Path $expansionTarget -ChildPath $installer
$uninstallfile = Join-Path -Path $expansionTarget -ChildPath "un$installer"

if(Test-Path -Path $uninstallfile){
    Write-Host "Invoking uninstaller..."
    Try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -NoLogo -File `"$uninstallfile`"" -Verb RunAs -WorkingDirectory $expansionTarget -Wait -WindowStyle Minimized
        Write-Host "Done."
    } Catch {
        $_ | Write-Error
    }
}


if(Test-Path -Path $installfile){
    Write-Host "Invoking installer..."
    Try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -NoLogo -File `"$installfile`"" -Verb RunAs -WorkingDirectory $expansionTarget -Wait -WindowStyle Minimized
        Write-Host "Done."
    } Catch {
        $_ | Write-Error
    }
}

$null = Read-Host 'Press ENTER'
