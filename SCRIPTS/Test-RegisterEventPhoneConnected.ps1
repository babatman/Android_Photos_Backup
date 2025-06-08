# Based off @mattifestation's example: https://gist.github.com/mattifestation/aff0cb8bf66c7f6ef44a
# Define the signature - i.e. __EventFilter
$EventFilterArgs = @{
    EventNamespace = 'root/cimv2'
    Name = 'HumanInterfaceDevice'
    #Query = 'SELECT * FROM __InstanceCreationEvent WITHIN 5 WHERE TargetInstance ISA "Win32_PointingDevice" OR TargetInstance ISA "Win32_KeyBoard"'
    query = "SELECT * FROM __InstanceCreationEvent WITHIN 2 WHERE TargetInstance ISA 'Win32_PnPEntity'"
    QueryLanguage = 'WQL'
}


$InstanceArgs = @{
    Namespace = 'root/subscription'
    Class = '__EventFilter'
    Arguments = $EventFilterArgs
}

$Filter = Set-WmiInstance @InstanceArgs

# Define the event log template and parameters
# Because this is an intrinsic event, you must reference TargetInstance when accessing columns from the WQL results
$Template = @(
    'HID Device Connected',
    'Name: %TargetInstance.Name%',
    'Description: %TargetInstance.Description%',
    'Type: %TargetInstance.CreationClassName%',
    'PNPDeviceID: %TargetInstance.PNPDeviceID%'
)

$NtEventLogArgs = @{
    Name = 'Android_ConnectionEvent'
    Category = [UInt16] 0
    EventType = [UInt32] 2 # Warning
    EventID = [UInt32] 8
    SourceName = 'WSH'
    NumberOfInsertionStrings = [UInt32] $Template.Length
    InsertionStringTemplates = $Template
}

$InstanceArgs = @{
    Namespace = 'root/subscription'
    Class = 'NTEventLogEventConsumer'
    Arguments = $NtEventLogArgs
}

$Consumer = Set-WmiInstance @InstanceArgs

$FilterConsumerBingingArgs = @{
    Filter = $Filter
    Consumer = $Consumer
}

$InstanceArgs = @{
    Namespace = 'root/subscription'
    Class = '__FilterToConsumerBinding'
    Arguments = $FilterConsumerBingingArgs
}

# Run the following code from an elevated PowerShell console.

# Register the alert
$Binding = Set-WmiInstance @InstanceArgs

# Delete the permanent WMI event subscriptions you just made
<#
Get-WmiObject -Namespace 'root/subscription' -Class '__EventFilter' -Filter 'Name="HumanInterfaceDevice"' | Remove-WmiObject
Get-WmiObject -Namespace 'root/subscription' -Class 'NTEventLogEventConsumer' -Filter 'Name="HIDConnectionEvent"' | Remove-WmiObject
Get-WmiObject -Namespace 'root/subscription' -Class '__FilterToConsumerBinding' -Filter 'Filter="__EventFilter.Name=\"HumanInterfaceDevice\""' | Remove-WmiObject
#>