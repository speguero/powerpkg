# powerpkg

A Windows application deployment script with an emphasis on simplicity and standardization.

## Section
1. [Requirement](#requirement)
2. [Philosophy](#philosophy)
3. [Package File](#package-file)
4. [Script Configuration](#script-configuration)
5. [Example Usage](#example-usage)
7. [Debugging](#debugging)

## Requirement

Before reading through this documentation, please note that a minimum of **PowerShell 2.0** is required to utilize this project. However, PowerShell 3.0+ is recommended.

## Philosophy

**One** script to perform **all** functions.

The sole purpose of `powerpkg` is to enable maintainability when managing application deployments on the Windows platform. This allows an administrator to consolidate an unsustainable collection of unique scripts into one PowerShell script.

Modifying the script itself is not necessary, as it processes custom instructions, or `task entries`, in an accompanying JSON and/or CSV `package file`, leaving the original codebase of said script intact.

However, `powerpkg` was purposely designed to process one package file per directory. For this reason, a package file should only fulfill one specific purpose, such as performing the installation of an application, and remain accompanied by a replicated variant of the script inside a separate directory, forming a `package`.

## Package File

#### TaskName

#### Executable

Parameter     | Description                                        | Example Value
---------     | -----------                                        | -------------
`[LocalFile]` | Allows specifying a file located within a package. | `[LocalFile]file.exe`

#### OperatingSystem

#### InstructionSet

#### TerminateProcess

#### TerminateMessage

#### SuccessExitCode

#### ContinueIfFail

#### VerifyInstall

Parameter        | Description | Example Value
---------        | ----------- | -------------
`[Hotfix]`       |             |
`[Path]`         |             |
`[Vers_File]`    |             |
`[Vers_Product]` |             |
`[Program]`      |             |

## Script Configuration

The script configuration file (`powerpkg.conf`) is not required for the utilization of `powerpkg.ps1`.

Type                 | Value  | Description
----                 | -----  | -----------
BlockHost            | `Null` | Prevents specified hosts from processing package files.
PackageName          | `Null` | Allows specifying a different package name apart from the name of the directory a package resides in.
SuppressNotification | `True` | Prevents a balloon notification from displaying upon a successful deployment. A value of `False` in `powerpkg.conf` changes this behavior.

## Example Usage

Consider the following recommended package structure:

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

As you may have noticed, both packages serve a unique purpose in relation to `example_package`. Within these packages are individual package files, `package.json` and `package.csv`, that contain specific instructions that the accompanying script, `powerpkg.ps1`, processes.

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
