# Disable UAC in registry and restart servers
# 
# 2017 Viktor Bardadym

# Output program information
Write-Host -foregroundcolor White ""
Write-Host -foregroundcolor White "Disable UAC"

#**************************************************************************************
# Constants
#**************************************************************************************

#**************************************************************************************
# Functions
#**************************************************************************************
#<summary>
# Loads the SharePoint PowerShell snap-in.
#</summary>
Function Load-SharePoint-PowerShell
{
	If ((Get-PsSnapin |?{$_.Name -eq "Microsoft.SharePoint.PowerShell"})-eq $null)
	{
		Write-Host -ForegroundColor White " - Loading SharePoint PowerShell snap-in"
		Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction Stop
	}
}

#<summary>
# returns True if the specified service is running on the specified server
#</summary>
#<param name="$serverName">Server name.</param>
#<param name="$serviceName">Service name.</param>
function ServiceIsRunning($serverName, $serviceName)
{
	try 
	{
		$service = Get-Service $serviceName -ComputerName $serverName
		if ($service -eq $null) 
		{
			Write-Host "Service" $serviceName "not found on server" $serverName -foregroundcolor Red
			$false
		}
		else 
		{
			$service.Status -eq "Running"
		}
	}
	catch 
	{
		$false
	}
}

#<summary>
# Set the value of the registry key.
# If required, restart all servers in the farm; the current is the last
#</summary>
#<param name="$farm">The SharePoint farm object.</param>
#<param name="$baseKey">String with registry base key, e.g. "LocalMachine", "CurrentUser", "ClassesRoot", "CurrentConfig", "Users"</param>
#<param name="$key">String with registry key</param>
#<param name="$value">Registry key value to set</param>
#<param name="$type">Registry key type</param>
#<param name="$restart">Whether to restart the server, boolean</param>
#<param name="$timeout">Timeout in seconds to check the readiness of the server qfter the restart</param>
function SetRegistryKey($farm, $baseKey, $keyPath, $key, $value, [Microsoft.Win32.RegistryValueKind]$type, $restart, $timeout)
{
	[string]$thisServerName = $env:COMPUTERNAME

	# Iterate through each server in the farm, and each service in each server
	foreach($server in $farm)
	{
		[string]$serverName = $server.Name
		if ($serverName -ne $thisServerName) 
		{
			Write-Host -foregroundcolor DarkGray -NoNewline "Updating registry on" $serverName

			$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($baseKey, $serverName) 
			$regKey= $reg.OpenSubKey($keyPath, $true) 
			$regKey.SetValue($key, $value, $type)
			if ($restart) 
			{ 
				Write-Host -foregroundcolor DarkGray -NoNewline "Restarting server" $serverName
				Restart-Computer -ComputerName $serverName -Force
                
				# Wait until the computer will reply on Test-Connection
				do 
				{
					Write-Host "Waiting the server"  $serverName "to restart." -ForegroundColor Yellow
					Start-Sleep -seconds $timeout
					$serverIsUp = Test-Connection -ComputerName $serverName -BufferSize 16 -Count 1 -Quiet 
				}
				until ($serverIsUp)
                
				# Wait until SharePoint services will start on the computer; SharePoint Timer and WWW Publishing services
				do 
				{
					Write-Host "Waiting services to start on the server"  $serverName -ForegroundColor Yellow
					Start-Sleep -seconds $timeout
					$servicesAreUp = (ServiceIsRunning $serverName "SPTimerV4") -and (ServiceIsRunning $serverName "W3SVC")
				}
				until ($servicesAreUp)
			}
		}
	}
	Write-Host -foregroundcolor DarkGray -NoNewline "Updating registry on this server" $thisServerName
	$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($baseKey, $thisServerName) 
	$regKey= $reg.OpenSubKey($keyPath, $true) 
	$regKey.SetValue($key, $value, $type)

	if ($restart) 
	{ 
		Write-Host -foregroundcolor DarkGray -NoNewline "Restarting this server" $thisServerName
		Restart-Computer -ComputerName $thisServerName -Force
	}
}

#**************************************************************************************
# Main script
#**************************************************************************************

# Load SharePoint PowerShell snap-in
Load-SharePoint-PowerShell

# Get the local farm instance
$farm = Get-SPServer | where {$_.Role -match "Application"}

# Set the registry key on each server in the farm
SetRegistryKey $farm 'LocalMachine' "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\policies\\system" "EnableLUA" 0 "DWord" $true 10
