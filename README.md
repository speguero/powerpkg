# powerpkg

A Windows application deployment script with an emphasis on simplicity and standardization.

## Section
1. [Requirement](#requirement)
2. [Philosophy](#philosophy)
3. [Package File](#package-file)
  - [TaskName](#taskname)
  - [Executable](#executable)
  - [OperatingSystem](#operatingsystem)
  - [Architecture](#architecture)
  - [TerminateProcess](#terminateprocess)
  - [TerminateMessage](#terminatemessage)
  - [SuccessExitCode](#successexitcode)
  - [ContinueIfFail](#continueiffail)
  - [VerifyInstall](#verifyinstall)
4. [Script Configuration](#script-configuration)
5. [Debugging](#debugging)

## Requirement

Before reading through this documentation, please note that a minimum of **PowerShell 2.0** is required to utilize this project. However, PowerShell 3.0+ is recommended.

## Philosophy

**One** script to perform **all** functions.

The sole purpose of `powerpkg` is to enable maintainability when managing application deployments on the Windows platform. This allows an administrator to consolidate an unsustainable collection of unique scripts as one PowerShell script.

## Getting Started

Firstly, consider the following recommended package structure:

```
+-- /example_package
    |
    |-- install
    |   |
    |   |-- package.json
    |   |-- package.csv
    |   |-- powerpkg.conf
    |   +-- powerpkg.ps1
    |
    +-- uninstall
        |
        |-- package.json
        |-- package.csv
        |-- powerpkg.conf
        +-- powerpkg.ps1
```

Here, we have directory `example_package`. In this case, it is associated with a specific application and solely a placeholder for two packages located within it, `install` and `uninstall`.

As you may have noticed, both packages serve a unique purpose in relation to `example_package`. Within these packages are individual package files, `package.json` and `package.csv`, that contain specific instructions that the accompanying script, `powerpkg.ps1`, processes. *Modifying the script itself is not necessary.*

## Package File

Package files consist of desired instructions, or task entries, that are processed by `powerpkg.ps1` at runtime.

> **NOTE**: You may have noticed that this project features both JSON (`package.json`) and CSV (`package.csv`) package files. Unfortunately, usage of `package.csv` is required for Windows systems utilizing PowerShell 2.0, as JSON support is nonexistent on said systems.
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
        "VerifyInstall": ""
    }
]
```

**CSV** (PowerShell 2.0):

```
TaskName,Executable,OperatingSystem,Architecture,TerminateProcess,TerminateMessage,SuccessExitCode,ContinueIfFail,VerifyInstall
,,,,,,,,
```

For more information on the variety of paramaters utilized within a task entry, refer to the Package File segment of [Section](#section) for a list of said parameters, or review the following information below:

#### `TaskName`

- **Required**: Yes
- **Purpose**: A name of an individual task entry.
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
- **Purpose**: An executable file or MS-DOS command to invoke.
- **Subparamaters**:

Subparameter     | Description
------------     | -----------
`[LocalFile]`    | Specifies a file located within a package directory.

- **Usage**:

```json
[
    {
        "Executable": "mspaint.exe"
    }
]
```

```json
[
    {
        "Executable": "msiexec.exe /i \"[LocalFile]example.msi\" /qn /norestart"
    }
]
```

```json
[
    {
        "Executable": "\"[LocalFile]example.exe\""
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
- **Purpose**: Non-zero exit codes that also determine a successful task entry.
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

By default, an unsuccessful task entry will cause `powerpkg.ps1` to fail. When explicitly utilizing the `ContinueIfFail` parameter and specifying the following value:

Value | Result
----- | ------
True  | `powerpkg.ps1` will continue processing remaining task entires.
False | `powerpkg.ps1` will fail.

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

When utilizing the `VerifyInstall` parameter, you must specify one of the following subparamaters mentioned above.

As you may have noticed, certain parameters take advantage of a `[Build:]` argument, which allows you to verify the existence of a specific version number associated with an installed program or executable file. To use this argument, you must specify it at the right side of a provided `VerifyInstall` value, then insert a version number on the right side of its colon. Take the following as an example:

```json
[
    {
        "VerifyInstall": "[Vers_Product]C:\\example_file.exe[Build:1.0]"
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
        "VerifyInstall": "[Vers_File]C:\\example_file.exe[Build:1.0]"
    },
    {
        "VerifyInstall": "[Vers_Product]C:\\example_file.exe[Build:1.0]"
    },
    {
        "VerifyInstall": "[Program]{00000000-0000-0000-0000-000000000000}"
    },
    {
        "VerifyInstall": "[Program]{00000000-0000-0000-0000-000000000000}[Build:1.0]"
    },
    {
        "VerifyInstall": "[Program]Example Program Name"
    },
    {
        "VerifyInstall": "[Program]Example Program Name[Build:1.0]"
    }
]
```

## Script Configuration

The script configuration file (`powerpkg.conf`) is not required for the utilization of `powerpkg.ps1`.

Type                 | Value  | Description
----                 | -----  | -----------
BlockHost            | `Null` | Prevents specified hosts from processing package files.
PackageName          | `Null` | Allows specifying a different package name apart from the name of the directory a package resides in.
SuppressNotification | `True` | Prevents a balloon notification from displaying upon a successful deployment. A value of `False` in `powerpkg.conf` changes this behavior.

## Debugging

### Exit Codes:

Code | Description
---- | -----------
1    | A task entry terminated with a non-zero exit status.
2    | An exception rose from a task entry.
3    | Initial task entry processing failed.
4    | A host has been blocked from processing package files.
5    | A package file was not found.
6    | No task entries were processed.
7    | A task entry is missing required information.
