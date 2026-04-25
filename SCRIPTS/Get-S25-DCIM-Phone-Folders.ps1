#Requires -Version 5.1

<#
.SYNOPSIS
    Advanced Android MTP backup utility for PowerShell
    
.DESCRIPTION
    This module provides advanced functions to backup Android device content via MTP protocol.
    It supports recursive folder backup with detailed progress reporting and error handling.
    
.NOTES
    Author: Refactored from original nosalan/powershell-mtp-file-transfer
    Version: 2.0
    Requires: PowerShell 5.1 or higher
#>
#automatic detection of phone device
Remove-Variable backupConfig  -ErrorAction SilentlyContinue
$backupConfig = @{
    DeviceName      = ""
    StorageRoot     = "Stockage interne"
    DestinationRoot = "P:\"
    BackupMappings  = [ordered]@{
        'DCIM\Camera'      = ''
        'DCIM\Screenshots' = 'Screenshots'
        'WhatsApp'         = 'WhatsAPP'
        #'Download'         = 'Download_S25'
    }
}

#device defined
Remove-Variable backupConfig  -ErrorAction SilentlyContinue
$backupConfig = @{
    DeviceName      = "Galaxy S25 Ultra"
    StorageRoot     = "Stockage interne"
    DestinationRoot = "P:\"
    BackupMappings  = [ordered]@{
        'DCIM\Camera'      = ''
        'DCIM\Screenshots' = 'Screenshots'
        'WhatsApp'         = 'WhatsAPP'
        'Download'         = 'Download_S25'
    }
}



class BackupSummary {
    [int]$NewFilesCount = 0
    [int]$ExistingFilesCount = 0
    [int]$ErrorCount = 0
    [datetime]$StartTime
    [datetime]$EndTime
    
    BackupSummary() {
        $this.StartTime = Get-Date
    }
    
    [void]Complete() {
        $this.EndTime = Get-Date
    }
    
    [string]ToString() {
        $duration = if ($this.EndTime) { 
            ($this.EndTime - $this.StartTime).ToString("hh\:mm\:ss") 
        }
        else { 
            "In progress..." 
        }
        return "Backup Summary - New: $($this.NewFilesCount), Existing: $($this.ExistingFilesCount), Errors: $($this.ErrorCount), Duration: $duration"
    }
}

function New-BackupDirectory {
    <#
    .SYNOPSIS
        Creates a backup directory if it doesn't exist
        
    .DESCRIPTION
        Creates the specified directory path and all necessary parent directories.
        Provides verbose output when -Verbose parameter is used.
        
    .PARAMETER Path
        The directory path to create
        
    .EXAMPLE
        New-BackupDirectory -Path "C:\Backup\Photos" -Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    
    process {
        try {
            if (-not (Test-Path -Path $Path -PathType Container)) {
                Write-Verbose "Creating directory: $Path"
                $null = New-Item -Path $Path -ItemType Directory -Force
                Write-Output "Created directory: $Path"
            }
            else {
                Write-Verbose "Directory already exists: $Path"
            }
        }
        catch {
            Write-Error "Failed to create directory '$Path': $($_.Exception.Message)"
            throw
        }
    }
}

function Get-MtpDevice {
    <#
    .SYNOPSIS
        Retrieves MTP device from Windows Shell
        
    .DESCRIPTION
        Connects to the specified MTP device using Windows Shell Application COM object.
        Validates device connectivity before returning the device object.
        
    .PARAMETER DeviceName
        The name of the MTP device as it appears in "This PC"
        
    .EXAMPLE
        $device = Get-MtpDevice -DeviceName "Galaxy S25 Ultra"
    #>
    [CmdletBinding()]
    [OutputType([System.__ComObject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [AllowNull()] 
        [string]$DeviceName
    )
    
    process {
        try {
            Write-Verbose "Searching for MTP device: $DeviceName"
            $shellApp = New-Object -ComObject Shell.Application
            $computerNamespace = $shellApp.NameSpace(0x11)
            if ([string]::IsNullOrEmpty($DeviceName)) {
                $device = $computerNamespace.Items() | Where-Object { $_.path.length -gt 30 } | Select-Object -First 1
            }
            else {
                $device = $computerNamespace.Items() | 
                Where-Object { $_.Name -eq $DeviceName } | 
                Select-Object -First 1
            }

            if (-not $device) {
                throw "MTP device '$DeviceName' not found. Please ensure the device is connected and MTP is enabled."
            }
            
            Write-Verbose "Successfully connected to device: $DeviceName"
            return $device
        }
        catch {
            Write-Error "Failed to connect to MTP device '$DeviceName': $($_.Exception.Message)"
            throw
        }
    }
}

function Get-MtpFolder {
    <#
    .SYNOPSIS
        Navigates to a specific folder on MTP device
        
    .DESCRIPTION
        Traverses the MTP device folder structure to locate the specified subfolder path.
        Supports nested folder navigation using backslash-separated paths.
        
    .PARAMETER ParentFolder
        The parent MTP folder object to start navigation from
        
    .PARAMETER SubPath
        The relative path to the target folder (e.g., "DCIM\Camera")
        
    .EXAMPLE
        $cameraFolder = Get-MtpFolder -ParentFolder $deviceRoot -SubPath "DCIM\Camera"
    #>
    [CmdletBinding()]
    [OutputType([System.__ComObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.__ComObject]$ParentFolder,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SubPath
    )
    
    process {
        try {
            $currentFolder = $ParentFolder
            $pathSegments = $SubPath -split '[\\/]' | Where-Object { $_ }
            
            foreach ($segment in $pathSegments) {
                Write-Verbose "Navigating to folder segment: $segment"
                $nextFolder = $currentFolder.GetFolder.Items() | 
                Where-Object { $_.Name -eq $segment } | 
                Select-Object -First 1
                
                if (-not $nextFolder) {
                    throw "Folder '$segment' not found in path '$SubPath'"
                }
                
                $currentFolder = $nextFolder
            }
            
            Write-Verbose "Successfully navigated to: $SubPath"
            return $currentFolder
        }
        catch {
            Write-Error "Failed to navigate to folder '$SubPath': $($_.Exception.Message)"
            throw
        }
    }
}

function Get-MtpFolderPath {
    <#
    .SYNOPSIS
        Gets the full path of an MTP folder
        
    .DESCRIPTION
        Reconstructs the full path of an MTP folder by traversing up the parent hierarchy.
        Useful for logging and debugging purposes.
        
    .PARAMETER MtpFolder
        The MTP folder object to get the path for
        
    .EXAMPLE
        $path = Get-MtpFolderPath -MtpFolder $cameraFolder
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.__ComObject]$MtpFolder
    )
    
    process {
        try {
            $pathComponents = @()
            $currentDirectory = $MtpFolder.GetFolder
            
            while ($currentDirectory) {
                if ($currentDirectory.Title) {
                    $pathComponents = @($currentDirectory.Title) + $pathComponents
                }
                $currentDirectory = $currentDirectory.ParentFolder
            }
            
            $fullPath = $pathComponents -join '\'
            Write-Verbose "MTP folder path: $fullPath"
            return $fullPath
        }
        catch {
            Write-Error "Failed to get MTP folder path: $($_.Exception.Message)"
            return "Unknown Path"
        }
    }
}

function Copy-MtpContent {
    <#
    .SYNOPSIS
        Recursively copies content from MTP source to local destination
        
    .DESCRIPTION
        Performs recursive backup of MTP folder content to a local directory.
        Supports file skipping for existing files and provides detailed progress reporting.
        Includes retry logic for handling temporary MTP communication issues.
        
    .PARAMETER SourceMtpFolder
        The source MTP folder object to copy from
        
    .PARAMETER DestinationPath
        The local destination directory path
        
    .PARAMETER Summary
        The backup summary object to track statistics
        
    .PARAMETER MaxRetries
        Maximum number of retry attempts for failed operations
        
    .EXAMPLE
        $summary = [BackupSummary]::new()
        Copy-MtpContent -SourceMtpFolder $cameraFolder -DestinationPath "C:\Backup\Photos" -Summary $summary
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.__ComObject]$SourceMtpFolder,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [BackupSummary]$Summary,
        
        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3
    )
    
    process {
        try {
            # Normalize destination path
            $normalizedDestination = $DestinationPath 
            
            # Create destination directory
            New-BackupDirectory -Path $normalizedDestination -Verbose:$VerbosePreference
            
            # Get source folder information
            $sourcePath = Get-MtpFolderPath -MtpFolder $SourceMtpFolder
            Write-Information "Processing folder: $sourcePath" -InformationAction Continue
         
            if ($PSCmdlet.ShouldProcess($sourcePath, "Backup to $normalizedDestination")) {
                $shellApp = New-Object -ComObject Shell.Application
                $destinationShell = $shellApp.NameSpace($normalizedDestination)
                
                $items = $SourceMtpFolder.GetFolder.Items()
                $itemCount = @($items).Count
                Write-Verbose "Found $itemCount items to process"
                
                $currentItem = 0
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Write-Progress -Activity "Initialization" -Status "Starting up..." -PercentComplete 0 -Id 1
                foreach ($item in $items) {
                    $currentItem++
                    $itemName = $item.Name
                    $destinationFile = Join-Path $normalizedDestination $itemName
                    
                    if ($sw.Elapsed.TotalMilliseconds -ge 500) {
                        Write-Progress -Activity "Backing up $sourcePath" -Status $itemName -PercentComplete (($currentItem / $itemCount) * 100) -id 1
                        $sw.Reset(); $sw.Start()
                    }

                    try {
                        if ($item.IsFolder) {
                            Write-Verbose "Processing subfolder: $itemName"
                            $subfolderDestination = Join-Path $normalizedDestination $item.GetFolder.Title
                            Copy-MtpContent -SourceMtpFolder $item -DestinationPath $subfolderDestination -Summary $Summary -MaxRetries $MaxRetries
                        }
                        elseif ([system.io.file]::Exists($destinationFile)) {
                            Write-Verbose "File already exists: $itemName"
                            $Summary.ExistingFilesCount++
                        }
                        else {
                            $retryCount = 0
                            $copySuccess = $false
                            
                            do {
                                try {
                                    Write-Verbose "Copying file ($($retryCount + 1)/$MaxRetries): $itemName"
                                    $destinationShell.CopyHere($item, 4 + 16) # 4 = No dialog, 16 = Yes to all
                                    $copySuccess = $true
                                    $Summary.NewFilesCount++
                                    Write-Information "Copied: $itemName" -InformationAction Continue
                                }
                                catch {
                                    $retryCount++
                                    if ($retryCount -lt $MaxRetries) {
                                        Write-Warning "Copy failed, retrying ($retryCount/$MaxRetries): $itemName"
                                        Start-Sleep -Seconds 2
                                    }
                                    else {
                                        throw
                                    }
                                }
                            } while (-not $copySuccess -and $retryCount -lt $MaxRetries)
                            
                            if (-not $copySuccess) {
                                throw "Failed to copy file after $MaxRetries attempts: $itemName"
                            }
                        }
                    }
                    catch {
                        Write-Error "Error processing item '$itemName': $($_.Exception.Message)"
                        $Summary.ErrorCount++
                    }
                }
                
                Write-Progress -Activity "Backing up $sourcePath" -Completed -Id 1
                Write-Information "Completed backup of: $sourcePath" -InformationAction Continue
            }
        }
        catch {
            Write-Error "Failed to backup MTP content from '$sourcePath': $($_.Exception.Message)"
            $Summary.ErrorCount++
            throw
        }
    }
}

function Start-AndroidBackup {
    <#
    .SYNOPSIS
        Performs complete Android device backup via MTP
        
    .DESCRIPTION
        Main function that orchestrates the backup process for specified Android device folders.
        Supports customizable source and destination mappings with comprehensive error handling.
        
    .PARAMETER DeviceName
        The name of the Android device as it appears in "This PC"
        
    .PARAMETER StorageRoot
        The root storage name on the device (e.g., "Internal storage", "Stockage interne")
        
    .PARAMETER BackupMappings
        Hashtable defining source folder to destination folder mappings
        
    .PARAMETER DestinationRoot
        The root destination path for all backups
        
    .EXAMPLE
        $mappings = @{
            'DCIM\Camera' = 'Photos'
            'DCIM\Screenshots' = 'Screenshots'
            'WhatsApp' = 'WhatsApp_Backup'
        }
        Start-AndroidBackup -DeviceName "Galaxy S25 Ultra" -StorageRoot "Internal storage" -BackupMappings $mappings -DestinationRoot "D:\AndroidBackup"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DeviceName,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageRoot,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable]$BackupMappings,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationRoot
    )
    
    begin {
        $summary = [BackupSummary]::new()
        Write-Information "Starting Android backup process..." -InformationAction Continue
    }
    
    process {
        try {
            # Connect to device
            $device = Get-MtpDevice -DeviceName $DeviceName
            
            # Process each backup mapping
            foreach ($mapping in $BackupMappings.GetEnumerator()) {
                $sourcePath = "$StorageRoot\$($mapping.Key)"
                $destinationPath = Join-Path $DestinationRoot $mapping.Value
                
                try {
                    Write-Information "Backing up: $sourcePath -> $destinationPath" -InformationAction Continue
                    
                    $sourceFolder = Get-MtpFolder -ParentFolder $device -SubPath $sourcePath
                    Copy-MtpContent -SourceMtpFolder $sourceFolder -DestinationPath $destinationPath -Summary $summary
                }
                catch {
                    Write-Warning "Failed to backup '$sourcePath': $($_.Exception.Message)"
                    $summary.ErrorCount++
                    continue
                }
            }
        }
        catch {
            Write-Error "Backup process failed: $($_.Exception.Message)"
            throw
        }
        finally {
            $summary.Complete()
            Write-Information $summary.ToString() -InformationAction Continue
        }
    }
    
    end {
        return $summary
    }
}

# Configuration example
<#
$backupConfig = @{
    DeviceName = "Galaxy S25 Ultra"
    StorageRoot = "Internal storage"
    DestinationRoot = "P:\"
    BackupMappings = @{
        'DCIM\Camera' = ''
        'DCIM\Screenshots' = 'Screenshots'
        'WhatsApp' = 'WhatsAPP'
        'Download' = 'Download_S25'
    }
}#>

#Cleaning





# Usage example
$result = Start-AndroidBackup @backupConfig -Verbose -InformationAction Continue
Write-Host "Backup completed: $($result.ToString())" -ForegroundColor Green
