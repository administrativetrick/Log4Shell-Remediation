<#	
	.NOTES
	===========================================================================
	 Created on:   	12/16/2021 12:41 PM
	 Created by:   	James Curtis
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		This script should be used to remediate the Log4Shell Vulnerability.
#>

Param (
	[Parameter(Mandatory = $true,
			   ValueFromPipeline = $true)]
	[ValidatePattern('.*\.jar$')]
	[string[]]$files
)

#Loads the required .net assembly for file compression operations
[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression') | out-null

#Replaces the .jar file extensions in files passed from files parameter and loads them into a new zipfile variable
$zipfile = $files.replace(".jar", ".zip")
#Place file names that you want to remove from a zip file in this variable
$FilesToRemove = 'JndiLookup.class'

#Function to test if EventLog Source Exists
function Test-EventLogSource
{
	Param (
		[Parameter(Mandatory = $true)]
		[string]$SourceName
	)
	
	[System.Diagnostics.EventLog]::SourceExists($SourceName)
}

#check to see if EventLog Source Exists, if it does not, create new EventLog Source
If (!(Test-EventLogSource -SourceName "Hotfix"))
{
	New-EventLog -LogName Application -Source "Hotfix"
}

#Function to write logs in a standard format
Function Write-Eventlogs
{
	Param (
		[Parameter(Mandatory = $true)]
		[string]$Message,
		[Parameter(Mandatory = $false)]
		[string]$Color
	)
	if ($color -eq $null)
	{
		$color = 'White'
	}
	Write-EventLog -LogName Application -EventId 3000 -Source "Hotfix" -Message $Message
	Write-Host $Message -ForegroundColor $color
}

#Function that can be used to convert the filenames provided into .zip format
function ConvertFrom-JarToZip
{
	Try
	{
		#Actual Rename is done here
		Rename-Item -Path $file -NewName $zipfile
		Write-EventLogs -Message "Renamed $file to $zipfile" -Color "White"
	}
	Catch
	{
		Write-EventLogs -Message "Failed to Convert $file to $zipfile" -Color "Red"
	}
}

#Function that can be used to convert the zip files back into .jar format
function ConvertFrom-ZipToJar
{
	Try
	{
		#Actual rename is done here
		Rename-Item -Path $zipfile -NewName "$file"
		Write-EventLogs -Message "Renamed $zipfile to $file" -Color "White"
	}
	Catch
	{
		Write-EventLogs -Message "Failed to Convert $zipfile to $file" -color "Red"
	}
}

#Function to remove files from a compressed archive
function Remove-FileFromCompressedFile
{
	$stream = New-Object IO.FileStream($zipfile, [IO.FileMode]::Open)
	$mode = [IO.Compression.ZipArchiveMode]::Update
	$zip = New-Object IO.Compression.ZipArchive($stream, $mode)
	
	($zip.Entries | Where-Object { $FilesToRemove -eq $_.Name }) | ForEach-Object {
		try
		{
			$_.Delete()
			Write-EventLogs -Message "Deleting $FilesToRemove from $file" -Color "Yellow"
		}
		catch
		{
			Write-Eventlogs -Message "Failed Removing JndiLookup.class from $zipfile" -color 'Red'
		}
	}
	$zip.Dispose()
	$stream.Close()
	$stream.Dispose()
}

#Foreach Loop that loops through 3 of the Functions Declared above
foreach ($file in $files)
{
	ConvertFrom-JarToZip
	Remove-FileFromCompressedFile
	ConvertFrom-ZipToJar
}
