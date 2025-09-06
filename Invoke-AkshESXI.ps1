function Invoke-AkshESXI
{
<#
  .SYNOPSIS
  Helps in automating various tasks related to managing a ESXI 6.5 based lab. 

  .DESCRIPTION
  This script is a wrapper on PowerCLI, a PowerShell-based command-line interface and scripting tool for automating and managing VMware vSphere environments. It uses PowerCLI commands to automate performing actions such as start, stop, suspend, snapshots, revert etc. on the entire lab or a single virtual machine.  

  .PARAMETER action
  Action to be performed on the lab / virtual machine. Vaild values are start, stop, suspend, reset, pause, unpause, snapshot and revert.

  .PARAMETER machineName
  Optional parameter. Specifies the name of the virtual machine on which the action is to be performed. If no value or "all" is specified, the specified action will be performed on the entire lab.

  .PARAMETER esxiHost
  Optional parameter. Specifies the IP address or FQDN of the ESXI server.

  .PARAMETER esxiUserName
  Optional parameter. Specifies the user name to connect to the ESXI server.

  .INPUTS
  None. You cannot pipe objects to Invoke-AKSH.ps1.

  .Notes
  PowerCLI configuration may need to be updated to ignore invalid SSL certificates. It can be done by the following command:

  Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

  Re-enable the certificate verification by following command:

  Set-PowerCLIConfiguration -InvalidCertificateAction Prompt -Confirm:$false
 

  .EXAMPLE
  PS> Invoke-AkshESXI -action start -esxiHost 192.168.1.54 -esxiUserName esxi_user

  .EXAMPLE
  PS> Invoke-AkshESXI -action snapshot -machineName all -esxiHost 192.168.1.54 -esxiUserName esxi_user

  .EXAMPLE
  PS> Invoke-AkshESXI -action revert -machineName Sample-VM  -esxiHost 192.168.1.54 -esxiUserName esxi_user

  .LINK
  https://yaksas.com
  https://github.com/yaksas443/Invoke-AkshESXI
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$action,
    [string]$machineName = "all",
    [Parameter(Mandatory=$false)]
    [string]$esxiHost,
    [Parameter(Mandatory=$false)]
    [string]$esxiUserName
)

function perform_action {
    param (
        [string]$action,
        [string]$machineName,
        [string]$snapshotName
    )

    $VM = Get-VM -Name $machineName -ErrorAction SilentlyContinue
    if ($action -eq "start" -or $action -eq "unpause") {
        try {
            Write-Host "Starting VM "$machineName"..." -ForegroundColor Green
            if ($vm.PowerState -eq 'PoweredOn') {
                Write-Host "VM "$machineName" is already started." -ForegroundColor Green
            }
            else {
                Start-VM -VM $VM -Confirm:$false | Out-Null
                Write-Host "VM "$machineName" has been started successfully." -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Could not start VM "$machineName": $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    if ($action -eq "stop") {
        Write-Host "Stopping VM "$machineName"..." -ForegroundColor Green
        if ($vm.PowerState -eq 'PoweredOff') {
            Write-Host "VM "$machineName" is already stopped." -ForegroundColor Green
        }
        else {
            if ($VM.ExtensionData.Guest.ToolsStatus -eq "toolsOk") {
                Shutdown-VMGuest -VM $VM -Confirm:$false -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            elseif ($VM.ExtensionData.Guest.ToolsStatus -eq "toolsNotInstalled") {
                Write-Host "VMware Tools not running - performing hard stop."
                Stop-VM -VM $VM -Confirm:$false | Out-Null
            }
            else {
                retryCount = 0
                while ($VM.ExtensionData.Guest.ToolsStatus -ne "toolsOk") {
                    Write-Host "VMWare Tools status is "$VM.ExtensionData.Guest.ToolsStatus". Delaying VM shutdown by 5 seconds"
                    Start-Sleep -Seconds 5
                    retryCount = retryCount + 1
                    $VM = Get-VM -Name $machineName -ErrorAction SilentlyContinue
                    if (($VM.ExtensionData.Guest.ToolsStatus -eq "toolsOk") -or (retryCount -le 3)) {
                        Write-Host "VMWare Tools status is "$VM.ExtensionData.Guest.ToolsStatus". Trying to shutdown now."
                        Shutdown-VMGuest -VM $VM -Confirm:$false -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
                    }
                }
            }
            Write-Host "VM '$machineName' has been stopped successfully." -ForegroundColor Green
        }   
    }
    if ($action -eq "reset") {
        Write-Host "Restarting VM "$machineName"..." -ForegroundColor Green
        if ($vm.PowerState -eq 'Suspended') {
            Write-Host "VM "$machineName" cannot be restarted as its in suspended state." -ForegroundColor Green
        }
        elseIf ($vm.PowerState -eq 'PoweredOff') {
            Write-Host "VM "$machineName" is powered off and cannot be reset." -ForegroundColor Green
        }
        else {
            Restart-VMGuest -VM $VM -Confirm:$false | Out-Null
            Write-Host "VM '$machineName' has been restarted successfully." -ForegroundColor Green
        } 
    }
    if ($action -eq "snapshot") {
        Write-Host "Creating a snapshot for "$machineName"..." -ForegroundColor Green
        New-Snapshot -VM $VM -Name $snapshotName | Out-Null
        Write-Host "Snapshot " $snapshotName " has been created." -ForegroundColor Green
    }
    if ($action -eq "revert"  -or $action -eq "reverttosnapshot") {
        Write-Host "Reverting "$machineName" to snapshot "$snapshotName"..." -ForegroundColor Green
        Set-VM -VM $VM -Snapshot $snapshotName -Confirm:$false | Out-Null
        Write-Host "VM "$machineName" has been reverted to "$snapshotName"." -ForegroundColor Green
    }
    if ($action -eq "suspend" -or $action -eq "pause") {
        Write-Host "Suspending / pausing "$machineName" ..." -ForegroundColor Green
        if ($vm.PowerState -eq 'Suspended') {
            Write-Host "VM "$machineName" is already paused or suspended." -ForegroundColor Green
        }
        elseIf ($vm.PowerState -eq 'PoweredOff') {
            Write-Host "VM "$machineName" is powered off and cannot be suspended." -ForegroundColor Green
        }
        else {
            Suspend-VM -VM $VM -Confirm:$false | Out-Null
            Write-Host "VM "$machineName" has been suspended / paused." -ForegroundColor Green
        } 
    }
}

function check_previousSnapshot {
    param (
        [string]$machineName
    )
    $snapshotName = ""
    Write-Host "[+] Checking if previous snapshot exists."
    $snapshotCount = (Get-Snapshot -VM $machineName).Count
    if ($snapshotCount -gt 0) {
        $prevSnapshotName = (Get-Snapshot -VM $machineName | Sort-Object Created -Descending | Select-Object -First 1).Name
        Write-Host "[+] Snapshot found for :"$machineName
        Write-Host "[+] Snapshot name is :"$prevSnapshotName
        $snapshotName = $prevSnapshotName
    }
    else {
        Write-Host "[+] Previous snapshot does not exist"
    }
    return $prevSnapshotName
}

$action =  $action.ToLower()
$vmList = ""
$esxiSessionExists = $false
$esxiSessionCreated = $false

if ($action -ne "start" -and $action -ne "stop" -and $action -ne "suspend" -and $action -ne "pause" -and $action -ne "unpause" -and $action -ne "reset" -and $action -ne "snapshot" -and $action -ne "revert") {
    Write-Host "[-] This action is not supported. Please choose from one of the following: start, stop, suspend, pause, unpause, snapshot, reverttosnapshot."
}
else {
    if ($esxiHost -ne ""){
            Write-Host "Connecting to ESXi host $esxiHost ..." -ForegroundColor Cyan
            $esxiPassword = Read-Host -Prompt "Enter ESXi Password" -AsSecureString
            $Credential = New-Object System.Management.Automation.PSCredential ($esxiUserName, $esxiPassword)
            Connect-VIServer -Server $esxiHost -Credential $Credential | Out-Null
            $esxiSessionExists = $true
            $esxiSessionCreated = $true
    }
    else {
        if($global:DefaultVIServers -and $global:DefaultVIServers.Count -gt 0){
            Write-Host "Found a session to ESXI server $($session.Name)."
            $esxiSessionExists = $true
        }
        else {
            Write-Host "A session to ESXI server does not exist."
            $esxiSessionExists = $false
        }
        
    }

    if ($esxiSessionExists){

    $vmNames = @()
    if ($machineName.ToUpper() -eq "ALL" -or $machineName -eq "")
    {
        $vmList = Get-VM | select Name
    }
    elseif (Test-Path -Path $machineName) {
        $vmNames = Get-Content -Path $machineName |
                ForEach-Object { $_ -split '[,;]' } |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -ne "" }
        $vmList = Get-VM -Name $vmNames | select Name
    }
    else {
        $vmNames = $machineName -split '[\r\n,;]' |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -ne "" }
        $vmList = Get-VM -Name $vmNames | select Name
    }
    
    foreach($vm in $vmList) {
            $snapshotName = ""
            if ($action -eq "snapshot"){
                $snapshotName = $(Get-Date -Format "MM-dd-yyyy-HH-mm")
                $prevSnapshotName = check_previousSnapshot -machineName $($vm.Name)
                if ($prevSnapshotName.length -gt 0) {
                    Write-Host "[+] Deleting previous snapshot"
                    Get-Snapshot -VM $($vm.Name) | Sort-Object Created -Descending | Select-Object -First 1 | Remove-Snapshot -Confirm:$false
                }
            }
            if ($action -eq "revert" -or $action -eq "reverttosnapshot"){
                $action = "reverttosnapshot"
                $prevSnapshotName = check_previousSnapshot -machineName $($vm.Name)
                if ($prevSnapshotName.length -gt 0) {
                    $snapshotName = $prevSnapshotName
                }
            }
            Write-Host "[+] Performing action "$action" on VM "$($vm.Name)
            if (($action -eq "revert" -or $action -eq "reverttosnapshot") -and $prevSnapshotName.length -eq 0)
            {
                Write-Host "[-] Unable to perform revert operation. There is no snapshot to revert to."
            }
            else {
                    perform_action -action $action -machineName $($vm.Name) -snapshotName $snapshotName
                    
            }
    } 
    if ($esxiSessionCreated) {
    Disconnect-VIServer -Server $esxiHost -Confirm:$false
    }
}
}
}
