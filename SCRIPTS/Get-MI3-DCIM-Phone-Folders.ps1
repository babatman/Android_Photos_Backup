#this is an enhanced version of https://github.com/nosalan/powershell-mtp-file-transfer/blob/master/phone_backup.ps1
#it supports backing up nested folders

$ErrorActionPreference = [string]"Stop"
$destpath = "P:"
$DestDirForPhotos = [string]"$destpath"
$DestDirForPhotosScreenShoot = "P:\SCreenshoots"


$DestDirForCallRecordings = [string]"$destpath\TELEFON_CALL_RECORDINGS_ALL"
$DestDirForVoiceRecordings = [string]"$destpath\TELEFON_VOICE_RECORDINGS_ALL"
$DestDirForWhatsApp = [string]"$destpath\WhatsAPP"
$DestDirForTello= [string]"$destpath\TelloVideo"

$DestDirForViber = [string]"$destpath\TELEFON_VIBER_ALL"
$Summary = [Hashtable]@{NewFilesCount=0; ExistingFilesCount=0}
$phoneName = "MI 3W" #Phone name as it appears in This PC
$firstRootPhoneName = "Mémoire de stockage interne"
$destRoot = "A:\BACKUP_ANDROID\RootFolderMI3-29-09-2022"

function Create-Dir($path)
{
  if(! (Test-Path -Path $path))
  {
    Write-Host "Creating: $path"
    New-Item -Path $path -ItemType Directory
  }
  else
  {
    Write-Host "Path $path already exist"
  }
}


function Get-SubFolder($parentDir, $subPath)
{
    Remove-Variable result -ErrorAction SilentlyContinue
  $result = $parentDir
  foreach($pathSegment in ($subPath -split "\\"))
  {
    $result = $result.GetFolder.Items() | Where-Object {$_.Name -eq $pathSegment} | select -First 1
    if($result -eq $null)
    {
      throw "Not found $subPath folder"
    }
  }
  return $result;
}


function Get-PhoneMainDir($phoneName)
{
  $o = New-Object -com Shell.Application
  $rootComputerDirectory = $o.NameSpace(0x11)
  $phoneDirectory = $rootComputerDirectory.Items() | Where-Object {$_.Name -eq $phoneName} | select -First 1
    
  if($phoneDirectory -eq $null)
  {
    throw "Not found '$phoneName' folder in This computer. Connect your phone."
  }
  
  return $phoneDirectory;
}


function Get-FullPathOfMtpDir($mtpDir)
{
 $fullDirPath = ""
 $directory = $mtpDir.GetFolder
 while($directory -ne $null)
 {
   $fullDirPath =  -join($directory.Title, '\', $fullDirPath)
   $directory = $directory.ParentFolder;
 }
 return $fullDirPath
}



function Copy-FromPhoneSource-ToBackup($sourceMtpDir, $destDirPath)
{
$destDirPath = $destDirPath -replace "\w{3,}\:","µ"
 Create-Dir $destDirPath
 $destDirShell = (new-object -com Shell.Application).NameSpace($destDirPath)
 $fullSourceDirPath = Get-FullPathOfMtpDir $sourceMtpDir

 
 Write-Host "Copying from: '" $fullSourceDirPath "' to '" $destDirPath "'"
 
 $copiedCount, $existingCount = 0
 $items= $sourceMtpDir.GetFolder.Items()

 foreach ($item in $items)
  {
   $itemName = ($item.Name)
   $fullFilePath = Join-Path -Path $destDirPath -ChildPath $itemName

   if($item.IsFolder)
   {
      Write-Host $item.Name " is folder, stepping into"
      Copy-FromPhoneSource-ToBackup  $item (Join-Path $destDirPath $item.GetFolder.Title)
   }
   elseif([System.IO.file]::Exists($fullFilePath))
   {
      Write-Host "Element '$itemName' already exists"
      $existingCount++;
   }
   else
   {
     $copiedCount++;
     Write-Host ("Copying #{0}: {1}{2}" -f $copiedCount, $fullSourceDirPath, $item.Name)
     $destDirShell.CopyHere($item)
   }
  }
  $script:Summary.NewFilesCount += $copiedCount 
  $script:Summary.ExistingFilesCount += $existingCount 
  Write-Host "Copied '$copiedCount' elements from '$fullSourceDirPath'"
}




$phoneRootDir = Get-PhoneMainDir $phoneName



Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "$firstRootPhoneName\DCIM\Camera") $DestDirForPhotos
#Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "$firstRootPhoneName\DCIM\Screenshots") $DestDirForPhotosScreenShoot
#Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "$firstRootPhoneName\WhatsApp") $DestDirForWhatsApp
#Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "$firstRootPhoneName\TelloVideo") $DestDirForTello
#Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "$firstRootPhoneName") $destRoot

# Attention
#>>> $destDirPath -replace "\:","µ"
#


<#Ce PC\MI 8\Espace de stockage interne partagé\DCIM\Screenshots
Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\ACRCalls") $DestDirForCallRecordings
Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\VoiceRecorder") $DestDirForVoiceRecordings
Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\WhatsApp") $DestDirForWhatsApp

Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\viber") $DestDirForViber
Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Card\DCIM\Camera") $DestDirForPhotos
#>
write-host ($Summary | out-string)


#cd C:\Users\admin\AppData\Local\MiPhoneManager\main
# lancer le dameon de la nouvelle version
#adb devices
#adb backup –all > not working
#repartir dans dossier d'une ancienne version
#cd C:\Program Files\Android SDK platform\platform-tools_r31.0.3-windows\platform-tools\
#C:\Program Files\Android SDK platform\platform-tools_r31.0.3-windows\platform-tools>adb backup -all

#adb  
#adb.exe install "%~f0\..\..\apps\app_sample\samples\sample_app\build\outputs\apk\sample_app-debug.apk
#J:\Téléchargements\platform-tools_r33.0.3-windows\platform-tools