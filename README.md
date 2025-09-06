# Invoke-AkshESXI

## SYNOPSIS
Helps in automating various tasks related to managing a ESXI 6.5 based lab. 

## DESCRIPTION
This script is a wrapper on PowerCLI, a PowerShell-based command-line interface and scripting tool for automating and managing VMware vSphere environments. It uses PowerCLI commands to automate performing actions such as start, stop, suspend, snapshots, revert etc. on the entire lab or a single virtual machine. 

## PARAMETERS 
 - action - Mandatory. Action to be performed on the lab / virtual machine. Vaild values are start, stop, suspend, reset, pause, unpause, snapshot and revert.
 - machineName - Optional. Specifies the name of the virtual machine on which the action is to be performed. If no value or "all" is specified, the specified action will be performed on the entire lab.
 - esxiHost - Optional. Specifies the IP address or FQDN of the ESXI server.
 - esxiUserName - Optional. Specifies the user name to connect to the ESXI server.

## NOTES
PowerCLI configuration may need to be updated to ignore invalid SSL certificates. It can be done by the following command:

`Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false`

Re-enable the certificate verification by following command:

`Set-PowerCLIConfiguration -InvalidCertificateAction Prompt -Confirm:$false`
  
 ## INSTRUCTIONS TO EXECUTE
 - Import Invoke-AkshESXI.ps1 - `. .\Invoke-AkshESXI.ps1`
 - See command help - `Get-Help Invoke-AkshESXI -Full`
 - Follow the examples.

 ## EXAMPLES
  
 - `PS> Invoke-AkshESXI -action start -esxiHost 192.168.1.54 -esxiUserName esxi_user`
 - `PS> Invoke-AkshESXI -action snapshot -machineName all -esxiHost 192.168.1.54 -esxiUserName esxi_user`
 - `PS> Invoke-AkshESXI -action revert -machineName Sample-VM  -esxiHost 192.168.1.54 -esxiUserName esxi_user`

## LINKS
 - https://yaksas.com
 - https://github.com/yaksas443/Invoke-AkshESXI
