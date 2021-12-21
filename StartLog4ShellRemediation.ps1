<#	
	.NOTES
	===========================================================================
	 Created on:   	12/16/2021 12:41 PM
	 Created by:   	James Curtis
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		This script should be used to remediate the Log4Shell Vulnerability.
	.PARAMETER files
		The Path to the vulnerable jar file that you want to remove a vulnerable file from.
	.PARAMETER FilesToRemove
		The file name that you would like to remove from the jar file. Defaults to JndiLookup.class
	.EXAMPLE
		Start-Log4ShellRemediation.ps1 -files 'C:\temp\log4shell_example\log4j-core-2.12.0.jar'
	.EXAMPLE
		Start-Log4ShellRemediation.ps1 -files 'C:\temp\log4shell_example\log4j-core-2.12.0.jar' -FilesToRemove 'someotherfile.class'
#>

Param (
	[Parameter(Mandatory = $true,
			   ValueFromPipeline = $true)]
	[string[]]$files,
	[Parameter(Mandatory = $false,
			   ValueFromPipeline = $true)]
	[string[]]$FilesToRemove = 'JndiLookup.class'
)

Add-Type -AssemblyName System.Web
$files = [System.Web.HttpUtility]::UrlDecode($files)
#Replaces the .jar file extensions in files passed from files parameter and loads them into a new zipfile variable
$zipfile = $files.replace(".jar", ".zip")

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
	#Loads the required .net assembly for file compression operations
	[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression') | out-null
	
	$stream = New-Object IO.FileStream($zipfile, [IO.FileMode]::Open)
	$mode = [IO.Compression.ZipArchiveMode]::Update
	$zip = New-Object IO.Compression.ZipArchive($stream, $mode)
	
	($zip.Entries | Where-Object { $FilesToRemove -eq $_.Name }) | ForEach-Object {
		try
		{
			$_.Delete()
			Write-EventLogs -Message "Deleting $FilesToRemove from $file" -Color "Yellow"
			If (($_.name -eq $null -OR $_.name -eq ""))
			{
				Write-Host "No targeted files found"
			}
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
