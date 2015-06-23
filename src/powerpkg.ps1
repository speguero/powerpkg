
<#
	.SYNOPSIS
	powerpkg: A Windows package deployment script with an emphasis on simplicity and standardization.
	
	.DESCRIPTION
	For information in regards to usage, consult the powerpkg README.md file.
	
	.NOTES
	The MIT License (MIT)

	Copyright (c) 2015 Steven Peguero

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
#>

# ---- VARIABLES ----

$ErrorActionPreference = "Stop"

$Script = @{
	"CurrentDirectory" = (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition) + "\"
	"CurrentPSVersion" = $Host.Version.Major
	"ExitCode"         = 0
	"Output"           = $Null
}

$Script += @{
	"Config" = @{
		"Content"              = $Null
		"BlockHost"            = $Null
		"FilePath"             = $Script.CurrentDirectory + "powerpkg.conf"
		"SuppressNotification" = $True
		"TotalImported"        = 0
		"ImportState"          = $Null # Reports as to whether or not any script configuration file arguments were imported.
	}
}

$Machine = @{
	"InstructionSet" = [System.Environment]::GetEnvironmentVariable("Processor_Architecture")
	"OSVersion"      = [System.Environment]::OSVersion.Version.ToString()
	"Hostname"       = [System.Environment]::GetEnvironmentVariable("ComputerName")
	"Username"       = [System.Environment]::GetEnvironmentVariable("Username")
	"SystemDrive"    = [System.Environment]::GetEnvironmentVariable("SystemDrive")
	"ProgramList"    = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" | % {Get-ItemProperty $_.PSPath}
}

$Package = @{
	"Name"       = $MyInvocation.MyCommand.Definition.Split("\")[-2]
	"Config"     = @{
		"FilePath"      = $Null
		"FilePath_CSV"  = $Script.CurrentDirectory + "package.csv"
		"FilePath_JSON" = $Script.CurrentDirectory + "package.json"
	}
	"Result"     = $Null
	"Syntax"     = @{
		"Executable"    = @{
			"LocalFile" = "(\[)LocalFile(\])"
			"Sanitizer" = (
				"\;(.*)$",
				"\&(.*)$",
				"\|(.*)$",
				"(\s+)$" # Removes extraneous whitespace adjacent to the end of a specified executable path.
			)
		}
		"VerifyInstall" = @{
			# NOTE: Arg_Build cannot parse uncommonly used, non-alphanumeric characters, such as commas, on PowerShell 2.0. Update to 3.0+ to circumvent this issue.

			"Arg_Build"                = "\[Build:(.*)\]$"       # [Build:<Version Build>] (Used in conjunction with "Type_Version_FileInfo" and "Type_Version_ProductInfo".)
			"Type_Hotfix"              = "^(\[)Hotfix(\])"       # [Hotfix]<Hotfix ID>
			"Type_Path"                = "^(\[)Path(\])"         # [Path]<File/Directory Path>
			"Type_Version_FileInfo"    = "^(\[)Vers_File(\])"    # [Vers_File]<File Path>[Build:<Version Build>]
			"Type_Version_ProductInfo" = "^(\[)Vers_Product(\])" # [Vers_Product]<File Path>[Build:<Version Build>]
			"Type_Program"             = "^(\[)Program(\])"      # [Program]<Program Name>[Build:<Version Build>] OR [Program]<Program Name>]
		}
	}
	"TaskStatus" = @{
		"Index"          = 0
		"Successful"     = 0
		"Unsuccessful"   = 0
		"TotalProcessed" = 0
	}
}

$Package += @{
	"Notification" = @{
		"Header" = "Installed '" + $Package.Name + "' package!"
		"Footer" = "Questions or concerns? Contact your system administrator for more information."
	}
}

# ---- FUNCTIONS ----

function pass {

	<#
		A simple placeholder, borrowed from Python, whose sole purpose is to do away with "{}" and
		improve readability when reviewing conditionals.
	#>
}

function Show-BalloonTip {

	[CmdletBinding(SupportsShouldProcess = $True)]
	Param (
		[Parameter(Mandatory = $True)]
		$Title,
			
		[Parameter(Mandatory = $False)]
		$Text = " ",

		[ValidateSet("None", "Info", "Warning", "Error")]
		$Icon = "Info",

		$Timeout = 10000
	)

	$Script:Balloon -eq $null

	Add-Type -AssemblyName System.Windows.Forms

	if ($Script:Balloon -eq $Null) {
		$Script:Balloon = New-Object System.Windows.Forms.NotifyIcon
	}

	$Path                    = Get-Process -id $PID | Select-Object -ExpandProperty Path
	$Balloon.Icon            = [System.Drawing.Icon]::ExtractAssociatedIcon($Path)
	$Balloon.BalloonTipIcon  = $Icon
	$Balloon.BalloonTipText  = $Text
	$Balloon.BalloonTipTitle = $Title
	$Balloon.Visible         = $True

	$Balloon.ShowBalloonTip($Timeout)
}

function Show-DialogBox {

	Param (
		[String]
		$Title,
		
		[String]
		$Message
	)
	
	$Wscript = New-Object -ComObject Wscript.Shell
	$Wscript.Popup($Message, 0, $Title, 0x0)
}

function Write-Result {

	Param (
		[String]
		$Code = "",
		
		[String]
		$Output,
		
		[String]
		$Status
	)
	
	[String]$Result = ""

	if ($Output -notmatch "^$") {
		$Result += ($Output + "`n`n")
	}
	
	else {}
	
	if ($Code -notmatch "^$") {
		$Code = ": (" + $Code + ")"
	}
	
	$Result += ($Status + $Code + "`n`n----")
	
	return $Result
}

# ---- IMPORTATION OF SCRIPT CONFIGURATION FILE ----

if (Test-Path $Script.Config.FilePath) {
	try {
		$Script.Config.Content = (Import-CSV $Script.Config.FilePath -Delimiter " " -Header "Type", "Value")
	}

	catch [Exception] {
		$Script.Config.Content = $Null
	}
	
	foreach ($Type in $Script.Config.Content | % {$_.Type}) {
		$Value = ($Script.Config.Content | ? {$_.Type -eq $Type} | % {$_.Value})
		
		if ($Type -eq "BlockHost") {
			if ($Value -notmatch "^$") {
				$Script.Config.BlockHost = $Value -split ","
				$Script.Config.TotalImported++
			}
			
			else {
				continue
			}
		}
		
		elseif ($Type -eq "PackageName") {
			if ($Value -notmatch "^$") {
				$Package.Name = $Value
				$Script.Config.TotalImported++
			}
			
			else {
				continue
			}
		}
		
		elseif ($Type -eq "SuppressNotification") {
			if ($Value -eq $True) {
				$Script.Config.SuppressNotification = $True
				$Script.Config.TotalImported++
			}
			
			elseif ($Value -eq $False) {
				$Script.Config.SuppressNotification = $False
				$Script.Config.TotalImported++
			}
			
			else {
				continue
			}
		}
		
		else {
			continue
		}
	}
}

else {
	pass
}

if ($Script.Config.TotalImported -gt 0) {
	$Script.Config.ImportState = $True
}

else {
	$Script.Config.ImportState = $False
}

# ---- HOST BLOCK PROCESSING ----

foreach ($ImportedHostname in $Script.Config.BlockHost) {
	if ($Machine.Hostname -match $ImportedHostname -and $ImportedHostname -notmatch "^$") {
		Write-Host -ForegroundColor Red ("`nERROR: Package '" + $Package.Name + "' will not be processed, as this host is blocked.`n")
		
		exit(4)
	}
	
	else {
		pass
	}
}

# ---- IMPORTATION OF PACKAGE FILE ----

try {
	if ($Script.CurrentPSVersion -ge 3) {
		$Package.Config.FilePath = $Package.Config.FilePath_JSON
		$Package.Config.FilePath = (Get-Content $Package.Config.FilePath | Out-String | ConvertFrom-JSON)
	}
	
	else {
		$Package.Config.FilePath = $Package.Config.FilePath_CSV
		$Package.Config.FilePath = (Import-CSV $Package.Config.FilePath)
	}
}

catch [Exception] {
	Write-Host -ForegroundColor Red ("`nERROR: Package file """ + $Package.Config.FilePath + """ could not be imported. Details: " + $Error[0])
	
	exit(5)
}

# ---- PACKAGE FILE PROCESSING ----

Write-Host -ForegroundColor Cyan (
	"`nInitiating Package (" + $Package.Name + "):`n"                              + `
	"`nHost                       : " + $Machine.Hostname                          + `
	"`nOperating System (Windows) : " + $Machine.OSVersion                         + `
	"`nInstruction Set            : " + $Machine.InstructionSet                    + `
	"`nUser                       : " + $Machine.Username + "`n"                   + `
	"`n----`n"                                                                     + `
	"`nConfiguration Importation  : " + $Script.Config.ImportState                 + `
	"`nSuppress Notification      : " + $Script.Config.SuppressNotification + "`n" + `
	"`n----"
)

foreach ($Row in $Package.Config.FilePath) {
	try {
		$TaskEntry = @{
			"TaskName"         = $Row.TaskName
			"Executable"       = @{
				"ExitCode" = 0
				"Path"     = $Row.Executable
			}
			"OperatingSystem"  = $Row.OperatingSystem
			"InstructionSet"   = $Row.InstructionSet
			"TerminateProcess" = $Row.TerminateProcess
			"TerminateMessage" = @{
				"Prompt"          = $Row.TerminateMessage
				"AlreadyPrompted" = $False # Ensures to only display TerminateMessage prompt once, if terminating more than one process.
			}
			"VerifyInstall"    = @{
				"Path"         = $Row.VerifyInstall
				"VersionBuild" = @{
					"Specified"  = 0
					"Discovered" = 0
				}
				"Existence"    = 0
			}
			"SuccessExitCode"  = $Row.SuccessExitCode
			"ContinueIfFail"   = $Row.ContinueIfFail
		}

		if ($TaskEntry.TaskName -match "^#") {
			continue
		}

		elseif ($TaskEntry.TaskName -match "^$") {
			continue
		}

		else {
			pass
		}
	}
	
	catch [Exception] {
		$Script.Output = ("Task Entry (" + $TaskEntry.TaskName + "): " + $Error[0])
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 3 -Output $Script.Output)
		
		$Script.ExitCode = 3
		break
	}
	
	# ---- TASK NAME COLUMN ----
	
	if ($TaskEntry.TaskName -match "^$") {
		$Script.Output = ("TaskName: Specification is required for """ + $TaskEntry.Executable + """ at entry " + [String]$Package.TaskStatus.Index + ".")
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output)
		
		$Script.ExitCode = 7
		break
	}
	
	elseif ($TaskEntry.TaskName -match "^\#") { # Allows for skipping tasks for the sole purpose of package testing.
		continue
	}
	
	else {
		pass
	}
	
	# ---- EXECUTABLE COLUMN ----
	
	$Package.TaskStatus.Index = $Package.TaskStatus.Index + 1
	
	if ($TaskEntry.Executable.Path -match "^$") {
		$Script.Output = ("Executable: Specification is required for """ + $TaskEntry.TaskName + """ at entry " + [String]$Package.TaskStatus.Index + ".")
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output)
		
		$Script.ExitCode = 7
		break
	}

	elseif ($TaskEntry.Executable.Path -match $Package.Syntax.Executable.LocalFile) {
		$TaskEntry.Executable.Path = $TaskEntry.Executable.Path -Replace ($Package.Syntax.Executable.LocalFile, $Script.CurrentDirectory)
	}
	
	else {
		pass
	}

	# The following loop prevents the execution of arbitrary commands.
	
	foreach ($Item in $Package.Syntax.Executable.Sanitizer) {
		$TaskEntry.Executable.Path = $TaskEntry.Executable.Path -replace ($Item, "")
	}

	Write-Host -NoNewLine ("`n(" + $Package.TaskStatus.Index + ") Invoking Command (" + $TaskEntry.TaskName + "): ")
	Write-Host -ForegroundColor Cyan ("`n[" + $TaskEntry.Executable.Path + "]`n")
	
	# ---- OPERATING SYSTEM COLUMN ----
	
	if ($TaskEntry.OperatingSystem -match "^$") {
		pass
	}
	
	elseif ($Machine.OSVersion -match $TaskEntry.OperatingSystem) {
		pass
	}
	
	else {
		$Script.Output = ("OperatingSystem: It is """ + $Machine.OSVersion + """ and not """ + $TaskEntry.OperatingSystem + """.")

		Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
		continue
	}
	
	# ---- INSTRUCTION SET COLUMN ----
	
	if ($TaskEntry.InstructionSet -match "^$") {
		pass
	}

	elseif ($TaskEntry.InstructionSet -match $Machine.InstructionSet) {
		pass
	}
	
	else {
		$Script.Output = ("InstructionSet: Operating system based on """ + $Machine.InstructionSet + """ and not """ + $TaskEntry.InstructionSet + """.")

		Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
		continue
	}
	
	# ---- INSTALL VERIFICATION COLUMN ----
	
	if ($TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Type_Hotfix) {
		$TaskEntry.VerifyInstall.Path      = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Type_Hotfix, "")
		$TaskEntry.VerifyInstall.Existence = Get-Hotfix | ? {$_.HotfixID -eq $TaskEntry.VerifyInstall.Path}

		if ($TaskEntry.VerifyInstall.Existence -ne $Null) {
			Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output ("VerifyInstall: [Hotfix] """ + $TaskEntry.VerifyInstall.Path + """ exists."))
			continue
		}

		else {
			pass
		}
	}
	
	elseif ($TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Type_Path) {
		$TaskEntry.VerifyInstall.Path      = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Type_Path, "")
		$TaskEntry.VerifyInstall.Existence = Test-Path $TaskEntry.VerifyInstall.Path

		if ($TaskEntry.VerifyInstall.Existence -eq $True) {
			Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output ("VerifyInstall: [Path] """ + $TaskEntry.VerifyInstall.Path + """ exists."))
			continue
		}

		else {
			pass
		}
	}

	elseif ($TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Type_Version_FileInfo) {
		$TaskEntry.VerifyInstall.Path = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Type_Version_FileInfo, "")

		try {
			$TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Arg_Build | Out-Null

			$TaskEntry.VerifyInstall.Path                    = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Arg_Build, "")
			$TaskEntry.VerifyInstall.VersionBuild.Specified  = $Matches[1]
			$TaskEntry.VerifyInstall.VersionBuild.Discovered = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall.Path) | % {$_.FileVersion}

			if ($TaskEntry.VerifyInstall.VersionBuild.Specified -eq $TaskEntry.VerifyInstall.VersionBuild.Discovered) {
				$Script.Output = ("VerifyInstall: [Vers_File] """ + $TaskEntry.VerifyInstall.VersionBuild.Specified + """ exists.")

				Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
				continue
			}
			
			else {
				throw
			} 
		}

		catch [Exception] {
			pass
		}
	}

	elseif ($TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Type_Version_ProductInfo) {
		$TaskEntry.VerifyInstall.Path = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Type_Version_ProductInfo, "")

		try {
			$TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Arg_Build | Out-Null

			$TaskEntry.VerifyInstall.Path                    = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Arg_Build, "")
			$TaskEntry.VerifyInstall.VersionBuild.Specified  = $Matches[1]
			$TaskEntry.VerifyInstall.VersionBuild.Discovered = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall.Path) | % {$_.ProductVersion}

			if ($TaskEntry.VerifyInstall.VersionBuild.Specified -eq $TaskEntry.VerifyInstall.VersionBuild.Discovered) {
				$Script.Output = ("VerifyInstall: [Vers_Product] """ + $TaskEntry.VerifyInstall.VersionBuild.Specified + """ exists.")

				Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
				continue
			}
			
			else {
				throw
			} 
		}

		catch [Exception] {
			pass
		}
	}
	
	elseif ($TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Type_Program) {
		$TaskEntry.VerifyInstall.Path = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Type_Program, "")

		try {
			if ($TaskEntry.VerifyInstall.Path -notmatch $Package.Syntax.VerifyInstall.Arg_Build) {
				$TaskEntry.VerifyInstall.VersionBuild.Discovered = $Machine.ProgramList | ? {$_.DisplayName -eq $TaskEntry.VerifyInstall.Path} | % {$_.DisplayName}
				
				if ($TaskEntry.VerifyInstall.Path -eq $TaskEntry.VerifyInstall.VersionBuild.Discovered) {
					$Script.Output = ("VerifyInstall: [Program] Name """ + $TaskEntry.VerifyInstall.Path + """ exists.")

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
					continue
				}
				
				else {
					throw
				}
			}
			
			else {
				$TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Arg_Build | Out-Null
				$TaskEntry.VerifyInstall.Path                    = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Arg_Build, "")
				$TaskEntry.VerifyInstall.VersionBuild.Specified  = $Matches[1]
			
				$TaskEntry.VerifyInstall.VersionBuild.Discovered = $Machine.ProgramList | ? {$_.DisplayName -eq $TaskEntry.VerifyInstall.Path} | % {$_.DisplayVersion}
				
				if ($TaskEntry.VerifyInstall.VersionBuild.Specified -eq $TaskEntry.VerifyInstall.VersionBuild.Discovered) {
					$Script.Output = ("VerifyInstall: [Program] Build """ + $TaskEntry.VerifyInstall.VersionBuild.Specified + """ exists.")

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
					continue
				}
				
				else {
					throw
				}
			}
		}

		catch [Exception] {
			pass
		}
	}

	else {
		pass
	}

	# ---- PROCESS TERMINATION COLUMNS ----
	
	if ($TaskEntry.TerminateProcess -notmatch "^$") {
		$TaskEntry.TerminateProcess = $TaskEntry.TerminateProcess -split ","
		
		foreach ($Process in $TaskEntry.TerminateProcess) {
			try {
				$RunningProcess = Get-Process $Process
			
				if ($RunningProcess) {
					if ($TaskEntry.TerminateMessage.Prompt -notmatch "^$" -and $TaskEntry.TerminateMessage.AlreadyPrompted -eq $False) {
						Show-DialogBox -Title $Package.Name -Message $TaskEntry.TerminateMessage.Prompt | Out-Null
						$TaskEntry.TerminateMessage.AlreadyPrompted = $True
					}

					else {
						pass
					}

					Get-Process $Process | Stop-Process -Force
				}

				else {
					continue
				}
			}
			
			catch [Exception] {
				continue
			}
		}
	}

	else {
		pass
	}

	# ---- SUCCESS EXIT CODE COLUMN ----
	
	if ($TaskEntry.SuccessExitCode -eq $Null) {
		$TaskEntry.SuccessExitCode = 0
	}
	
	else {
		$TaskEntry.SuccessExitCode  = $TaskEntry.SuccessExitCode -split ","
		$TaskEntry.SuccessExitCode += 0
	}
	
	# ---- INVOCATION PROCESS ----
	
	try {
		# Prevents the Command Prompt from outputting an error regarding the usage of a UNC path as a startup path.
		Push-Location $Machine.SystemDrive
		
		$Script.Output = (& "cmd.exe" /c $TaskEntry.Executable.Path 2>&1)
		$TaskEntry.Executable.ExitCode = $LastExitCode
		
		if ($TaskEntry.SuccessExitCode -contains $TaskEntry.Executable.ExitCode) {
			Write-Host -ForegroundColor Green (Write-Result -Status "OK" -Code $TaskEntry.Executable.ExitCode -Output $Script.Output)
			$Package.TaskStatus.Successful++
		}
	
		else {
			Write-Host -ForegroundColor Red (Write-Result -Status "WARN" -Code $TaskEntry.Executable.ExitCode -Output $Script.Output)
			
			$Script.ExitCode                  = 1
			$Package.TaskStatus.Unsuccessful += 1
			
			if ($TaskEntry.ContinueIfFail -ne "true") {
				break
			}
			
			else {
				pass
			}
		}
	}
	
	catch [Exception] {
		$Script.Output = ("Executable Invocation: " + $Error[0])
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 2 -Output $Script.Output)
		
		$Script.ExitCode                  = 2
		$Package.TaskStatus.Unsuccessful += 1
		continue
	}
	
	finally {
		Pop-Location
	}
}

<#

	Insert custom code within this segment of the script.

#>

# ---- TASK STATUS REPORTING ---

if ($Script.ExitCode -eq 0 -and $Package.TaskStatus.Successful -eq 0) {
	Write-Host -ForegroundColor Red "`nWARN: No task entries were processed.`n"
	
	$Script.ExitCode = 6
}

else {
	$Package.TaskStatus.TotalProcessed = [Int32]$Package.TaskStatus.Successful + [Int32]$Package.TaskStatus.Unsuccessful

	$Package.Result = (
		"`nTasks Processed : " + $Package.TaskStatus.TotalProcessed + `
		"`n  ^"                                                     + `
		"`n  |"                                                     + `
		"`n  |---- Success : " + $Package.TaskStatus.Successful     + `
		"`n  +---- Failure : " + $Package.TaskStatus.Unsuccessful   + `
		"`n"
	)

	Write-Host ("`nPackage Results (" + $Package.Name + "):")

	if ($Script.ExitCode -eq 0 -and $Package.TaskStatus.Unsuccessful -eq 0) {
		$Package.Result += ("`nOK: (" + $Script.ExitCode + ")`n")
		
		Write-Host -ForegroundColor Green $Package.Result
		
		if ($Script.Config.SuppressNotification -eq $False) {
			Show-BalloonTip -Title $Package.Notification.Header -Text $Package.Notification.Footer | Out-Null
		}

		else {
			pass
		}
	}

	else {
		$Package.Result += ("`nERROR: (" + $Script.ExitCode + ")`n")

		Write-Host -ForegroundColor Red $Package.Result
	}
}

exit($Script.ExitCode)
