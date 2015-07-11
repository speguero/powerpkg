# powerpkg

![Header](/readme/header.gif)

A monolithic Windows package deployment script with an emphasis on simplicity, maintainability, and standardization. Written in PowerShell.

## Section
1. [Requirement](#requirement)
2. [Philosophy](#philosophy)
3. [Getting Started](#getting-started)
4. [How It Works](#how-it-works)
5. [Package File](#package-file)
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
6. [Script Configuration](#script-configuration)
7. [Debugging](#debugging)
8. [License](#license)
9. [Additional Comments](#additional-comments)

## Requirement

Before reading through this documentation, please note that a minimum of **PowerShell 2.0** is required to utilize this project. However, PowerShell 3.0 or higher is recommended.

## Philosophy

**One** script to perform **all** functions.

The sole purpose of powerpkg is to enable maintainability when managing package deployments on the Windows platform. This allows an administrator to consolidate an unsustainable collection of unique scripts into one PowerShell script.

## Getting Started

To begin test driving powerpkg:

**(1)**: Clone this repository or download it as a ZIP file.

**(2)**: Invoke `powerpkg.ps1`:
```shell
powershell.exe -ExecutionPolicy Unrestricted -File "example_package\powerpkg.ps1"
```

**(3)**: *And that's it!*

> **NOTE**:
>
> For more information on the usage of both `package.json` and `package.csv`, refer to the [Package File](#package-file) segment of this README.
>
> To discover basic usage of powerpkg, refer to the [How It Works](#how-it-works) segment of this README.

## How It Works

**(1)**: Create one of the following [package files](#package-file):

  - **`package.json` (PowerShell 3.0+):**
  ```json
  [
      {
          "TaskName": "Example Task Entry",
          "Executable": "powershell.exe -NoProfile Write-Host \"Hello, World!\""
      }
  ]
  ```
  
  - **`package.csv` (PowerShell 2.0):**
  ```
  TaskName,Executable
  "Example Task Entry","powershell.exe -NoProfile Write-Host ""Hello, World!"""
  ```

**(2)**: Create `powerpkg.conf`, the script configuration file, with the following content:
```
BlockHost
PackageName "Example Package"
SuppressNotification False
```

**(3)**: Invoke `powerpkg.ps1`:
```shell
powershell.exe -ExecutionPolicy Unrestricted -File "powerpkg.ps1"
```

**(4)**: As `powerpkg.ps1` is running, you will notice output similar to the following example:
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
[powershell.exe -NoProfile Write-Host "Hello, World!"]

Hello, World!

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
**(5)**: *And that's it!*

> **NOTE**:
>
> To discover in-depth usage of powerpkg, refer to the [Package File](#package-file) and [Script Configuration](#script-configuration) segments of this README.
>
> To further familiarize yourself with powerpkg and how it works, examining the contents of the `\example_package` directory is highly recommended.

## Package File

Package files consist of specific instructions, or task entries, that are processed by `powerpkg.ps1` at runtime.

> **NOTE**:
>
> You may have noticed that this project features both JSON (`package.json`) and CSV (`package.csv`) package files. Unfortunately, usage of `package.csv` is required for Windows systems utilizing PowerShell 2.0, as JSON support is nonexistent on said systems.
>
> If you are using PowerShell 3.0 or higher, ``package.csv`` is not required and can be deleted.

Specific instructions are stored in the form of task entries, which are presented in the following fashion:

**JSON** (PowerShell 3.0+):

```json
[
    {
        "TaskName": "",
        "Executable": "",
        "OperatingSystem": "",
        "Architecture": "",
        "TerminateProcess": "",
        "TerminateMessage": "",
        "SuccessExitCode": "",
        "ContinueIfFail": "",
        "VerifyInstall": "",
        "SkipProcessCount": ""
    }
]
```

**CSV** (PowerShell 2.0):

```
TaskName,Executable,OperatingSystem,Architecture,TerminateProcess,TerminateMessage,SuccessExitCode,ContinueIfFail,VerifyInstall,SkipProcessCount
"","","","","","","","","",""
```

For more information on the variety of parameters utilized within a task entry, refer to the Package File segment of [Section](#section) for a list of said parameters, or review the following information below:

#### `TaskName`

- **Required**: Yes
- **Purpose**: A name for an individual task entry.
- **Usage**:

```json
[
    {
        "TaskName": "Install Program"
    }
]
```

#### `Executable`

- **Required**: Yes
- **Purpose**: An executable file/path to invoke.
- **Subparamaters**:

Subparameter | Description
------------ | -----------
`[Package]`  | Allows for specifying a file or directory located within a package directory.

- **Usage**:

> **NOTE**:
>
> **Before calling `powershell.exe`, ensure to specify the `-NoProfile` parameter (`powershell.exe -NoProfile Example-Command`), to minimize the risk of arbitrary code execution.**

***Whitespace and Quotation Marks***

When specifying an executable path or arguments containing whitespace, it is recommended to surround such text with double quotation marks. An individual quotation mark should be escaped in the following manner:

Quotation Mark | Package File Type
-------------- | -----------------
`\"`           | JSON
`""`           | CSV

For individual file and/or directory names containing whitespace, such items should be surrounded by **single** quotation marks. Example: `\"[Package]'an example.ps1'\"`

It is also recommended to always surround files and/or directories specified with the `[Package]` parameter with double quotation marks, to prevent I/O exceptions from being thrown with the usage of whitespace within the directory path of a package directory.
 
***Environment Variables***

Unfortunately, at this time, powerpkg does not support the independent usage of environment variables. However, as a workaround, you can:

- Call `cmd.exe` in the following manner: `cmd.exe /c notepad.exe %SYSTEMDRIVE%\test.txt`.
- Call `powershell.exe` in the following manner: `powershell.exe Start-Process -FileName notepad.exe -ArgumentList $env:SYSTEMDRIVE\test.txt -Wait`.

Here are some valid example use cases of the `Executable` parameter:

```json
[
    {
        "Executable": "ipconfig.exe"
    },
    {
        "Executable": "msiexec.exe /i \"[Package]example.msi\" /qn /norestart"
    },
    {
        "Executable": "\"[Package]example.exe\""
    },
    {
        "Executable": "\"[Package]example_directory\\'example file with whitespace.exe'\""
    }
]
```

#### `OperatingSystem`

- **Required**: No
- **Purpose**: The operating system a task entry should be processed under.
- **Usage**:

When utilizing this parameter, you will want to specify the NT kernel version number of a specific Windows operating system:

Windows Operating System | NT Kernel Version
------------------------ | -----------------
10                       | 10.0
8.1                      | 6.3
8                        | 6.2
7                        | 6.1
Vista                    | 6.0

And specify a NT kernel version number in this fashion:

```json
[
    {
        "OperatingSystem": "6.3"
    }
]
```

> **NOTE**:
>
> Because the `OperatingSystem` parameter determines to find a match between a specified value (`6.1`) and the complete version number of a Windows operating system (`6.1.7601`), the value of `6.1.7601`, which indicates a specific build of Windows 7, can be specified, as well.

#### `Architecture`

- **Required**: No
- **Purpose**: The userspace architecture a task entry should be processed under.
- **Usage**:

For executable invocations that depend on a specific architectural environment, you will want to specify the following for:

**AMD64** (x64 in Microsoft terminology) environments:

```json
[
    {
        "Architecture": "AMD64"
    }
]
```

**x86** environments:

```json
[
    {
        "Architecture": "x86"
    }
]
```

#### `TerminateProcess`

- **Required**: No, except when utilizing the `TerminateMessage` parameter.
- **Purpose**: A process, or list of process, to terminate prior to executable invocation.
- **Usage**:

```json
[
    {
        "TerminateProcess": "explorer"
    },
    {
        "TerminateProcess": "explorer,notepad"
    }
]
```

#### `TerminateMessage`

- **Required**: No
- **Purpose**: A message to display to an end-user prior to the termination of processes. Used in conjunction with the `TerminateProcess` parameter.
- **Usage**:

```json
[
    {
        "TerminateProcess": "explorer",
        "TerminateMessage": "File Explorer will terminate. When prepared, click on the OK button."
    }
]
```

#### `SuccessExitCode`

- **Required**: No
- **Purpose**: Non-zero exit codes that also determine a successful task entry. Used in conjunction with the exit code of `0`, so manually specifying such a value is unnecessary. 
- **Usage**:

```json
[
    {
        "SuccessExitCode": "10"
    },
    {
        "SuccessExitCode": "10,777,1000"
    }
]
```

#### `ContinueIfFail`

- **Required**: No
- **Purpose**: Specify as to whether or not to continue with remaining task entires if a specific task entry fails.
- **Usage**:

When explicitly utilizing the `ContinueIfFail` parameter and specifying the following value:

Value           | Result
-----           | ------
True            | `powerpkg.ps1` will continue processing remaining task entires. A task entry set to continue when resulting in a non-zero exit code will not alter the exit code of `powerpkg.ps1`.
False (Default) | `powerpkg.ps1` will fail and result in a non-zero exit code.

And specify your desired value in this fashion:

```json
[
    {
        "ContinueIfFail": "true"
    }
]
```

#### `VerifyInstall`

- **Required**: No
- **Purpose**: Skip a task entry if a program, hotfix, file/directory path, or a specific version of an executable file exist.
- **Subparamaters**:

Subparameter     | Description                                                        | Additional Arguments | Additional Arguments Required?
------------     | -----------                                                        | -------------------- | ------------------------------
`[Hotfix]`       | Verify the existence of a hotfix.                                  |                      |
`[Path]`         | Verify the existence of a file or directory path.                  |                      |
`[Vers_File]`    | Verify the file version of an executable file.                     | `[Build:]`           | Yes
`[Vers_Product]` | Verify the product version of an executable file.                  | `[Build:]`           | Yes
`[Program]`      | Verify the existence of an installed program name or product code. | `[Build:]`           | No

- **Usage**:

> **NOTE**:
>
> When utilizing the `VerifyInstall` parameter, you **must** specify one of the following subparamaters mentioned above.
>
> The usage of PowerShell environment variables, such as `$env:SYSTEMDRIVE`, is supported by the `VerifyInstall` parameter.
>
> The usage of quotation marks is not a requirement, even for paths that contain whitespace.

***[Build:] Argument***

As you may have noticed, certain parameters take advantage of a **`[Build:]`** argument, which allows you to verify the existence of a specific version number associated with an installed program or executable file. To use this argument, you must specify it at the right side of a provided `VerifyInstall` value, then insert a version number on the right side of its colon. Take the following as an example:

```json
[
    {
        "VerifyInstall": "[Vers_Product]C:\\example_file.exe[Build:1.0]"
    }
]
```

However, unlike the `OperatingSystem` parameter, whatever `[Build:]` version number is specified must be identical to the version number of an installed program or executable file.

***[Vers_] Subparameters***

To utilize the **`[Vers_*]`** subparameters, you will need to retrieve the file or product version numbers from an executable file. To do so:

  - Invoke the following command:

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
  ```json
  [
      {
          "VerifyInstall": "[Vers_File]C:\\example_file.exe[Build:1.0]"
      },
      {
          "VerifyInstall": "[Vers_File]$env:SYSTEMDRIVE\\example_file.exe[Build:1.0]"
      },
      {
          "VerifyInstall": "[Vers_Product]C:\\example_file.exe[Build:1.0]"
      }
  ]
  ```

***[Program] Subparameter***

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
  ```json
  [
      {
          "VerifyInstall": "[Program]{00000000-0000-0000-0000-000000000000}"
      }
  ]
  ```

  - Or if you wish to verify the existence an installed program's respective version number along with its product code:
  ```json
  [
      {
          "VerifyInstall": "[Program]{00000000-0000-0000-0000-000000000000}[Build:1.0]"
      }
  ]
  ```

- **Program Name**:
  - Open the `Programs and Features` applet of the Windows Control Panel, and retrieve the name of the installed program you wish to verify the existence of:
  ![Programs and Features](/readme/example_verifyinstall_program.gif)

  - Then, specify a program name in this fashion:
  ```json
  [
      {
          "VerifyInstall": "[Program]Example Program"
      }
  ]
  ```

  - Or if you wish to verify the existence an installed program's respective version number along with its name:
  ```json
  [
      {
          "VerifyInstall": "[Program]Example Program[Build:1.0]"
      }
  ]
  ```

Here are more valid example use cases of the `VerifyInstall` parameter and its respective subparameters:

```json
[
    {
        "VerifyInstall": "[Hotfix]KB0000000"
    },
    {
        "VerifyInstall": "[Path]C:\\example_file.exe"
    },
    {
        "VerifyInstall": "[Path]C:\\example_directory"
    },
    {
        "VerifyInstall": "[Path]C:\\example directory with whitespace"
    },
    {
        "VerifyInstall": "[Path]$env:SYSTEMDRIVE\\example_directory"
    },
    {
        "VerifyInstall": "[Path]HKLM:\\registry_path"
    },
    {
        "VerifyInstall": "[Path]env:\\ENVIRONMENT_VARIABLE"
    }
]
```

#### `SkipProcessCount`

- **Required**: No
- **Purpose**: Specify as to whether or not a processed task entry should be counted as such and contribute to the overall total of processed task entries, whether it succeeds or fails.
- **Usage**:

When explicitly utilizing the `SkipProcessCount` parameter and specifying the following value:

Value           | Result
-----           | ------
True            | `powerpkg.ps1` will not count a processed task entry as such.
False (Default) | `powerpkg.ps1` will count a processed task entry as such.

And specify your desired value in this fashion:

```json
[
    {
        "SkipProcessCount": "true"
    }
]
```

## Script Configuration

The script configuration file (`powerpkg.conf`) is not required for the utilization of `powerpkg.ps1`. When `powerpkg.conf` is nonexistent, the default values for the following parameters below are used:

Parameter            | Description                                                                                                             | Default Value | Example Value
---------            | -----------                                                                                                             | ------------- | -------------
BlockHost            | Prevents specified hosts from processing a package.                                                                     | `Null`        | `examplehost1`, `examplehost1,examplehost2`
PackageName          | Allows specifying a different package name apart from the name of the directory a package resides in.                   | `Null`        | `"Example Package"`
SuppressNotification | Prevents a balloon notification from displaying upon a successful deployment. A value of `False` changes this behavior. | `True`        | `True`, `False`

## Debugging

#### Exit Codes:

Code | Description
---- | -----------
1    | A task entry terminated with a non-zero exit code.
2    | An exception rose from a task entry during its executable invocation process.
3    | Initial task entry processing failed.
4    | A host has been blocked from processing a package.
5    | A package file was not found.
6    | No task entries were processed.
7    | A task entry is missing required information.

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

