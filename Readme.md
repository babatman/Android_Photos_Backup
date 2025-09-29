# Advanced Android MTP Photos&more Backup Script for PowerShell - Windows

![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![Platform Support](https://img.shields.io/badge/Platform-Windows-lightgrey)

PowerShell script for backing up Android devices Photos & more via MTP protocol, example for 2025 flagship devices like the **Samsung Galaxy S25 Ultra** 

## Features
- 🔄 Recursive backup of nested directories
- 📊 Real-time progress tracking and statistics
- 🔒 Error handling with automatic retries (3 attempts default)
- 📱 Verified compatibility with Galaxy S25 Ultra MTP implementation
- 📅 Last tested with Windows 11 24H2 MTP stack


## Clone repository

git clone https://github.com/babatman/Android_Photos_Backup.git


## Prerequisites
```
Install PowerShell extension
```

## Set values for your phones

Update $backupConfig variable at the begining of SCRIPTS\Get-S25-DCIM-Phone-Folders.ps1

```
$backupConfig = @{
    DeviceName      = "Galaxy S25 Ultra"
    StorageRoot     = "Stockage interne"
    DestinationRoot = "D:\Backup"
    BackupMappings  = [ordered]@{
        'DCIM\Camera'      = ''
        'DCIM\Screenshots' = 'Screenshots'
        'WhatsApp'         = 'WhatsAPP'
        'Download'         = 'Download_S25'
    }
}
```
```
Explained
$backupConfig = @{
    DeviceName      = "Galaxy S25 Ultra" >>> This is the device you see in windows explorer
    StorageRoot     = "Stockage interne" >>> This is the folder under <device name>
    DestinationRoot = "D:\Backup"        >>> This is the folder where you want to backup data
    BackupMappings  = [ordered]@{
        'DCIM\Camera'      = ''          >>> first value is the phone folder you want to backup , second value the destination (under DestinationRoot) 
        'DCIM\Screenshots' = 'Screenshots'  >>> e.g. Galaxy S25 Ultra\Stockage interne\DCIM\Screenshots will be backp up into D:\Backup\Screenshots
        'WhatsApp'         = 'WhatsAPP'
        'Download'         = 'Download_S25'
    }
}
```

## Usage in Visual Studio Code
```
CTRL+SHIFT+u 
Set-ExecutionPolicy RemoteSigned -Scope Process

CTRL+Shift+p
powershell:run

```

## Debugging with powershell
https://devblogs.microsoft.com/scripting/debugging-powershell-script-in-visual-studio-code-part-1/

## Output example
```
COMMENTAIRES : File already exists: 20250401_082225.jpg
COMMENTAIRES : File already exists: 20250927_105117.jpg
COMMENTAIRES : File already exists: VID_20250302_173740.mp4 
COMMENTAIRES : File already exists: 20250807_173646.jpg
COMMENTAIRES : File already exists: 20250329_162850.jpg
COMMENTAIRES : File already exists: 20250822_210023.jpg
COMMENTAIRES : File already exists: 20250726_214503(0).jpg
COMMENTAIRES : File already exists: 20250316_151916.jpg
Completed backup of: Bureau\Ce PC\Galaxy S25 Ultra\Stockage interne\DCIM\Camera
Backup Summary - New: 0, Existing: 9620, Errors: 0, Duration: 00:00:30
Backup completed: Backup Summary - New: 0, Existing: 9620, Errors: 0, Duration: 00:00:30
PS A:\00--H_DRIVE--\Android_Photos_Backup>
```