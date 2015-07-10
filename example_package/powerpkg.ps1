
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
	"UserspaceArchitecture" = [System.Environment]::GetEnvironmentVariable("Processor_Architecture")
	"OSVersion"             = [System.Environment]::OSVersion.Version.ToString()
	"Hostname"              = [System.Environment]::GetEnvironmentVariable("ComputerName")
	"Username"              = [System.Environment]::GetEnvironmentVariable("Username")
	"ProgramList"           = @(
		"HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
		"HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
	)
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
			"Type_Program"             = "^(\[)Program(\])"      # [Program]<Program Name/Product Code>[Build:<Version Build>] OR [Program]<Program Name/Product Code>]
		}
	}
	"TaskStatus" = @{
		"Index"                   = 0
		"Successful"              = 0
		"Unsuccessful"            = 0
		"TotalProcessed"          = 0
		"TotalFailedButContinued" = 0
	}
}

# ---- FUNCTIONS ----

function Invoke-Executable {

	Param (
		[Parameter(Mandatory = $True)]
		[String]
		$Path
	)
	
	$Invocation = @{
		"Input"      = $Path
		"Executable" = @{
			"Value"    = $Null
			"Quoted"   = "^(\"")(.*)(\"")"
			"Unquoted" = "^(\S+)"
		}
		"Arguments"  = @{
			"Value"              = $Null
			"LeftwardWhitespace" = "^(\s+)(.*)"
		}
	}

	# Split executable and its arguments.
	
	if ($Invocation.Input -match $Invocation.Executable.Quoted) {
		$Invocation.Executable.Value = $Invocation.Input -match $Invocation.Executable.Quoted
		$Invocation.Executable.Value = $Matches[2]
		$Invocation.Arguments.Value  = $Invocation.Input -replace ($Invocation.Executable.Quoted, "")
	}

	else {
		$Invocation.Executable.Value = $Invocation.Input -match $Invocation.Executable.Unquoted
		$Invocation.Executable.Value = $Matches[1]
		$Invocation.Arguments.Value  = $Invocation.Input -replace ($Invocation.Executable.Unquoted, "")
	}
	
	# Remove potential whitespace between executable and its arguments.
	
	if ($Invocation.Arguments.Value -match $Invocation.Arguments.LeftwardWhitespace) {
		$Invocation.Arguments.Value = $Invocation.Arguments.Value -match $Invocation.Arguments.LeftwardWhitespace
		$Invocation.Arguments.Value = $Matches[2]
	}
	
	else {}
	
	try {
		$ProcessStartInfo                        = New-Object System.Diagnostics.ProcessStartInfo
		$ProcessStartInfo.FileName               = $Invocation.Executable.Value
		$ProcessStartInfo.RedirectStandardError  = $True
		$ProcessStartInfo.RedirectStandardOutput = $True
		$ProcessStartInfo.UseShellExecute        = $False
		$ProcessStartInfo.Arguments              = $Invocation.Arguments.Value
		
		$Process           = New-Object System.Diagnostics.Process
		$Process.StartInfo = $ProcessStartInfo
		$Process.Start() | Out-Null
		$Process.WaitForExit()

		$Result = New-Object PSObject -Property @{
			"ExitCode" = $Process.ExitCode
			"Output"   = $Process.StandardOutput.ReadToEnd()
		}
		
		return $Result
	}

	catch [Exception] {
		throw
	}
}

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
		$Status,
		
		[Switch]
		$AddNewLine
	)
	
	[String]$Result = ""

	if ($Output -notmatch "^$") {
		if ($AddNewLine) {
			$Result += ($Output + "`n`n")
		}
		
		else {
			$Result += ($Output + "`n")
		}
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
				$Script.Config.BlockHost = $Value -split (",")
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

# ---- CREATION OF NOTIFICATION DETAILS ----

$Package += @{
	"Notification" = @{
		"Header" = "Installed '" + $Package.Name + "' package!"
		"Footer" = "Questions or concerns? Contact your system administrator for more information."
	}

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
	"`nUserspace Architecture     : " + $Machine.UserspaceArchitecture             + `
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
				"Result" = $Null
				"Path"   = $Row.Executable
			}
			"OperatingSystem"  = $Row.OperatingSystem
			"Architecture"     = $Row.Architecture
			"TerminateProcess" = $Row.TerminateProcess
			"TerminateMessage" = @{
				"Prompt"          = $Row.TerminateMessage
				"AlreadyPrompted" = $False # Ensures to only display TerminateMessage prompt once, if terminating more than one process.
			}
			"VerifyInstall"    = @{
				"Path"             = $Row.VerifyInstall
				"SpecifiedBuild"   = 0
				"DiscoveredBuild"  = 0
				"Existence"        = $Null
				"ProgramReference" = $Null
			}
			"SuccessExitCode"  = $Row.SuccessExitCode
			"ContinueIfFail"   = $Row.ContinueIfFail
			"SkipProcessCount" = $Row.SkipProcessCount
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
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 3 -Output $Script.Output -AddNewLine)
		
		$Script.ExitCode = 3
		break
	}
	
	# ---- TASK NAME COLUMN ----
	
	if ($TaskEntry.TaskName -match "^$") {
		$Script.Output = ("TaskName: Specification is required for """ + $TaskEntry.Executable + """ at entry " + [String]$Package.TaskStatus.Index + ".")
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output -AddNewLine)
		
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
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output -AddNewLine)
		
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

	Write-Host -NoNewLine ("`n(" + $Package.TaskStatus.Index + ") " + $TaskEntry.TaskName + ": ")
	Write-Host -ForegroundColor Cyan ("`n[" + $TaskEntry.Executable.Path + "]`n")
	
	# ---- OPERATING SYSTEM COLUMN ----
	
	if ($TaskEntry.OperatingSystem -match "^$") {
		pass
	}
	
	elseif ($Machine.OSVersion -match $TaskEntry.OperatingSystem) {
		pass
	}
	
	else {
		$Script.Output = ("OperatingSystem: """ + $TaskEntry.OperatingSystem + """ is a requirement.")

		Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
		continue
	}
	
	# ---- ARCHITECTURE COLUMN ----
	
	if ($TaskEntry.Architecture -match "^$") {
		pass
	}

	elseif ($TaskEntry.Architecture -match $Machine.UserspaceArchitecture) {
		pass
	}
	
	else {
		$Script.Output = ("Architecture: """ + $TaskEntry.Architecture + """ is a requirement.")

		Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
		continue
	}
	
	# ---- INSTALL VERIFICATION COLUMN ----
	
	if ($TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Type_Hotfix) {
		$TaskEntry.VerifyInstall.Path      = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Type_Hotfix, "")
		$TaskEntry.VerifyInstall.Existence = Get-Hotfix | ? {$_.HotfixID -eq $TaskEntry.VerifyInstall.Path}

		if ($TaskEntry.VerifyInstall.Existence -ne $Null) {
			Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output ("VerifyInstall: [Hotfix] """ + $TaskEntry.VerifyInstall.Path + """ exists.") -AddNewLine)
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
			Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output ("VerifyInstall: [Path] """ + $TaskEntry.VerifyInstall.Path + """ exists.") -AddNewLine)
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

			$TaskEntry.VerifyInstall.Path            = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Arg_Build, "")
			$TaskEntry.VerifyInstall.SpecifiedBuild  = $Matches[1]
			$TaskEntry.VerifyInstall.DiscoveredBuild = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall.Path) | % {$_.FileVersion}

			if ($TaskEntry.VerifyInstall.SpecifiedBuild -eq $TaskEntry.VerifyInstall.DiscoveredBuild) {
				$Script.Output = ("VerifyInstall: [Vers_File] """ + $TaskEntry.VerifyInstall.SpecifiedBuild + """ exists.")

				Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
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

			$TaskEntry.VerifyInstall.Path            = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Arg_Build, "")
			$TaskEntry.VerifyInstall.SpecifiedBuild  = $Matches[1]
			$TaskEntry.VerifyInstall.DiscoveredBuild = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall.Path) | % {$_.ProductVersion}

			if ($TaskEntry.VerifyInstall.SpecifiedBuild -eq $TaskEntry.VerifyInstall.DiscoveredBuild) {
				$Script.Output = ("VerifyInstall: [Vers_Product] """ + $TaskEntry.VerifyInstall.SpecifiedBuild + """ exists.")

				Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
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
				if ($TaskEntry.VerifyInstall.Path -match "^\{(.*)\}$") {
					$TaskEntry.VerifyInstall.ProgramReference = "PSChildName"
				}

				else {
					$TaskEntry.VerifyInstall.ProgramReference = "DisplayName"
				}

				foreach ($Path in $Machine.ProgramList) {
					if (Test-Path $Path) {
						$TaskEntry.VerifyInstall.Existence = @(
							Get-ChildItem $Path | % {Get-ItemProperty $_.PSPath} | ? {$_.$($TaskEntry.VerifyInstall.ProgramReference) -eq $TaskEntry.VerifyInstall.Path} | % {$_.DisplayName}
						)
					}

					else {
						pass
					}
				}
				
				if ($TaskEntry.VerifyInstall.Existence -ne $Null) {
					$Script.Output = ("VerifyInstall: [Program] """ + $TaskEntry.VerifyInstall.Path + """ exists.")

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
					continue
				}
				
				else {
					throw
				}
			}
			
			else {
				$TaskEntry.VerifyInstall.Path -match $Package.Syntax.VerifyInstall.Arg_Build | Out-Null
				$TaskEntry.VerifyInstall.Path           = $TaskEntry.VerifyInstall.Path -replace ($Package.Syntax.VerifyInstall.Arg_Build, "")
				$TaskEntry.VerifyInstall.SpecifiedBuild = $Matches[1]

				if ($TaskEntry.VerifyInstall.Path -match "^\{(.*)\}$") {
					$TaskEntry.VerifyInstall.ProgramReference = "PSChildName"
				}

				else {
					$TaskEntry.VerifyInstall.ProgramReference = "DisplayName"
				}

				foreach ($Path in $Machine.ProgramList) {
					if (Test-Path $Path) {
						$TaskEntry.VerifyInstall.DiscoveredBuild = @(
							Get-ChildItem $Path | % {Get-ItemProperty $_.PSPath} | ? {$_.$($TaskEntry.VerifyInstall.ProgramReference) -eq $TaskEntry.VerifyInstall.Path} | % {$_.DisplayVersion}
						)
					}

					else {
						pass
					}
				}

				if ($TaskEntry.VerifyInstall.DiscoveredBuild -contains $TaskEntry.VerifyInstall.SpecifiedBuild) {
					$Script.Output = ("VerifyInstall: [Program] """ + $TaskEntry.VerifyInstall.SpecifiedBuild + """ exists.")

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
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
		$TaskEntry.TerminateProcess = $TaskEntry.TerminateProcess -split (",")
		
		foreach ($Process in $TaskEntry.TerminateProcess) {
			try {
				if (Get-Process $Process) {
					pass
				}

				else {
					continue
				}
				
				if ($TaskEntry.TerminateMessage.Prompt -notmatch "^$" -and $TaskEntry.TerminateMessage.AlreadyPrompted -eq $False) {
					Show-DialogBox -Title $Package.Name -Message $TaskEntry.TerminateMessage.Prompt | Out-Null
					$TaskEntry.TerminateMessage.AlreadyPrompted = $True
				}

				else {
					pass
				}

				Get-Process $Process | Stop-Process -Force
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
		$TaskEntry.SuccessExitCode  = $TaskEntry.SuccessExitCode -split (",")
		$TaskEntry.SuccessExitCode += 0
	}
	
	# ---- INVOCATION PROCESS ----
	
	try {
		$TaskEntry.Executable.Result = (Invoke-Executable -Path $TaskEntry.Executable.Path)
		
		if ($TaskEntry.SuccessExitCode -contains $TaskEntry.Executable.Result.ExitCode) {
			Write-Host -ForegroundColor Green (Write-Result -Status "OK" -Code $TaskEntry.Executable.Result.ExitCode -Output $TaskEntry.Executable.Result.Output)
			
			if ($TaskEntry.SkipProcessCount -ne "true") {
				$Package.TaskStatus.Successful++
			}
			
			else {
				continue
			}
		}
	
		else {
			Write-Host -ForegroundColor Red (Write-Result -Status "WARN" -Code $TaskEntry.Executable.Result.ExitCode -Output $TaskEntry.Executable.Result.Output)
			
			if ($TaskEntry.SkipProcessCount -ne "true") {
				$Package.TaskStatus.Unsuccessful++
			}
			
			else {
				pass
			}
			
			if ($TaskEntry.ContinueIfFail -ne "true") {
				$Script.ExitCode = 1
				break
			}
			
			else {
				$Package.TaskStatus.TotalFailedButContinued++
				continue
			}
		}
	}
	
	catch [Exception] {
		$Script.Output = ("Executable Invocation: " + $Error[0])
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 2 -Output $Script.Output -AddNewLine)
		
		if ($TaskEntry.SkipProcessCount -ne "true") {
			$Package.TaskStatus.Unsuccessful++
		}
		
		else {
			pass
		}
		
		if ($TaskEntry.ContinueIfFail -ne "true") {
			$Script.ExitCode = 2
			break
		}
		
		else {
			$Package.TaskStatus.TotalFailedButContinued++
			continue
		}
	}
}

# ---- TASK STATUS REPORTING ---

if ($Script.ExitCode -eq 0 -and $Package.TaskStatus.Successful -eq 0 -and $Package.TaskStatus.Unsuccessful -eq 0) {
	Write-Host -ForegroundColor Red "`nWARN: No task entries were processed.`n"
	
	$Script.ExitCode = 6
}

else {
	$Package.TaskStatus.TotalProcessed = [Int]$Package.TaskStatus.Successful + [Int]$Package.TaskStatus.Unsuccessful

	$Package.Result = (
		"`nTasks Processed : " + $Package.TaskStatus.TotalProcessed + `
		"`n  ^"                                                     + `
		"`n  |"                                                     + `
		"`n  |---- Success : " + $Package.TaskStatus.Successful     + `
		"`n  +---- Failure : " + $Package.TaskStatus.Unsuccessful   + `
		"`n"
	)

	Write-Host ("`nPackage Results (" + $Package.Name + "):")

	if ($Script.ExitCode -eq 0 -and $Package.TaskStatus.Unsuccessful -eq 0 -or $Package.TaskStatus.TotalFailedButContinued -gt 0) {
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
