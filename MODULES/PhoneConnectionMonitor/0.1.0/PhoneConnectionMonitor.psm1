# PhoneConnectionMonitor.psm1
# A comprehensive PowerShell module for monitoring phone connections via event handlers

<#
.SYNOPSIS
    PowerShell module for detecting and handling mobile phone connection events on Windows.

.DESCRIPTION
    This module provides multiple methods for detecting when mobile phones (especially Android devices)
    are connected via MTP (Media Transfer Protocol) to Windows systems. It includes temporary and 
    permanent event subscription options with customizable action handlers.

.NOTES
    Author: PowerShell Event Handler Examples
    Version: 1.0
    Requires: PowerShell 5.1+ and Administrator privileges for some features
#>

#region Private Variables
$Script:ActiveSubscriptions = @{}
$Script:LogSource = "PhoneConnectionMonitor"
#endregion

#region Public Functions

function Start-PhoneConnectionMonitor {
    <#
    .SYNOPSIS
        Starts monitoring for phone connection events using WMI temporary events.
    
    .DESCRIPTION
        Creates a temporary WMI event subscription to detect when phones are connected or disconnected.
        This method is easy to implement but only persists during the PowerShell session.
    
    .PARAMETER OnConnect
        Script block to execute when a phone is connected.
    
    .PARAMETER OnDisconnect
        Script block to execute when a phone is disconnected.
    
    .PARAMETER IncludeAllDevices
        Monitor all USB devices, not just phones/MTP devices.
    
    .EXAMPLE
        Start-PhoneConnectionMonitor -OnConnect { Write-Host "Phone connected!" } -OnDisconnect { Write-Host "Phone disconnected!" }
    #>
    [CmdletBinding()]
    param(
        [ScriptBlock]$OnConnect = { Write-Host "Phone connected at $(Get-Date)" -ForegroundColor Green },
        [ScriptBlock]$OnDisconnect = { Write-Host "Phone disconnected at $(Get-Date)" -ForegroundColor Yellow },
        [switch]$IncludeAllDevices
    )
    
    try {
        Write-Verbose "Starting phone connection monitor..."
        
        # Create connection detection query
        if ($IncludeAllDevices) {
            $ConnectQuery = "SELECT * FROM __InstanceCreationEvent WHERE TargetInstance ISA 'Win32_PnPEntity'"
            $DisconnectQuery = "SELECT * FROM __InstanceDeletionEvent WHERE TargetInstance ISA 'Win32_PnPEntity'"
        } else {
            $ConnectQuery = @"
SELECT * FROM __InstanceCreationEvent 

WHERE TargetInstance ISA 'Win32_PnPEntity' 
AND (TargetInstance.PNPDeviceID LIKE '%VID_04E8%' OR 
     TargetInstance.PNPDeviceID LIKE '%MTP%' OR
     TargetInstance.Description LIKE '%Android%' OR
     TargetInstance.Description LIKE '%Mobile%' OR
     TargetInstance.Description LIKE '%Phone%')
"@
            
            $DisconnectQuery = @"
SELECT * FROM __InstanceDeletionEvent 

WHERE TargetInstance ISA 'Win32_PnPEntity' 
AND (TargetInstance.PNPDeviceID LIKE '%VID_04E8%' OR 
     TargetInstance.PNPDeviceID LIKE '%MTP%' OR
     TargetInstance.Description LIKE '%Android%' OR
     TargetInstance.Description LIKE '%Mobile%' OR
     TargetInstance.Description LIKE '%Phone%')
"@
        }
        
        # Register connection event
        $ConnectAction = {
            $Device = $Event.SourceEventArgs.NewEvent.TargetInstance
            $DeviceInfo = [PSCustomObject]@{
                Name = $Device.Name
                Description = $Device.Description
                DeviceID = $Device.PNPDeviceID
                Manufacturer = $Device.Manufacturer
                Service = $Device.Service
                Status = $Device.Status
                Time = Get-Date
                EventType = "Connected"
            }
            
            # Store device info in global scope for access by custom script
            $Global:LastConnectedDevice = $DeviceInfo
            
            # Execute custom action
            & $OnConnect $DeviceInfo
        }
        
        Register-WmiEvent -Query $ConnectQuery -SourceIdentifier "PhoneConnection" -Action $ConnectAction
        $Script:ActiveSubscriptions["PhoneConnection"] = "Connected"
        
        # Register disconnection event
        $DisconnectAction = {
            $Device = $Event.SourceEventArgs.NewEvent.TargetInstance
            $DeviceInfo = [PSCustomObject]@{
                Name = $Device.Name
                Description = $Device.Description
                DeviceID = $Device.PNPDeviceID
                Time = Get-Date
                EventType = "Disconnected"
            }
            
            $Global:LastDisconnectedDevice = $DeviceInfo
            
            # Execute custom action
            & $OnDisconnect $DeviceInfo
        }
        
        Register-WmiEvent -Query $DisconnectQuery -SourceIdentifier "PhoneDisconnection" -Action $DisconnectAction
        $Script:ActiveSubscriptions["PhoneDisconnection"] = "Disconnected"
        
        Write-Host "Phone connection monitoring started successfully!" -ForegroundColor Green
        Write-Host "Monitoring for: $(if($IncludeAllDevices){'All USB devices'}else{'Phones and MTP devices only'})"
        Write-Host "Use Stop-PhoneConnectionMonitor to stop monitoring."
        
    } catch {
        Write-Error "Failed to start phone connection monitor: $($_.Exception.Message)"
        Stop-PhoneConnectionMonitor
    }
}

function Stop-PhoneConnectionMonitor {
    <#
    .SYNOPSIS
        Stops all active phone connection monitoring.
    
    .DESCRIPTION
        Unregisters all WMI event subscriptions created by this module.
    #>
    [CmdletBinding()]
    param()
    
    try {
        foreach ($subscription in $Script:ActiveSubscriptions.Keys) {
            Unregister-Event -SourceIdentifier $subscription -ErrorAction SilentlyContinue
            Write-Verbose "Stopped monitoring: $subscription"
        }
        
        $Script:ActiveSubscriptions.Clear()
        Write-Host "Phone connection monitoring stopped." -ForegroundColor Yellow
        
    } catch {
        Write-Warning "Error stopping monitor: $($_.Exception.Message)"
    }
}

function Get-ConnectedPhones {
    <#
    .SYNOPSIS
        Gets all currently connected phones and MTP devices.
    
    .DESCRIPTION
        Queries both WMI and Shell.Application to find connected phones and MTP devices.
        Returns detailed information about each device including access to file system.
    
    .EXAMPLE
        Get-ConnectedPhones | Format-Table Name, Type, Path
    #>
    [CmdletBinding()]
    param()
    
    $phones = @()
    
    try {
        # Method 1: WMI Query for PnP devices
        $pnpDevices = Get-WmiObject -Class Win32_PnPEntity | Where-Object {
            $_.PNPDeviceID -like "*MTP*" -or 
            $_.Description -like "*Android*" -or 
            $_.Description -like "*Phone*" -or
            $_.PNPDeviceID -like "*VID_04E8*"  # Samsung
        } | Where-Object { $_.Status -eq "OK" }
        
        foreach ($device in $pnpDevices) {
            $phones += [PSCustomObject]@{
                Name = $device.Name
                Description = $device.Description
                DeviceID = $device.PNPDeviceID
                Manufacturer = $device.Manufacturer
                Status = $device.Status
                Type = "PnP Device"
                Source = "WMI"
            }
        }
        
        # Method 2: Shell.Application for MTP devices
        $shell = New-Object -ComObject Shell.Application
        $computer = $shell.NameSpace(0x11) # My Computer
        
        foreach ($item in $computer.Items()) {
            if ($item.IsFolder -and ($item.Type -match "Phone|MTP|Portable" -or $item.Name -match "Android|Galaxy|iPhone")) {
                $phones += [PSCustomObject]@{
                    Name = $item.Name
                    Description = $item.Type
                    Path = $item.Path
                    Type = $item.Type
                    IsFolder = $item.IsFolder
                    Source = "Shell"
                    ShellObject = $item
                }
            }
        }
        
    } catch {
        Write-Warning "Error detecting phones: $($_.Exception.Message)"
    }
    
    return $phones | Sort-Object Name -Unique
}

function New-PermanentPhoneMonitor {
    <#
    .SYNOPSIS
        Creates a permanent WMI event subscription for phone detection.
    
    .DESCRIPTION
        Creates a permanent WMI event subscription that survives reboots and runs system-wide.
        Requires Administrator privileges.
    
    .PARAMETER ScriptPath
        Path to PowerShell script to execute when phone is connected.
    
    .PARAMETER FilterName
        Name for the WMI event filter (default: PhoneConnectionFilter).
    
    .EXAMPLE
        New-PermanentPhoneMonitor -ScriptPath "C:\Scripts\Get-S25-DCIM-Phone-Folders.ps1"
        New-PermanentPhoneMonitor -ScriptPath "A:\00--H_DRIVE--\Android_Photos_Backup\SCRIPTS\Get-S25-DCIM-Phone-Folders.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath,
        
        [string]$FilterName = "PhoneConnectionFilter",
        [string]$ConsumerName = "PhoneConnectionConsumer"
    )
    
    # Check for admin privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        throw "Administrator privileges required for permanent WMI event subscriptions."
    }
    
    if (-not (Test-Path $ScriptPath)) {
        throw "Script path does not exist: $ScriptPath"
    }
    
    try {
        # Create Event Filter
        $FilterQuery = @"
SELECT * FROM __InstanceCreationEvent 
WITHIN 10 
WHERE TargetInstance ISA 'Win32_PnPEntity' 
AND (TargetInstance.PNPDeviceID LIKE '%MTP%' OR 
     TargetInstance.Description LIKE '%Android%' OR
     TargetInstance.Description LIKE '%Phone%')
"@

        $Filter = New-CimInstance -ClassName __EventFilter -Namespace root\subscription -Property @{
            Name = $FilterName
            Query = $FilterQuery
            QueryLanguage = 'WQL'
        }
        
        # Create Event Consumer
        $ScriptText = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$ScriptPath""", 0, False
"@

        $Consumer = New-CimInstance -ClassName ActiveScriptEventConsumer -Namespace root\subscription -Property @{
            Name = $ConsumerName
            ScriptingEngine = 'VBScript'
            ScriptText = $ScriptText
        }
        
        # Bind Filter to Consumer
        $Binding = New-CimInstance -ClassName __FilterToConsumerBinding -Namespace root\subscription -Property @{
            Filter = [ref]$Filter
            Consumer = [ref]$Consumer
        }
        
        Write-Host "Permanent phone connection monitor created successfully!" -ForegroundColor Green
        Write-Host "Filter: $FilterName"
        Write-Host "Consumer: $ConsumerName"
        Write-Host "Script: $ScriptPath"
        
    } catch {
        Write-Error "Failed to create permanent monitor: $($_.Exception.Message)"
    }
}

function Remove-PermanentPhoneMonitor {
    <#
    .SYNOPSIS
        Removes permanent WMI event subscription for phone detection.
    
    .PARAMETER FilterName
        Name of the WMI event filter to remove.
    
    .EXAMPLE
        Remove-PermanentPhoneMonitor -FilterName "PhoneConnectionFilter"
    #>
    [CmdletBinding()]
    param(
        [string]$FilterName = "PhoneConnectionFilter",
        [string]$ConsumerName = "PhoneConnectionConsumer"
    )
    
    try {
        # Remove binding
        Get-CimInstance -ClassName __FilterToConsumerBinding -Namespace root\subscription | 
            Where-Object { $_.Filter.Name -eq $FilterName } | Remove-CimInstance
        
        # Remove consumer
        Get-CimInstance -ClassName ActiveScriptEventConsumer -Namespace root\subscription | 
            Where-Object { $_.Name -eq $ConsumerName } | Remove-CimInstance
        
        # Remove filter
        Get-CimInstance -ClassName __EventFilter -Namespace root\subscription | 
            Where-Object { $_.Name -eq $FilterName } | Remove-CimInstance
        
        Write-Host "Permanent phone monitor removed successfully." -ForegroundColor Green
        
    } catch {
        Write-Error "Failed to remove permanent monitor: $($_.Exception.Message)"
    }
}

function Test-PhoneConnectionEvents {
    <#
    .SYNOPSIS
        Tests phone connection event detection by monitoring for 30 seconds.
    
    .DESCRIPTION
        Starts temporary phone monitoring and waits for events for a specified duration.
        Useful for testing and verification.
    
    .PARAMETER Duration
        Duration in seconds to monitor for events (default: 30).
    
    .EXAMPLE
        Test-PhoneConnectionEvents -Duration 60
    #>
    [CmdletBinding()]
    param(
        [int]$Duration = 15
    )
    
    Write-Host "Starting phone connection test for $Duration seconds..." -ForegroundColor Cyan
    Write-Host "Please connect/disconnect your phone to test detection."
    
    $testAction = {
        param($DeviceInfo)
        Write-Host "TEST EVENT: $($DeviceInfo.EventType) - $($DeviceInfo.Name)" -ForegroundColor Magenta
        Write-Host "  Device ID: $($DeviceInfo.DeviceID)"
        Write-Host "  Time: $($DeviceInfo.Time)"
    }
    
    Start-PhoneConnectionMonitor -OnConnect $testAction -OnDisconnect $testAction -IncludeAllDevices
    
    Start-Sleep -Seconds $Duration
    Stop-PhoneConnectionMonitor
    
    Write-Host "Phone connection test completed." -ForegroundColor Green
}

function Get-PhoneStorageAccess {
    <#
    .SYNOPSIS
        Provides access to phone storage through Shell.Application COM object.
    
    .DESCRIPTION
        Returns Shell folder objects for connected phones that allow file system access.
        Useful for automated file operations with MTP devices.
    
    .PARAMETER PhoneName
        Name of the phone to access (optional, returns all if not specified).
    
    .EXAMPLE
        $phone = Get-PhoneStorageAccess -PhoneName "Galaxy S25 Ultra"
        $phone.GetFolder().Items() | Where-Object IsFolder | Select-Object Name
    #>
    [CmdletBinding()]
    param(
        [string]$PhoneName
    )
    
    try {
        $shell = New-Object -ComObject Shell.Application
        $computer = $shell.NameSpace(0x11)
        $phoneAccess = @()
        
        foreach ($item in $computer.Items()) {
            if ($item.IsFolder -and ($item.Type -match "Phone|MTP|Portable")) {
                if (-not $PhoneName -or $item.Name -like "*$PhoneName*") {
                    $phoneAccess += [PSCustomObject]@{
                        Name = $item.Name
                        Type = $item.Type
                        Path = $item.Path
                        ShellObject = $item
                        GetFolder = $item.GetFolder()
                    }
                }
            }
        }
        
        return $phoneAccess
        
    } catch {
        Write-Error "Failed to access phone storage: $($_.Exception.Message)"
    }
}

#endregion

#region Module Cleanup
function Cleanup-PhoneMonitor {
    Stop-PhoneConnectionMonitor
}

# Register cleanup on module removal
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = { Cleanup-PhoneMonitor }
#endregion

#region Export Module Members
Export-ModuleMember -Function @(
    'Start-PhoneConnectionMonitor',
    'Stop-PhoneConnectionMonitor', 
    'Get-ConnectedPhones',
    'New-PermanentPhoneMonitor',
    'Remove-PermanentPhoneMonitor',
    'Test-PhoneConnectionEvents',
    'Get-PhoneStorageAccess'
)
#endregion