
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

$Script                = @{
	"CurrentDirectory" = (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition) + "\"
	"ExitCode"         = 0
	"Output"           = ""
}

$Machine               = @{
	"InstructionSet" = [System.Environment]::GetEnvironmentVariable("Processor_Architecture")
	"OSVersion"      = [System.Environment]::OSVersion.Version.ToString()
	"Hostname"       = [System.Environment]::GetEnvironmentVariable("ComputerName")
	"Username"       = [System.Environment]::GetEnvironmentVariable("Username")
	"SystemDrive"    = [System.Environment]::GetEnvironmentVariable("SystemDrive")
}

$Package               = @{
	"Name"                    = $MyInvocation.MyCommand.Definition.Split("\")[-2]
	"Blacklist"               = @{
		"Content"  = @{}
		"FilePath" = $Script.CurrentDirectory + "blacklist.conf"
	}
	"Result"                  = @()
	"SuccessfulInstallPrompt" = @{
		"Header" = "Installed '" + $Package.Name + "' package!"
		"Footer" = "Questions or concerns? Contact your system administrator for more information."
	}
	"Task"                    = @{
		"Successful"     = 0
		"Unsuccessful"   = 0
		"TotalProcessed" = 0
	}
	"TaskEntries"             = $Script.CurrentDirectory + "package.json"
}

$TaskConfig            = @{
	"EntryIndex" = 0
	"Syntax"     = @{
		"Executable"    = @{
			"LocalFile" = "^(\[)LocalFile(\])"
		}
		"VerifyInstall" = @{                                         # SYNTAX:
			"Arg_Build"                = "\[Build:(.*)\]$"       # [Build:<Version Build>] (Used in conjunction with "Type_Version_FileInfo" and "Type_Version_ProductInfo". See below.)
			"Type_Path"                = "^(\[)Path(\])"         # [Path]<File/Directory Path>
			"Type_Version_FileInfo"    = "^(\[)Vers_File(\])"    # [Vers_File]<File Path>[Build:<Version Build>]
			"Type_Version_ProductInfo" = "^(\[)Vers_Product(\])" # [Vers_Product]<File Path>[Build:<Version Build>]
		}
	}
}


# ---- FUNCTIONS ----

function pass {

	# A simple placeholder, borrowed from Python, used for improving readability and doing away with "{}" when using conditionals.
}

function Show-BalloonTip {

	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Parameter(Mandatory = $True)]
		$Title,
			
		[Parameter(Mandatory = $False)]
		$Text = " ",

		[ValidateSet('None', 'Info', 'Warning', 'Error')]
		$Icon = 'Info',

		$Timeout = 10000
	)

	$Script:Balloon -eq $null

	Add-Type -AssemblyName System.Windows.Forms

	if ($Script:Balloon -eq $null) {
		$Script:Balloon = New-Object System.Windows.Forms.NotifyIcon
	}

	$Path                    = Get-Process -id $pid | Select-Object -ExpandProperty Path
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

# ---- IMPORTATION OF BLACKLIST ----

try {
	$Package.Blacklist.Content = (Get-Content $Package.Blacklist.FilePath)

	foreach ($Hostname in $Package.Blacklist.Content) {
		if ($Hostname -match "^#") {
			continue
		}

		elseif ($Hostname -match "^$") {
			continue
		}

		elseif ($Hostname -match "^(\s)") {
			continue
		}

		elseif ($Hostname -match $Machine.Hostname) {
			Write-Output ("`nERROR: Package '" + $Package.Name + "' will not be processed on this machine, as it is blacklisted.")
			exit(4)
		}
		
		else {
			pass
		}
	}
}

catch [Exception] {
	Write-Output ("`nERROR: Blacklist could not be imported. Details: " + $Error[0])
	exit(3)
}

# ---- IMPORTATION OF PACKAGE FILE ----

try {
	$Package.TaskEntries = (Get-Content $Package.TaskEntries | Out-String | ConvertFrom-Json)
}

catch [Exception] {
	Write-Output ($Error[0])
	exit(5)
}

# ---- PACKAGE FILE PROCESSING ----

Write-Host -ForegroundColor Cyan (
	"`nInitiating Package (" + $Package.Name + "):`n" + `
	"`nHost                       : "   + $Machine.Hostname        + `
	"`nOperating System (Windows) : "   + $Machine.OSVersion       + `
	"`nInstruction Set            : "   + $Machine.InstructionSet  + `
	"`nUser                       : "   + $Machine.Username + "`n" + `
	"`n----"
)

foreach ($Row in $Package.TaskEntries) {
	try {
		$TaskEntry = @{

			# Data from the package file:

			"TaskName"         = $Row.TaskName
			"Executable"       = @{
				"ExitCode" = 0
				"Path"     = $Row.Executable
			}
			"InstructionSet"   = $Row.InstructionSet
			"TerminateProcess" = $Row.TerminateProcess
			"TerminateMessage" = $Row.TerminateMessage
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

		elseif ($TaskEntry.TaskName -match "^(\s)") {
			continue
		}

		else {
			pass
		}
	}
	
	catch [Exception] {
		$Script.Output = ("Initializaion of Task Entry (" + $TaskEntry.TaskName + "): " + $Error[0])
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 2 -Output $Script.Output)
		
		$Script.ExitCode = 2
		break
	}
	
	# ---- TASK NAME COLUMN ----
	
	if ($TaskEntry.TaskName -match "^$") {
		$Script.Output = ("'Name' is required for '" + $TaskEntry.Executable + "' at entry " + [String]$TaskConfig.EntryIndex + ".")
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output)
		
		$Script.ExitCode = 7
		break
	}
	
	else {
		pass
	}
	
	# ---- EXECUTABLE COLUMN ----
	
	$TaskConfig.EntryIndex = $TaskConfig.EntryIndex + 1
	
	if ($TaskEntry.Executable.Path -match "^$") {
		$Script.Output = ("'Executable' is required for '" + $TaskEntry.TaskName + "' at entry " + [String]$TaskConfig.EntryIndex + ".")
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output)
		
		$Script.ExitCode = 7
		break
	}

	elseif ($TaskEntry.Executable.Path -match $TaskConfig.Syntax.Executable.LocalFile) {
		$TaskEntry.Executable.Path = $TaskEntry.Executable.Path -Replace ($TaskConfig.Syntax.Executable.LocalFile, $Script.CurrentDirectory)
	}
	
	else {
		pass
	}

	Write-Host -NoNewLine ("`n(" + $TaskConfig.EntryIndex + ") Invoking Command (" + $TaskEntry.TaskName + "): ")
	Write-Host -ForegroundColor Cyan ("`n[" + $TaskEntry.Executable.Path + "]`n")
	
	# ---- INSTRUCTION SET COLUMN ----
	
	if ($TaskEntry.InstructionSet -match "^$") {
		pass
	}

	elseif ($TaskEntry.InstructionSet -match $Machine.InstructionSet) {
		pass
	}
	
	else {
		$Script.Output = ("Instruction Set Verification: This operating system is based on """ + $Machine.InstructionSet + """ and not """ + $TaskEntry.InstructionSet + """.")

		Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
		continue
	}
	
	# ---- PROCESS TERMINATION COLUMNS ----
	
	if ($TaskEntry.TerminateProcess -notmatch "^$") {
		$TaskEntry.TerminateProcess = $TaskEntry.TerminateProcess.Split(":")
		
		if ($TaskEntry.TerminateMessage -notmatch "^$") {
			Show-DialogBox -Title $Package.Name -Message $TaskEntry.TerminateMessage | Out-Null
		}

		else {
			pass
		}
	
		foreach ($Process in $TaskEntry.TerminateProcess) {
			try {
				$RunningProcess = Get-Process $Process
			
				if ($RunningProcess) {
					Get-Process $Process | Stop-Process -Force
				}

				else {
					pass
				}
			}
			
			catch [Exception] {
				pass	
			}
		}
	}

	# ---- INSTALL VERIFICATION COLUMN ----
	
	if ($TaskEntry.VerifyInstall.Path -notmatch "^$") {
		if ($TaskEntry.VerifyInstall.Path -match $TaskConfig.Syntax.VerifyInstall.Type_Path) {
			$TaskEntry.VerifyInstall.Path      = $TaskEntry.VerifyInstall.Path -replace ($TaskConfig.Syntax.VerifyInstall.Type_Path, "")
			$TaskEntry.VerifyInstall.Existence = Test-Path $TaskEntry.VerifyInstall.Path

			if ($TaskEntry.VerifyInstall.Existence -eq $True) {
				Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output ("Installation Verification: Path """ + $TaskEntry.VerifyInstall.Path + """ exists."))
				continue
			}

			else {
				pass
			}
		}

		elseif ($TaskEntry.VerifyInstall.Path -match $TaskConfig.Syntax.VerifyInstall.Type_Version_FileInfo) {
			$TaskEntry.VerifyInstall.Path = $TaskEntry.VerifyInstall.Path -replace ($TaskConfig.Syntax.VerifyInstall.Type_Version_FileInfo, "")

			try {
				$TaskEntry.VerifyInstall.Path -match $TaskConfig.Syntax.VerifyInstall.Arg_Build | Out-Null

				$TaskEntry.VerifyInstall.Path                    = $TaskEntry.VerifyInstall.Path -replace ($TaskConfig.Syntax.VerifyInstall.Arg_Build, "")
				$TaskEntry.VerifyInstall.VersionBuild.Specified  = $Matches[1]
				$TaskEntry.VerifyInstall.VersionBuild.Discovered = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall.Path).FileVersion

				if ($TaskEntry.VerifyInstall.VersionBuild.Specified -eq $TaskEntry.VerifyInstall.VersionBuild.Discovered) {
					$Script.Output = ("Installation Verification: File Version Build """ + $TaskEntry.VerifyInstall.VersionBuild.Specified + """ exists.")

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
					continue
				}
				
				else {
					pass
				} 
			}

			catch [Exception] {
				$Script.Output = ("Installation Verification: " + $Error[0])
				Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 2 -Output $Script.Output)
				
				$Script.ExitCode            = 2
				$Package.Task.Unsuccessful += 1
				continue
			}
		}

		elseif ($TaskEntry.VerifyInstall.Path -match $TaskConfig.Syntax.VerifyInstall.Type_Version_ProductInfo) {
			$TaskEntry.VerifyInstall.Path = $TaskEntry.VerifyInstall.Path -replace ($TaskConfig.Syntax.VerifyInstall.Type_Version_ProductInfo, "")

			try {
				$TaskEntry.VerifyInstall.Path -match $TaskConfig.Syntax.VerifyInstall.Arg_Build | Out-Null

				$TaskEntry.VerifyInstall.Path                    = $TaskEntry.VerifyInstall.Path -replace ($TaskConfig.Syntax.VerifyInstall.Arg_Build, "")
				$TaskEntry.VerifyInstall.VersionBuild.Specified  = $Matches[1]
				$TaskEntry.VerifyInstall.VersionBuild.Discovered = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall.Path).ProductVersion

				if ($TaskEntry.VerifyInstall.VersionBuild.Specified -eq $TaskEntry.VerifyInstall.VersionBuild.Discovered) {
					$Script.Output = ("Installation Verification: Product Version Build """ + $TaskEntry.VerifyInstall.VersionBuild.Specified + """ exists.")

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output)
					continue
				}
				
				else {
					pass
				} 
			}

			catch [Exception] {
				$Script.Output = ("Installation Verification: " + $Error[0])
				Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 2 -Output $Script.Output)
				
				$Script.ExitCode            = 2
				$Package.Task.Unsuccessful += 1
				continue
			}
		}

		else {
			pass
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
		$TaskEntry.SuccessExitCode  = $TaskEntry.SuccessExitCode.Split(":")
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
			$Package.Task.Successful++
		}
	
		else {
			Write-Host -ForegroundColor Red (Write-Result -Status "WARN" -Code $TaskEntry.Executable.ExitCode -Output $Script.Output)
			
			$Script.ExitCode            = 1
			$Package.Task.Unsuccessful += 1
			
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
		
		$Script.ExitCode            = 2
		$Package.Task.Unsuccessful += 1
		continue
	}
	
	finally {
		Pop-Location
	}
}

<#

	Insert custom code within this segment of the script.

#>

if ($Script.ExitCode -eq 0 -and $Package.Task.Successful -eq 0) {
	Write-Output ("`nWARN: No task entries were processed.")
	$Script.ExitCode = 6
}

else {
	$Package.Task.TotalProcessed = [Int32]$Package.Task.Successful + [Int32]$Package.Task.Unsuccessful

	$Package.Result = (
		"`nTasks Processed : " + $Package.Task.TotalProcessed + `
		"`n  ^"                                               + `
		"`n  |"                                               + `
		"`n  |---- Success : " + $Package.Task.Successful     + `
		"`n  +---- Failure : " + $Package.Task.Unsuccessful   + `
		"`n"
	)

	Write-Host ("`nPackage Results (" + $Package.Name + "):")

	if ($Script.ExitCode -eq 0 -and $Package.Task.Unsuccessful -eq 0) {
		$Package.Result += ("`nOK: (" + $Script.ExitCode + ")`n")

		Write-Host -ForegroundColor Green $Package.Result
		Show-BalloonTip -Title $Package.SuccessfulInstallPrompt.Header -Text $Package.SuccessfulInstallPrompt.Footer | Out-Null
	}

	else {
		$Package.Result += ("`nERROR: (" + $Script.ExitCode + ")`n")

		Write-Host -ForegroundColor Red $Package.Result
	}
}

exit($Script.ExitCode)

