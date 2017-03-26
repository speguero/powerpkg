# powerpkg

![Header](/readme/header.gif)

`powerpkg` is a Windows-focused script that provides IT departments a standard framework for unattended software deployment packaging from within a corporate network.

Similar to Ansible and its playbook file functionality, `powerpkg` is accompanied and leveraged by a [configuration file](#package-file-packagexml) that can contain the necessary commands and verification processes to build a package and guarantee a seamless deployment to an end-user's workstation via a company's distribution tool of choice, whether it's Microsoft SCCM or Ivanti/LANDesk.

*This project was proudly written in PowerShell.*

## Section

1. [Requirement](#requirement)
2. [Getting Started](#getting-started)
3. [How It Works](#how-it-works)
4. [Package File (`package.xml`)](#package-file-packagexml)
    - [Script Configuration (`<Configuration>`)](#script-configuration-configuration)
        - [PackageName](#packagename)
        - [BlockHost](#blockhost)
        - [SuppressNotification](#suppressnotification)
    - [Task Entry (`<TaskEntry>`)](#task-entry-taskentry)
        - [TaskName](#taskname)
        - [Executable](#executable)
        - [OperatingSystem](#operatingsystem)
        - [Architecture](#architecture)
        - [TerminateProcess](#terminateprocess)
        - [TerminateMessage](#terminatemessage)
        - [SuccessExitCode](#successexitcode)
        - [ContinueIfFail](#continueiffail)
        - [VerifyInstall](#verifyinstall)
        - [SkipProcessCount](#skipprocesscount)
5. [Debugging](#debugging)
6. [License](#license)
7. [Additional Comments](#additional-comments)

## Requirement

Before reading through this documentation, please note that a minimum of **PowerShell 2.0** is required to utilize this project. **However, PowerShell 3.0 or higher is recommended.**

## Getting Started

To begin test driving powerpkg:

**(1)**: Clone this repository or download it as a ZIP file.

**(2)**: Invoke `powerpkg.ps1`:
```shell
powershell.exe -NoProfile -ExecutionPolicy Unrestricted -File "example_package\powerpkg.ps1"
```

**(3)**: *And that's it!*

> **NOTE**:
>
> To discover basic usage of powerpkg, refer to the [How It Works](#how-it-works) segment of this README.

## How It Works

**(1)**: Save the following XML element inside a [`package.xml`](#package-file-packagexml) file alongside `powerpkg.ps1`:

```xml
<Package>
</Package>
```

**(2)**: Copy the following [script configuration](#script-configuration-configuration) XML element and paste it inside the `<Package>` XML element:

```xml
<Configuration>
	<PackageName>Example Package</PackageName>
	<BlockHost></BlockHost>
	<SuppressNotification>false</SuppressNotification>
</Configuration>
```

**(3)**: Copy the following [task entry](#task-entry-taskentry) XML element and paste it below the `<Configuration>` XML element:

```xml
<TaskEntry>
	<TaskName>Example Task Entry</TaskName>
	<Executable>powershell.exe -NoProfile Write-Host "Hello World!"</Executable>
</TaskEntry>
```

**(4)**: Ensure your package file (`package.xml`) appears as this example:

```xml
<Package>
	<Configuration>
		<PackageName>Example Package</PackageName>
		<BlockHost></BlockHost>
		<SuppressNotification>false</SuppressNotification>
	</Configuration>
	<TaskEntry>
		<TaskName>Example Task Entry</TaskName>
		<Executable>powershell.exe -NoProfile Write-Host "Hello World!"</Executable>
	</TaskEntry>
</Package>
```

**(5)**: Invoke `powerpkg.ps1`:
```shell
powershell.exe -NoProfile -ExecutionPolicy Unrestricted -File "powerpkg.ps1"
```

**(6)**: As `powerpkg.ps1` is running, you will notice output similar to the following example:
```
Initiating Package (Example Package):

Host                       : examplehost1
Operating System (Windows) : 6.3
Userspace Architecture     : AMD64
User                       : misterpeguero

----

Configuration Importation  : True
Suppress Notification      : False

----

(1) Example Task Entry:
[powershell.exe -NoProfile Write-Host "Hello World!"]

Hello World!

OK: (0)

----

Package Results (Example Package):

Tasks Processed : 1
 ^
 |
 |---- Success : 1
 +---- Failure : 0

OK: (0)
```
**(7)**: *And that's it!*

The last line in the example output above (`OK: (0)`) solely reports the exit code of `powerpkg.ps1`. In this case, the zero exit code indicates a successful package deployment. Specified executables also report an exit code upon their invocation and have an influence on the exit code of `powerpkg.ps1`.

> **NOTE**:
>
> If `powerpkg.ps1` terminates with a non-zero exit code, determine its meaning in the [Debugging](#debugging) segment of this README.
>
> To discover in-depth usage of powerpkg, refer to the [Package File](#package-file-packagexml) segment of this README.

## Package File (`package.xml`)

A package file is a configuration file of `powerpkg.ps1` that consists of instructions that:

  1. [Specify how `powerpkg.ps1` should behave](#script-configuration-configuration), using one `<Configuration>` XML element.
  2. [What executables to invoke and how to invoke them](#task-entry-taskentry), using one or more `<TaskEntry>` XML elements.

And are typically presented in the following manner:

```xml
<Package>
	<Configuration>
		<PackageName></PackageName>
		<BlockHost></BlockHost>
		<SuppressNotification></SuppressNotification>
	</Configuration>
	<TaskEntry>
		<TaskName></TaskName>
		<Executable></Executable>
		<OperatingSystem></OperatingSystem>
		<Architecture></Architecture>
		<TerminateProcess></TerminateProcess>
		<TerminateMessage></TerminateMessage>
		<SuccessExitCode></SuccessExitCode>
		<ContinueIfFail></ContinueIfFail>
		<VerifyInstall></VerifyInstall>
		<SkipProcessCount></SkipProcessCount>
	</TaskEntry>
</Package>
```

Which, with a bit of customization, can become the following example:

```xml
<Package>
	<Configuration>
		<PackageName>Example Package</PackageName>
		<BlockHost>examplehost1,examplehost2</BlockHost>
		<SuppressNotification>false</SuppressNotification>
	</Configuration>
	<TaskEntry>
		<TaskName>Example Task Entry</TaskName>
		<Executable>powershell.exe -NoProfile Write-Host "Hello World!"</Executable>
		<OperatingSystem>6.1</OperatingSystem>
		<Architecture>AMD64</Architecture>
		<TerminateProcess>exampleprocess</TerminateProcess>
		<TerminateMessage>Example Program will terminate. Press OK to continue.</TerminateMessage>
		<SuccessExitCode>1234</SuccessExitCode>
		<ContinueIfFail>true</ContinueIfFail>
		<VerifyInstall>[Program]Example Program</VerifyInstall>
		<SkipProcessCount>false</SkipProcessCount>
	</TaskEntry>
	<TaskEntry>
		<TaskName>Another Example Task Entry</TaskName>
		<Executable>powershell.exe -NoProfile Write-Host "Hello New England!"</Executable>
	</TaskEntry>
	<TaskEntry>
		<TaskName>Yet Another Example Task Entry</TaskName>
		<Executable>msiexec.exe /i "[Package]example_program.msi" /qn /norestart</Executable>
		<VerifyInstall>[Program]Example Program</VerifyInstall>
	</TaskEntry>
</Package>
```

To further familiarize yourself with powerpkg (and especially the above examples), continue reading the [Script Configuration](#script-configuration-configuration) and [Task Entry](#task-entry-taskentry) segments of this README. Examining the contents of the `\example_package` directory is also encouraged.

### Script Configuration (`<Configuration>`)

The `<Configuration>` XML element allows for specifying how `powerpkg.ps1` should behave. If `<Configuration>` is nonexistent or no values are specified within `package.xml`, the default values for the parameters mentioned below are used.

`<Configuration>` should be specified only once within `package.xml`.

#### `PackageName`

> - **Required**: No
> - **Purpose**: Allows for specifying a custom name for a package.
> - **Default Value**: The name of the package directory.
> - **Example Value**:
>
> ```xml
> <PackageName>Example Package</PackageName>
> ```

#### `BlockHost`

> - **Required**: No
> - **Purpose**: Prevents specified hosts from processing a package.
> - **Default Value**: `null`
> - **Example Value**:
>
> ```xml
> <BlockHost>examplehost1</BlockHost>
>
> <BlockHost>examplehost1,examplehost2</BlockHost>
> ```
>
> **NOTE**:
>
> A range of hosts can also be blocked, as well. If you have a set machines whose **first** several characters are identical, such as the following example:
>
> ```
> ABCDE1111
> ABCDE2222
> ABCDE3333
> ABCDE4444
> ABCDE5555
> ```
>
> You can block the list of machines mentioned above by specifying the following:
>
> ```xml
> <BlockHost>ABCDE</BlockHost>
> ```

#### `SuppressNotification`

> - **Required**: No
> - **Purpose**: Prevents a balloon notification from displaying upon a successful deployment.
> - **Default Value**: `true`
> - **Example Value**:
>
> ```xml
> <SuppressNotification>true</SuppressNotification>
>
> <SuppressNotification>false</SuppressNotification>
> ```

### Task Entry (`<TaskEntry>`)

The `<TaskEntry>` XML element allows for specifying what executables to invoke and how to invoke them.

Because of its purpose, `<TaskEntry>` can also be specified more than once within `package.xml`.

#### `TaskName`

> - **Required**: Yes
> - **Purpose**: The title for an individual task entry.

```xml
<TaskName>Install Program</TaskName>
```

> **NOTE**:
>
> You can temporarily skip task entries for the sole purpose of debugging and testing packages, by specifying `#` as the first character in this fashion:
>
> ```xml
> <TaskName>#Install Program</TaskName>
> ```

#### `Executable`

> - **Required**: Yes
> - **Purpose**: An executable file/path to invoke.
> - **Subparamaters**:
>
> Subparameter | Description
> ------------ | -----------
> `[Package]`  | Allows for specifying a file or directory located within a package directory.

> **NOTE**:
>
> Before calling `powershell.exe`, ensure to specify the `-NoProfile` parameter (`powershell.exe -NoProfile Example-Command`), to minimize the risk of arbitrary code execution.

##### Whitespace and Quotation Marks

When specifying an executable path or arguments containing whitespace, it is recommended to surround such text with double quotation marks.

For individual file and/or directory names containing whitespace, such items should be surrounded by **single** quotation marks. However, note that this tip solely applies to arguments, and not executable paths themselves.

Example: `powershell.exe "[Package]'an example.ps1'"` or `"C:\White Space\example.exe" /argument "D:\'More White Space'\Directory"`

It is also recommended to always surround files and/or directories specified with the `[Package]` parameter with double quotation marks, to prevent I/O exceptions from being thrown with the usage of whitespace within the directory path of a package directory.

##### Environment Variables

Unfortunately, at this time, powerpkg does not support the independent usage of environment variables. However, as a workaround, you can:

- Call `cmd.exe` in the following manner: `cmd.exe /c notepad.exe %SYSTEMDRIVE%\test.txt`.
- Call `powershell.exe` in the following manner: `powershell.exe Start-Process -FileName notepad.exe -ArgumentList $env:SYSTEMDRIVE\test.txt -Wait`.

##### Examples

Here are other valid example use cases of the `Executable` parameter:

```xml
<Executable>ipconfig.exe</Executable>

<Executable>msiexec.exe /i "[Package]example.msi" /qn /norestart</Executable>

<Executable>cmd.exe /q /c "[Package]example.bat"</Executable>

<Executable>"[Package]example.exe"</Executable>

<Executable>"[Package]example_directory\'example file with whitespace.exe'"</Executable>
```

#### `OperatingSystem`

> - **Required**: No
> - **Purpose**: The operating system a task entry should be processed under.

When utilizing this parameter, you will want to specify the NT kernel version number of a specific Windows operating system:

Windows Operating System | NT Kernel Version
------------------------ | -----------------
10                       | `10.0`
8.1                      | `6.3`
8                        | `6.2`
7                        | `6.1`
Vista                    | `6.0`

And specify a NT kernel version number in this fashion:

```xml
<OperatingSystem>6.3</OperatingSystem>
```

> **NOTE**:
>
> Because the `OperatingSystem` parameter determines to find a match between a specified value (`6.1`) and the complete version number of a Windows operating system (`6.1.7601`), the value of `6.1.7601`, which indicates a specific build of Windows 7, can be specified, as well.

#### `Architecture`

> - **Required**: No
> - **Purpose**: The userspace architecture a task entry should be processed under.

For executable invocations that depend on a specific architectural environment, you will want to specify the following for:

**AMD64** (x64 in Microsoft terminology) environments:

```xml
<Architecture>AMD64</Architecture>
```

**x86** environments:

```xml
<Architecture>x86</Architecture>
```

#### `TerminateProcess`

> - **Required**: No, except when utilizing the `TerminateMessage` parameter.
> - **Purpose**: A process, or list of process, to terminate prior to executable invocation.

```xml
<TerminateProcess>explorer</TerminateProcess>

<TerminateProcess>explorer,notepad</TerminateProcess>
```

#### `TerminateMessage`

> - **Required**: No
> - **Purpose**: A message to display to an end-user prior to the termination of processes. Used in conjunction with the `TerminateProcess` parameter.

```xml
<TerminateMessage>File Explorer will terminate. When prepared, click on the OK button.</TerminateMessage>
```

#### `SuccessExitCode`

> - **Required**: No
> - **Purpose**: Non-zero exit codes that also determine a successful task entry.

> **NOTE**:
>
> The `0` exit code is automatically applied to any specified value, regardless as to whether or not it is explicitly specified.

```xml
<SuccessExitCode>10</SuccessExitCode>

<SuccessExitCode>10,777,1000</SuccessExitCode>
```

#### `ContinueIfFail`

> - **Required**: No
> - **Purpose**: Specify as to whether or not to continue with remaining task entires if a specific task entry fails.

When explicitly utilizing the `ContinueIfFail` parameter and specifying the following value:

Value             | Result
-----             | ------
`true`            | `powerpkg.ps1` will continue processing remaining task entires. A task entry set to continue when resulting in a non-zero exit code will not alter the exit code of `powerpkg.ps1`.
`false` (Default) | `powerpkg.ps1` will fail and result in a non-zero exit code.

And specify your desired value in this fashion:

```xml
<ContinueIfFail>true</ContinueIfFail>
```

#### `VerifyInstall`

> - **Required**: No
> - **Purpose**: Skip a task entry if a program, hotfix, file/directory path, or a specific version of an executable file exist.
> - **Subparamaters**:
>
> Subparameter     | Description                                                        | Additional Arguments | Additional Arguments Required?
> ------------     | -----------                                                        | -------------------- | ------------------------------
> `[Hotfix]`       | Verify the existence of a hotfix.                                  |                      |
> `[Path]`         | Verify the existence of a file or directory path.                  |                      |
> `[Vers_File]`    | Verify the file version of an executable file.                     | `[Build:]`           | Yes
> `[Vers_Product]` | Verify the product version of an executable file.                  | `[Build:]`           | Yes
> `[Program]`      | Verify the existence of an installed program name or product code. | `[Build:]`           | No

> **NOTE**:
>
> When utilizing the `VerifyInstall` parameter, you **must** specify one of the following subparamaters mentioned above.
>
> The usage of PowerShell environment variables, such as `$env:SYSTEMDRIVE`, is supported by the `VerifyInstall` parameter.
>
> The usage of quotation marks is not a requirement, even for paths that contain whitespace.

##### [Build:] Argument

As you may have noticed, certain parameters take advantage of a **`[Build:]`** argument, which allows you to verify the existence of a specific version number associated with an installed program or executable file. To use this argument, you must specify it at the right side of a provided `VerifyInstall` value, then insert a version number on the right side of its colon. Take the following as an example:

```xml
<VerifyInstall>[Vers_Product]C:\example_file.exe[Build:1.0]</VerifyInstall>
```

However, unlike the `OperatingSystem` parameter, whatever `[Build:]` version number is specified must be identical to the version number of an installed program or executable file.

##### [Vers_] Subparameters

To utilize the **`[Vers_*]`** subparameters, you will need to retrieve the file or product version numbers from an executable file. To do so:

  - Within PowerShell, invoke the following command:

    ```powershell
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\example_file.exe") | Select FileVersion, ProductVersion
    ```

  - And you will notice the following output:

    ```
    FileVersion       ProductVersion
    -----------       --------------
    1.0               1.0
    ```

  - Then, specify either outputted value inside the `[Build:]` argument in the following manner:

    ```xml
    <VerifyInstall>[Vers_File]C:\example_file.exe[Build:1.0]</VerifyInstall>

    <VerifyInstall>[Vers_File]$env:SYSTEMDRIVE\example_file.exe[Build:1.0]</VerifyInstall>

    <VerifyInstall>[Vers_Product]C:\example_file.exe[Build:1.0]</VerifyInstall>
    ```

##### [Program] Subparameter

To utilize the **`[Program]`** subparameter, you can verify the existence of a:

- **Product Code**:

  - Open the `Programs and Features` applet of the Windows Control Panel, and retrieve the name of the installed program you wish to verify the existence of:

    ![Programs and Features](/readme/example_verifyinstall_program.gif)

  - Within PowerShell, enter the following command:

    ```powershell
    Get-ChildItem HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall | % {Get-ItemProperty $_.PSPath} | ? {$_.DisplayName -eq "Example Program"} | Select PSChildName
    ```

  - Within PowerShell, enter the following command, if you're utilizing a x86 program on an AMD64 system:

    ```powershell
    Get-ChildItem HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall | % {Get-ItemProperty $_.PSPath} | ? {$_.DisplayName -eq "Example Program"} | Select PSChildName
    ```

  - And you will notice the following output:

    ```
    PSChildName
    -----------
    {00000000-0000-0000-0000-000000000000}
    ```

  - Then, specify the outputted value in this fashion:

    ```xml
    <VerifyInstall>[Program]{00000000-0000-0000-0000-000000000000}</VerifyInstall>
    ```

  - Or if you wish to verify the existence an installed program's respective version number along with its product code:

    ```xml
    <VerifyInstall>[Program]{00000000-0000-0000-0000-000000000000}[Build:1.0]</VerifyInstall>
    ```

- **Program Name**:

  - Open the `Programs and Features` applet of the Windows Control Panel, and retrieve the name of the installed program you wish to verify the existence of:

    ![Programs and Features](/readme/example_verifyinstall_program.gif)

  - Then, specify a program name in this fashion:

    ```xml
    <VerifyInstall>[Program]Example Program</VerifyInstall>
    ```

  - Or if you wish to verify the existence an installed program's respective version number along with its name:

    ```xml
    <VerifyInstall>[Program]Example Program[Build:1.0]</VerifyInstall>
    ```

##### Examples

Here are other valid example use cases of the `VerifyInstall` parameter and its respective subparameters:

```xml
<VerifyInstall>[Hotfix]KB0000000</VerifyInstall>

<VerifyInstall>[Path]C:\example_file.exe</VerifyInstall>

<VerifyInstall>[Path]C:\example_directory</VerifyInstall>

<VerifyInstall>[Path]C:\example directory with whitespace</VerifyInstall>

<VerifyInstall>[Path]$env:SYSTEMDRIVE\example_directory</VerifyInstall>

<VerifyInstall>[Path]HKLM:\registry_path</VerifyInstall>

<VerifyInstall>[Path]env:\ENVIRONMENT_VARIABLE</VerifyInstall>
```

#### `SkipProcessCount`

> - **Required**: No
> - **Purpose**: Specify as to whether or not a processed task entry should be counted as such and contribute to the overall total of processed task entries, whether it succeeds or fails.

When explicitly utilizing the `SkipProcessCount` parameter and specifying the following value:

Value             | Result
-----             | ------
`true`            | `powerpkg.ps1` will not count a processed task entry as such.
`false` (Default) | `powerpkg.ps1` will count a processed task entry as such.

And specify your desired value in this fashion:

```xml
<SkipProcessCount>true</SkipProcessCount>
```

## Debugging

### Exit Codes

Code | Description
---- | -----------
1    | A task entry terminated with a non-zero exit code.
2    | An exception rose from a task entry during its executable invocation process.
3    | Initial task entry processing failed.
4    | A host has been prevented from processing a package.
5    | A package file was not found.
6    | No task entries were processed.
7    | A task entry is missing a required value.

## License

powerpkg is licensed under the MIT license. For more information regarding this license, refer to the `LICENSE` file located at the root of this repository.

## Additional Comments

```
 ________  ________  ___       __   _______   ________  ________  ___  __    ________
|\   __  \|\   __  \|\  \     |\  \|\  ___ \ |\   __  \|\   __  \|\  \|\  \ |\   ____\
\ \  \|\  \ \  \|\  \ \  \    \ \  \ \   __/|\ \  \|\  \ \  \|\  \ \  \/  /|\ \  \___|
 \ \   ____\ \  \\\  \ \  \  __\ \  \ \  \_|/_\ \   _  _\ \   ____\ \   ___  \ \  \  ___  
  \ \  \___|\ \  \\\  \ \  \|\__\_\  \ \  \_|\ \ \  \\  \\ \  \___|\ \  \\ \  \ \  \|\  \
   \ \__\    \ \_______\ \____________\ \_______\ \__\\ _\\ \__\    \ \__\\ \__\ \_______\
    \|__|     \|_______|\|____________|\|_______|\|__|\|__|\|__|     \|__| \|__|\|_______|
```

Fellow PowerShell enthusiasts, this is my contribution to the community. I hope you take advantage of this project I have worked very hard on. You guys rock!
