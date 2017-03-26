
<#
	 ________  ________  ___       __   _______   ________  ________  ___  __    ________
	|\   __  \|\   __  \|\  \     |\  \|\  ___ \ |\   __  \|\   __  \|\  \|\  \ |\   ____\
	\ \  \|\  \ \  \|\  \ \  \    \ \  \ \   __/|\ \  \|\  \ \  \|\  \ \  \/  /|\ \  \___|
	 \ \   ____\ \  \\\  \ \  \  __\ \  \ \  \_|/_\ \   _  _\ \   ____\ \   ___  \ \  \  ___
	  \ \  \___|\ \  \\\  \ \  \|\__\_\  \ \  \_|\ \ \  \\  \\ \  \___|\ \  \\ \  \ \  \|\  \
	   \ \__\    \ \_______\ \____________\ \_______\ \__\\ _\\ \__\    \ \__\\ \__\ \_______\
	    \|__|     \|_______|\|____________|\|_______|\|__|\|__|\|__|     \|__| \|__|\|_______|


	.SYNOPSIS
	powerpkg: A monolithic Windows package deployment script with an emphasis on simplicity,
	maintainability, and standardization.

	.DESCRIPTION
	For information in regards to usage, consult the powerpkg README.md file.

	.NOTES
	The MIT License (MIT)

	Copyright (c) 2015-2017 Steven Peguero

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

# ---- PROPERTIES >>>>
#
# ... For the sole purpose of maintainability, this segment of the codebase was intentionally ...
# ... written to provide an overview of the various properties used throughout the codebase   ...
# ... in an organized and centralized fashion.                                                ...
# ...............................................................................................

$ErrorActionPreference = "Stop"

$Script = @{
	"Config" = @{
		"BlockHost"            = $Null
		"SuppressNotification" = $True
		"TotalImported"        = 0 # Retrieves number of imported package-specified script preferences.
		"ImportState"          = $Null # Reports whether or not package-specified script preferences were imported.
	}
	"CurrentDirectory"         = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	"CurrentPSVersion"         = $Host.Version.Major
	"ExitCode"                 = 0
	"Output"                   = $Null # Used for capturing and printing general output.
}

$Machine = @{
	"UserspaceArchitecture" = [System.Environment]::GetEnvironmentVariable("Processor_Architecture")
	"OSVersion"             = [System.Environment]::OSVersion.Version.ToString()
	"Hostname"              = [System.Environment]::GetEnvironmentVariable("ComputerName")
	"Username"              = [System.Environment]::GetEnvironmentVariable("Username")
	"ProgramList" = @(

	                          # Registry paths that contain list of MSI program codes and version builds of installed applications:

	                          "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", # x86 and AMD64 Programs
	                          "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" # x86 Programs (in AMD64 Userspace)
	)
}

$Package = @{
	"Name"                             = $MyInvocation.MyCommand.Definition.Split("\")[-2] # Name of directory this script is located in.
	"Content" = @{
		"All"                          = $Null
		"Configuration"                = $Null
		"TaskEntry"                    = $Null
	}
	"Path"                             = ("{0}\package.xml" -f $Script.CurrentDirectory)
	"Delimiter"                        = "," # Character used for separating individual values specified in task entires.
	"TaskEntryStatus" = @{
		"Index"                        = 0
		"Successful"                   = 0
		"Unsuccessful"                 = 0
		"TotalProcessed"               = 0
		"TotalFailedButContinued"      = 0
	}
	"TaskEntrySubparameterRegexp" = @{
		"Executable" = @{
			"Package"                  = "(\[)Package(\])" # Regexp that replaces matching string with path of package directory.
			"Sanitizer" = (
			                             # Regexps that remove arbitrary commands:

			                             "\;(.*)$",
			                             "\&(.*)$",
			                             "\|(.*)$",
			                             "(\s+)$"
			)
		}
		"VerifyInstall" = @{
			                             # NOTE:
			                             #
			                             # Arg_Build cannot parse uncommonly used, non-alphanumeric characters, such as commas, on
			                             # PowerShell 2.0. Upgrade to 3.0+ to circumvent this issue.

			"Arg_Build"                = "\[Build:(.*)\]$"
			"Type_Hotfix"              = "^(\[)Hotfix(\])"
			"Type_Path"                = "^(\[)Path(\])"
			"Type_Version_FileInfo"    = "^(\[)Vers_File(\])"
			"Type_Version_ProductInfo" = "^(\[)Vers_Product(\])"
			"Type_Program"             = "^(\[)Program(\])"
			"Value_MSIGUID"            = "^\{(.*)\}$"
		}
	}
	"Variable" = @{
		"TerminateProcess" = @{
			"AlreadyPrompted"          = $False # Ensures to only display TerminateMessage prompt once, if terminating more than one process.
		}
		"VerifyInstall" = @{
			"SpecifiedBuild"           = $Null
			"DiscoveredBuild"          = $Null
			"Existence"                = $Null
			"ProgramReference"         = $Null
		}
	}
}

$TaskEntry = @{
	"TaskName"         = $Null
	"Executable"       = $Null
	"OperatingSystem"  = $Null
	"Architecture"     = $Null
	"TerminateProcess" = $Null
	"TerminateMessage" = $Null
	"VerifyInstall"    = $Null
	"SuccessExitCode"  = $Null
	"ContinueIfFail"   = $Null
	"SkipProcessCount" = $Null
}

# <<<< PROPERTIES ----

# ---- FUNCTIONS >>>>

function Get-EnvironmentVariableValue
{
	Param (
		[Parameter(Mandatory = $True)]
		[String]
		$Path
	)

	$Function = @{
		"EnvironmentVariableSyntax" = @{
			"Before"                = "^(\$)env(\:)"
			"After"                 = "env:\"
		}
		"Path"                      = $Path
		"Result"                    = $Null
	}

	foreach ($Item in $Function.Path -split "\\")
    {
		if ($Item -match $Function.EnvironmentVariableSyntax.Before)
        {
			$Item = $Item -replace ($Function.EnvironmentVariableSyntax.Before, $Function.EnvironmentVariableSyntax.After)

			try
            {
				$Item = (Get-Content $Item -ErrorAction Stop)
			}
			catch [Exception]
            {
				continue
			}
		}

		else {}

		$Function.Result += @($Item)
	}

	return ($Function.Result -join "\")
}

function Invoke-Executable
{
	Param (
		[Parameter(Mandatory = $True)]
		[String]
		$Path
	)

	$Invocation = @{
		"Input"                  = $Path
		"Executable" = @{
			"Value"              = $Null
			"Quoted"             = "^(\"")(.*)(\"")"
			"Unquoted"           = "^(\S+)"
		}
		"Arguments" = @{
			"Value"              = $Null
			"LeftwardWhitespace" = "^(\s+)(.*)"
		}
	}

	# Split executable and its arguments:

	if ($Invocation.Input -match $Invocation.Executable.Quoted)
    {
		$Invocation.Executable.Value = $Invocation.Input -match $Invocation.Executable.Quoted
		$Invocation.Executable.Value = $Matches[2]
		$Invocation.Arguments.Value  = $Invocation.Input -replace ($Invocation.Executable.Quoted, "")
	}
	else
    {
		$Invocation.Executable.Value = $Invocation.Input -match $Invocation.Executable.Unquoted
		$Invocation.Executable.Value = $Matches[1]
		$Invocation.Arguments.Value  = $Invocation.Input -replace ($Invocation.Executable.Unquoted, "")
	}

	# Remove potential whitespace between executable and its arguments:

	if ($Invocation.Arguments.Value -match $Invocation.Arguments.LeftwardWhitespace)
    {
		$Invocation.Arguments.Value = $Invocation.Arguments.Value -match $Invocation.Arguments.LeftwardWhitespace
		$Invocation.Arguments.Value = $Matches[2]
	}
	else {}

	try
    {
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
	catch [Exception]
    {
		throw
	}
}

function pass
{
	<#
		A placeholder, borrowed from Python, with the purpose of doing away with "{}" and
		improving readability when reviewing conditionals.
	#>
}

function Show-BalloonTip
{
	[CmdletBinding(SupportsShouldProcess = $True)]
	Param (
		[Parameter(Mandatory = $True)]
		$Title,

		[Parameter(Mandatory = $False)]
		$Text = " ",

		[Parameter(Mandatory = $False)]
		[ValidateSet("None", "Info", "Warning", "Error")]
		$Icon = "Info",

		[Parameter(Mandatory = $False)]
		$Timeout = 10000
	)

	$Script:Balloon -eq $null

	Add-Type -AssemblyName System.Windows.Forms

	if ($Script:Balloon -eq $Null)
    {
		$Script:Balloon = New-Object System.Windows.Forms.NotifyIcon
	}

	$Path                    = Get-Process -Id $PID | Select-Object -ExpandProperty Path
	$Balloon.Icon            = [System.Drawing.Icon]::ExtractAssociatedIcon($Path)
	$Balloon.BalloonTipIcon  = $Icon
	$Balloon.BalloonTipText  = $Text
	$Balloon.BalloonTipTitle = $Title
	$Balloon.Visible         = $True

	$Balloon.ShowBalloonTip($Timeout)
}

function Show-DialogBox
{
	Param (
		[Parameter(Mandatory = $True)]
		[String]
		$Title,

		[Parameter(Mandatory = $True)]
		[String]
		$Message
	)

	$Wscript = New-Object -COMObject Wscript.Shell
	$Wscript.Popup($Message, 0, $Title, 0x0)
}

function Write-Result
{
	Param (
		[Parameter(Mandatory = $True)]
		[String]
		$Status,

		[Parameter(Mandatory = $False)]
		[String]
		$Code = "",

		[Parameter(Mandatory = $False)]
		[String]
		$Output,

		[Parameter(Mandatory = $False)]
		[Switch]
		$AddNewLine
	)

	[String]$Result = ""

	if ($Output -notmatch "^$")
    {
		if ($AddNewLine)
        {
			$Result += ("{0}`n`n" -f $Output)
		}
		else
        {
			$Result += ("{0}`n" -f $Output)
		}
	}
	else {}

	if ($Code -notmatch "^$")
    {
		$Code = (": ({0})" -f $Code)
	}

	$Result += ("{0}{1}`n`n----" -f $Status, $Code)

	return $Result
}

# <<<< FUNCTIONS ----

# ---- MAIN >>>>

# ---- Package File Importation >>>>

try
{
	if (Test-Path $Package.Path)
    {
		[XML]$Package.Content.All      = Get-Content $Package.Path
		$Package.Content.Configuration = $Package.Content.All.Package.Configuration
		$Package.Content.TaskEntry     = $Package.Content.All.Package.TaskEntry
	}
	else
    {
		throw "No package file was present within the package directory."
	}
}
catch [Exception]
{
	Write-Host -ForegroundColor Red ("`nERROR: A package file could not be imported. Details: {0}" -f $Error[0])

	[Environment]::Exit(5)
}

# ---- Script Configuration Processing >>>>

if ($Package.Content.Configuration.BlockHost -notmatch "^$")
{
	$Script.Config.BlockHost = $Package.Content.Configuration.BlockHost -split ($Package.Delimiter)
	$Script.Config.TotalImported++
}
else
{
	pass
}

if ($Package.Content.Configuration.PackageName -notmatch "^$")
{
	$Package.Name = $Package.Content.Configuration.PackageName
	$Script.Config.TotalImported++
}
else
{
	pass
}

if ($Package.Content.Configuration.SuppressNotification -eq $False)
{
	$Script.Config.SuppressNotification = $False
	$Script.Config.TotalImported++
}
else
{
	pass
}

if ($Script.Config.TotalImported -gt 0)
{
	$Script.Config.ImportState = $True
}
else
{
	$Script.Config.ImportState = $False
}

# ---- Notification Message Composition >>>>

$Package += @{
	"Notification" = @{
		"Header" = ("Installed ""{0}"" package!" -f $Package.Name)
		"Footer" = "Questions or concerns? Contact your system administrator for more information."
	}
}

# ---- BlockHost Processing (Script Configuration) >>>>

foreach ($ImportedHostname in $Script.Config.BlockHost)
{
	if ($Machine.Hostname -match $ImportedHostname -and $ImportedHostname -notmatch "^$")
    {
		Write-Host -ForegroundColor Red ("`nERROR: Package ""{0}"" will not be processed, as this host is blocked.`n" -f $Package.Name)

		[Environment]::Exit(4)
	}
	else
    {
		pass
	}
}

# ---- Task Entry Processing >>>>

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

foreach ($Item in $Package.Content.TaskEntry)
{
	try
    {
		$TaskEntry.TaskName         = $Item.TaskName
		$TaskEntry.Executable       = $Item.Executable
		$TaskEntry.OperatingSystem  = $Item.OperatingSystem
		$TaskEntry.Architecture     = $Item.Architecture
		$TaskEntry.TerminateProcess = $Item.TerminateProcess
		$TaskEntry.TerminateMessage = $Item.TerminateMessage
		$TaskEntry.VerifyInstall    = $Item.VerifyInstall
		$TaskEntry.SuccessExitCode  = $Item.SuccessExitCode
		$TaskEntry.ContinueIfFail   = $Item.ContinueIfFail
		$TaskEntry.SkipProcessCount = $Item.SkipProcessCount
	}
	catch [Exception]
    {
		$Script.Output = ("`nTask Entry ({0}): {1}" -f $TaskEntry.TaskName, $Error[0])
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 3 -Output $Script.Output -AddNewLine)

		$Script.ExitCode = 3
		break
	}

	# ---- TaskName Parameter >>>>

	$Package.TaskEntryStatus.Index = $Package.TaskEntryStatus.Index + 1

	if ($TaskEntry.TaskName -match "^$" -or $TaskEntry.TaskName -match "^(\s+)$")
    {
		$Script.Output = ("`nTaskName: Specification is required for ""{0}"" at Task Entry {1}." -f $TaskEntry.Executable, [String]$Package.TaskEntryStatus.Index)
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output -AddNewLine)

		$Script.ExitCode = 7
		break
	}
	elseif ($TaskEntry.TaskName -match "^\#")
    {
		continue
	}
	else
    {
		pass
	}

	# ---- Executable Parameter >>>>

	if ($TaskEntry.Executable -match "^$" -or $TaskEntry.Executable -match "^(\s+)$")
    {
		$Script.Output = ("`nExecutable: Specification is required for ""{0}"" at Task Entry {1}." -f $TaskEntry.TaskName, [String]$Package.TaskEntryStatus.Index)
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 7 -Output $Script.Output -AddNewLine)

		$Script.ExitCode = 7
		break
	}
	elseif ($TaskEntry.Executable -match $Package.TaskEntrySubparameterRegexp.Executable.Package)
    {
		$TaskEntry.Executable = $TaskEntry.Executable -Replace ($Package.TaskEntrySubparameterRegexp.Executable.Package, ("{0}\" -f $Script.CurrentDirectory))
	}
	else
    {
		pass
	}

	# The following loop prevents execution of arbitrary commands:

	foreach ($Item in $Package.TaskEntrySubparameterRegexp.Executable.Sanitizer)
    {
		$TaskEntry.Executable = $TaskEntry.Executable -replace ($Item, "")
	}

	# Outputs task entry's respective TaskName and Executable values to host:

	Write-Host -NoNewLine ("`n({0}) {1}: " -f $Package.TaskEntryStatus.Index, $TaskEntry.TaskName)
	Write-Host -ForegroundColor Cyan ("`n[{0}]`n" -f $TaskEntry.Executable)

	# ---- OperatingSystem Parameter >>>>

	if ($TaskEntry.OperatingSystem -match "^$")
    {
		pass
	}
	elseif ($Machine.OSVersion -match $TaskEntry.OperatingSystem)
    {
		pass
	}
	else
    {
		$Script.Output = ("OperatingSystem: ""{0}"" is a requirement." -f $TaskEntry.OperatingSystem)

		Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
		continue
	}

	# ---- Architecture Parameter >>>>

	if ($TaskEntry.Architecture -match "^$")
    {
		pass
	}
	elseif ($TaskEntry.Architecture -match $Machine.UserspaceArchitecture)
    {
		pass
	}
	else
    {
		$Script.Output = ("Architecture: ""{0}"" is a requirement." -f $TaskEntry.Architecture)

		Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
		continue
	}

	# ---- VerifyInstall Parameter >>>>

	# ---- VerifyInstall Parameter (Type_Hotfix Subparameter) >>>>

	if ($TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Hotfix)
    {
		$TaskEntry.VerifyInstall                  = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Hotfix, "")
		$Package.Variable.VerifyInstall.Existence = Get-Hotfix | ? {$_.HotfixID -eq $TaskEntry.VerifyInstall}

		if ($Package.Variable.VerifyInstall.Existence -ne $Null)
        {
			$Script.Output = ("VerifyInstall: [Hotfix] ""{0}"" exists." -f $TaskEntry.VerifyInstall)

			Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
			continue
		}
		else
        {
			pass
		}
	}

	# ---- VerifyInstall Parameter (Type_Path Subparameter) >>>>

	elseif ($TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Path)
    {
		$TaskEntry.VerifyInstall                  = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Path, "")
		$TaskEntry.VerifyInstall                  = Get-EnvironmentVariableValue -Path $TaskEntry.VerifyInstall
		$Package.Variable.VerifyInstall.Existence = Test-Path $TaskEntry.VerifyInstall

		if ($Package.Variable.VerifyInstall.Existence -eq $True)
        {
			$Script.Output = ("VerifyInstall: [Path] ""{0}"" exists." -f $TaskEntry.VerifyInstall)

			Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
			continue
		}
		else
        {
			pass
		}
	}

	# ---- VerifyInstall Parameter (Version_FileInfo Subparameter) >>>>

	elseif ($TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Version_FileInfo)
    {
		$TaskEntry.VerifyInstall = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Version_FileInfo, "")

		try
        {
			# Separates Arg_Build (version/build number) and VerifyInstall value (file path):

			$TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Arg_Build | Out-Null

			$TaskEntry.VerifyInstall                        = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Arg_Build, "")
			$TaskEntry.VerifyInstall                        = Get-EnvironmentVariableValue -Path $TaskEntry.VerifyInstall
			$Package.Variable.VerifyInstall.SpecifiedBuild  = $Matches[1]
			$Package.Variable.VerifyInstall.DiscoveredBuild = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall) | % {$_.FileVersion}

			# Determines as to whether or not both Arg_Build and version/build number of VerifyInstall value (file path) match:

			if ($Package.Variable.VerifyInstall.SpecifiedBuild -eq $Package.Variable.VerifyInstall.DiscoveredBuild)
            {
				$Script.Output = ("VerifyInstall: [Vers_File] ""{0}"" exists." -f $Package.Variable.VerifyInstall.SpecifiedBuild)

				Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
				continue
			}
			else
            {
				throw
			}
		}
		catch [Exception]
        {
			pass
		}
	}

	# ---- VerifyInstall Parameter (Version_ProductInfo Subparameter) >>>>

	elseif ($TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Version_ProductInfo)
    {
		$TaskEntry.VerifyInstall = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Version_ProductInfo, "")

		try
        {
			# Separates Arg_Build (version/build number) and VerifyInstall value (file path):

			$TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Arg_Build | Out-Null

			$TaskEntry.VerifyInstall                        = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Arg_Build, "")
			$TaskEntry.VerifyInstall                        = Get-EnvironmentVariableValue -Path $TaskEntry.VerifyInstall
			$Package.Variable.VerifyInstall.SpecifiedBuild  = $Matches[1]
			$Package.Variable.VerifyInstall.DiscoveredBuild = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($TaskEntry.VerifyInstall) | % {$_.ProductVersion}

			# Determines as to whether or not both Arg_Build and version/build number of VerifyInstall value (file path) match:

			if ($Package.Variable.VerifyInstall.SpecifiedBuild -eq $Package.Variable.VerifyInstall.DiscoveredBuild)
            {
				$Script.Output = ("VerifyInstall: [Vers_Product] ""{0}"" exists." -f $Package.Variable.VerifyInstall.SpecifiedBuild)

				Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
				continue
			}
			else
            {
				throw
			}
		}
		catch [Exception]
        {
			pass
		}
	}

	# ---- VerifyInstall Parameter (Type_Program Subparameter) >>>>

	elseif ($TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Program)
    {
		$TaskEntry.VerifyInstall = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Type_Program, "")

		try
        {
			if ($TaskEntry.VerifyInstall -notmatch $Package.TaskEntrySubparameterRegexp.VerifyInstall.Arg_Build) # If the VerifyInstall value does not contain the Arg_Build argument.
            {

				# Determines whether or not VerifyInstall value is a MSI GUID, in order to reference the correct property:

				if ($TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Value_MSIGUID)
                {
					$Package.Variable.VerifyInstall.ProgramReference = "PSChildName"
				}
				else
                {
					$Package.Variable.VerifyInstall.ProgramReference = "DisplayName"
				}

				# Searches the registry for possible program name or MSI GUID that matches VerifyInstall value:

				foreach ($Path in $Machine.ProgramList)
                {
					if (Test-Path $Path)
                    {
						$Package.Variable.VerifyInstall.Existence += @(
							Get-ChildItem $Path | % {Get-ItemProperty $_.PSPath} | ? {$_.$($Package.Variable.VerifyInstall.ProgramReference) -eq $TaskEntry.VerifyInstall} | % {$_.DisplayName}
						)
					}
					else
                    {
						pass
					}
				}

				# Determines as to whether or not a matching program code or MSI GUID was found:

				if ($Package.Variable.VerifyInstall.Existence -ne $Null)
                {
					$Script.Output = ("VerifyInstall: [Program] ""{0}"" exists." -f $TaskEntry.VerifyInstall)

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
					continue
				}
				else
                {
					throw
				}
			}
			else
            {
				# Separates Arg_Build (version/build number) and VerifyInstall value (program name/MSI GUID):

				$TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Arg_Build | Out-Null
				$TaskEntry.VerifyInstall                       = $TaskEntry.VerifyInstall -replace ($Package.TaskEntrySubparameterRegexp.VerifyInstall.Arg_Build, "")
				$Package.Variable.VerifyInstall.SpecifiedBuild = $Matches[1]

				# Determines whether or not VerifyInstall value is a MSI GUID, in order to reference the correct property:

				if ($TaskEntry.VerifyInstall -match $Package.TaskEntrySubparameterRegexp.VerifyInstall.Value_MSIGUID)
                {
					$Package.Variable.VerifyInstall.ProgramReference = "PSChildName"
				}
				else
                {
					$Package.Variable.VerifyInstall.ProgramReference = "DisplayName"
				}

				# Searches the registry for possible program name/MSI GUID that matches VerifyInstall value:

				foreach ($Path in $Machine.ProgramList)
                {
					if (Test-Path $Path)
                    {
						$Package.Variable.VerifyInstall.DiscoveredBuild += @(
							Get-ChildItem $Path | % {Get-ItemProperty $_.PSPath} | ? {$_.$($Package.Variable.VerifyInstall.ProgramReference) -eq $TaskEntry.VerifyInstall} | % {$_.DisplayVersion}
						)
					}
					else
                    {
						pass
					}
				}

				# Determines whether or not there is a match between a discovered program name/MSI GUID's respective version/build number and Arg_Build:

				if ($Package.Variable.VerifyInstall.DiscoveredBuild -contains $Package.Variable.VerifyInstall.SpecifiedBuild)
                {
					$Script.Output = ("VerifyInstall: [Program] ""{0}"" exists." -f $Package.Variable.VerifyInstall.SpecifiedBuild)

					Write-Host -ForegroundColor Yellow (Write-Result -Status "SKIP" -Output $Script.Output -AddNewLine)
					continue
				}
				else
                {
					throw
				}
			}
		}
		catch [Exception]
        {
			pass
		}
	}
	else
    {
		pass
	}

	# <<<< VerifyInstall Parameter ----

	# ---- TerminateProcess Parameter >>>>

	if ($TaskEntry.TerminateProcess -notmatch "^$")
    {
		$TaskEntry.TerminateProcess = $TaskEntry.TerminateProcess -split ($Package.Delimiter)

		foreach ($Process in $TaskEntry.TerminateProcess)
        {
			try
            {
				if (Get-Process $Process)
                {
					pass
				}
				else
                {
					continue
				}

				if ($TaskEntry.TerminateMessage -notmatch "^$" -and $Package.Variable.TerminateProcess.AlreadyPrompted -eq $False)
                {
					Show-DialogBox -Title $Package.Name -Message $TaskEntry.TerminateMessage | Out-Null
					$Package.Variable.TerminateProcess.AlreadyPrompted = $True
				}
				else
                {
					pass
				}

				Get-Process $Process | Stop-Process -Force
			}
			catch [Exception]
            {
				continue
			}
		}
	}
	else
    {
		pass
	}

	# ---- SuccessExitCode Parameter >>>>

	if ($TaskEntry.SuccessExitCode -eq $Null)
    {
		$TaskEntry.SuccessExitCode = 0
	}
	else
    {
		$TaskEntry.SuccessExitCode  = $TaskEntry.SuccessExitCode -split ($Package.Delimiter)
		$TaskEntry.SuccessExitCode += 0
	}

	# ---- Executable Invocation Processing >>>>

	try
    {
		$Script.Output = (Invoke-Executable -Path $TaskEntry.Executable)

		if ($TaskEntry.SuccessExitCode -contains $Script.Output.ExitCode)
        {
			Write-Host -ForegroundColor Green (Write-Result -Status "OK" -Code $Script.Output.ExitCode -Output $Script.Output.Output)

			if ($TaskEntry.SkipProcessCount -ne "true")
            {
				$Package.TaskEntryStatus.Successful++
			}
			else
            {
				continue
			}
		}
		else
        {
			Write-Host -ForegroundColor Red (Write-Result -Status "WARN" -Code $Script.Output.ExitCode -Output $Script.Output.Output)

			if ($TaskEntry.SkipProcessCount -ne "true")
            {
				$Package.TaskEntryStatus.Unsuccessful++
			}
			else
            {
				pass
			}

			if ($TaskEntry.ContinueIfFail -ne "true")
            {
				$Script.ExitCode = 1
				break
			}
			else
            {
				$Package.TaskEntryStatus.TotalFailedButContinued++
				continue
			}
		}
	}
	catch [Exception]
    {
		$Script.Output = ("Executable Invocation: {0}" -f $Error[0])
		Write-Host -ForegroundColor Red (Write-Result -Status "ERROR" -Code 2 -Output $Script.Output -AddNewLine)

		if ($TaskEntry.SkipProcessCount -ne "true")
        {
			$Package.TaskEntryStatus.Unsuccessful++
		}
		else
        {
			pass
		}

		if ($TaskEntry.ContinueIfFail -ne "true")
        {
			$Script.ExitCode = 2
			break
		}
		else
        {
			$Package.TaskEntryStatus.TotalFailedButContinued++
			continue
		}
	}
}

# ---- Package Result Reporting >>>>

if ($Package.TaskEntryStatus.Successful -eq 0 -and $Package.TaskEntryStatus.Unsuccessful -eq 0)
{
	Write-Host -ForegroundColor Red "`nWARN: No task entries were processed.`n"

	if ($Script.ExitCode -eq 0)
    {
		$Script.ExitCode = 6
	}
	else
    {
		pass
	}
}
else
{
	$Package.TaskEntryStatus.TotalProcessed = [Int]$Package.TaskEntryStatus.Successful + [Int]$Package.TaskEntryStatus.Unsuccessful

	$Script.Output = (
		"`nTasks Processed : " + $Package.TaskEntryStatus.TotalProcessed + `
		"`n  ^"                                                          + `
		"`n  |"                                                          + `
		"`n  |---- Success : " + $Package.TaskEntryStatus.Successful     + `
		"`n  +---- Failure : " + $Package.TaskEntryStatus.Unsuccessful   + `
		"`n"
	)

	Write-Host ("`nPackage Results ({0}):" -f $Package.Name)

	if ($Script.ExitCode -eq 0)
    {
		$Script.Output += ("`nOK: ({0})`n" -f $Script.ExitCode)

		Write-Host -ForegroundColor Green $Script.Output

		if ($Script.Config.SuppressNotification -eq $False)
        {
			Show-BalloonTip -Title $Package.Notification.Header -Text $Package.Notification.Footer | Out-Null
		}
		else
        {
			pass
		}
	}
	else
    {
		$Script.Output += ("`nERROR: ({0})`n" -f $Script.ExitCode)

		Write-Host -ForegroundColor Red $Script.Output
	}
}

[Environment]::Exit($Script.ExitCode)
