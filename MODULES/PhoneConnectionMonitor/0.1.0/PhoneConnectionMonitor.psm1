# PhoneConnectionMonitor.psm1
# Enhanced PowerShell module for monitoring phone connections via WMI events

<#
.SYNOPSIS
    Advanced PowerShell module for detecting and handling mobile device connections on Windows.

.DESCRIPTION
    This module provides multiple detection methods including temporary WMI events, 
    permanent event subscriptions with NTEventLog consumers, and Shell.Application integration
    for MTP device file access. Includes comprehensive error handling and logging.

.NOTES
    Author: PowerShell Event Handler Examples
    Version: 2.0
    Requires: PowerShell 5.1+ and Administrator privileges for permanent subscriptions
#>

#region Private Variables
$Script:ActiveSubscriptions = @{}
$Script:LogSource = "PhoneConnectionMonitor"
#endregion

#region Public Functions

function Start-PhoneConnectionMonitor {
    <#
    .SYNOPSIS
        Starts temporary WMI event monitoring for device connections.
    
    .PARAMETER OnConnect
        Scriptblock to execute on device connection
    
    .PARAMETER OnDisconnect
        Scriptblock to execute on device disconnection
    #>
    [CmdletBinding()]
    param(
        [ScriptBlock]$OnConnect,
        [ScriptBlock]$OnDisconnect
    )
    
    try {
        $ConnectQuery = @"
        SELECT * FROM __InstanceCreationEvent 
        WITHIN 2 
        WHERE TargetInstance ISA 'Win32_PnPEntity' 
        AND (TargetInstance.PNPDeviceID LIKE '%VID_04E8%' OR 
             TargetInstance.Description LIKE '%Android%')
"@
        
        $ConnectAction = {
            $Device = $Event.SourceEventArgs.NewEvent.TargetInstance
            & $OnConnect $Device
        }
        
        Register-WmiEvent -Query $ConnectQuery -SourceIdentifier "PhoneConnection" -Action $ConnectAction
        $Script:ActiveSubscriptions["PhoneConnection"] = $true
    }
    catch {
        Write-Error "Monitoring failed: $($_.Exception.Message)"
    }
}

function New-PhoneEventLogMonitor {
    <#
    .SYNOPSIS
        Creates permanent WMI event subscription with NTEventLog consumer.
    
    .PARAMETER FilterName
        Name for the WMI event filter
    
    .PARAMETER ConsumerName
        Name for the NTEventLog consumer
    
    .EXAMPLE
        New-PhoneEventLogMonitor -FilterName "AndroidMonitor" -ConsumerName "AndroidLogger"
    #>
    [CmdletBinding()]
    param(
        [string]$FilterName = "PhoneConnectionFilter",
        [string]$ConsumerName = "PhoneConnectionConsumer"
    )
    
    $EventFilterArgs = @{
        EventNamespace = 'root/cimv2'
        Name = $FilterName
        Query = "SELECT * FROM __InstanceCreationEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_PnPEntity' AND TargetInstance.Description LIKE '%Android%'"
        QueryLanguage = 'WQL'
    }

    $Filter = Set-WmiInstance -Namespace 'root/subscription' -Class '__EventFilter' -Arguments $EventFilterArgs

    $Template = @(
        'Device Connected: %TargetInstance.Name%',
        'Description: %TargetInstance.Description%',
        'DeviceID: %TargetInstance.PNPDeviceID%'
    )

    $NtEventLogArgs = @{
        Name = $ConsumerName
        Category = 0
        EventType = 2
        EventID = 8
        SourceName = 'PhoneMonitor'
        NumberOfInsertionStrings = $Template.Length
        InsertionStringTemplates = $Template
    }

    $Consumer = Set-WmiInstance -Namespace 'root/subscription' -Class 'NTEventLogEventConsumer' -Arguments $NtEventLogArgs

    $BindingArgs = @{
        Filter = $Filter
        Consumer = $Consumer
    }

    Set-WmiInstance -Namespace 'root/subscription' -Class '__FilterToConsumerBinding' -Arguments $BindingArgs
}

function Get-ConnectedMtpDevices {
    <#
    .SYNOPSIS
        Retrieves MTP devices using Shell.Application COM object
    
    .EXAMPLE
        Get-ConnectedMtpDevices | Select-Object Name, Path
    #>
    $shell = New-Object -ComObject Shell.Application
    $devices = @()
    
    $shell.NameSpace(0x11).Items() | Where-Object {
        $_.IsFolder -and $_.Type -match "Portable Device|MTP"
    } | ForEach-Object {
        $devices += [PSCustomObject]@{
            Name = $_.Name
            Path = $_.Path
            Type = $_.Type
        }
    }
    
    return $devices
}

function Remove-PhoneMonitor {
    <#
    .SYNOPSIS
        Removes permanent WMI event subscriptions
    #>
    [CmdletBinding()]
    param(
        [string]$FilterName = "PhoneConnectionFilter",
        [string]$ConsumerName = "PhoneConnectionConsumer"
    )
    
    Get-WmiObject -Namespace 'root/subscription' -Class '__EventFilter' -Filter "Name='$FilterName'" | Remove-WmiObject
    Get-WmiObject -Namespace 'root/subscription' -Class 'NTEventLogEventConsumer' -Filter "Name='$ConsumerName'" | Remove-WmiObject
    Get-WmiObject -Namespace 'root/subscription' -Class '__FilterToConsumerBinding' -Filter "Filter='__EventFilter.Name=`"$FilterName`"'" | Remove-WmiObject
}

#endregion

#region Module Cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Get-EventSubscriber | Unregister-Event
}
#endregion

# Export module members
Export-ModuleMember -Function @(
    'Start-PhoneConnectionMonitor',
    'New-PhoneEventLogMonitor',
    'Get-ConnectedMtpDevices',
    'Remove-PhoneMonitor'
)
