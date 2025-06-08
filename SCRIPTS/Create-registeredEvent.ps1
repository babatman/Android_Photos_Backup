# Import the module
Import-Module .\MODULES\PhoneConnectionMonitor

# Define custom actions for phone connection
$OnPhoneConnect = {
    param($DeviceInfo)
    
    # Log to Windows Event Log
    Write-EventLog -LogName Application -Source "PhoneMonitor" -EventId 1001 -Message "Phone Connected: $($DeviceInfo.Name)"
    
    # Display notification
    Write-Host "📱 Phone Connected: $($DeviceInfo.Name)" -ForegroundColor Green
    Write-Host "   Time: $($DeviceInfo.Time)"
    Write-Host "   Device ID: $($DeviceInfo.DeviceID)"
    
    # Optional: Trigger backup or sync script
    if (Test-Path "C:\Scripts\BackupPhone.ps1") {
        . .\A:\00--H_DRIVE--\Android_Photos_Backup\SCRIPTS\Get-S25-DCIM-Phone-Folders.ps1
    }
}

$OnPhoneDisconnect = {
    param($DeviceInfo)
    
    Write-EventLog -LogName Application -Source "PhoneMonitor" -EventId 1002 -Message "Phone Disconnected: $($DeviceInfo.Name)"
    Write-Host "📱 Phone Disconnected: $($DeviceInfo.Name)" -ForegroundColor Yellow
}

# Start monitoring
Test-PhoneConnectionEvents -Duration 20
#Start-PhoneConnectionMonitor -OnConnect $OnPhoneConnect -OnDisconnect $OnPhoneDisconnect -IncludeAllDevices

# Keep the script running
Write-Host "Phone monitoring active. Press Ctrl+C to stop."
try {
    while ($true) { Start-Sleep -Seconds 1 }
}
finally {
    Stop-PhoneConnectionMonitor
}



# New-PermanentPhoneMonitor -ScriptPath "A:\00--H_DRIVE--\Android_Photos_Backup\SCRIPTS\Get-S25-DCIM-Phone-Folders.ps1"