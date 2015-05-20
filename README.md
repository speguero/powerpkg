# powerpkg

A Windows application deployment script with an emphasis on simplicity and standardization.

## Requirement

Before reading through this documentation, please note that a minimum of **PowerShell 2.0** is required to utilize this project. However, PowerShell 3.0+ is recommended.

## Philosophy

**One** script to perform **all** functions.

The sole purpose of `powerpkg` is to enable maintainability when managing application deployments on the Windows platform. This allows an administrator to consolidate an unsustainable collection of unique scripts into one PowerShell script.

Modifying the script itself is not necessary, as it processes custom instructions, or `task entries`, in an accompanying JSON and/or CSV `package file`, leaving the original codebase of said script intact.

However, `powerpkg` was purposely designed to process one package file per directory. For this reason, a package file should only fulfill one specific purpose, such as performing the installation of an application, and remain accompanied by a replicated variant of the script inside a separate directory, forming a `package`.

## How It Works

Consider the following package structure example:

```
/collection
|
|-- /example_package1
|   |
|   |-- install
|   |   |
|   |   |-- package.json
|   |   |-- package.csv
|   |   |-- powerpkg.conf
|   |   +-- powerpkg.ps1
|   |
|   |-- uninstall
|   |
|   |-- package.json
|   |-- package.csv
|   |-- powerpkg.conf
|   +-- powerpkg.ps1
|
+-- /example_package2
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

## Default Script Configuration

The script configuration file (`powerpkg.conf`) is not required for the utilization of `powerpkg.ps1`.

Type                 | Value  | Description
----                 | -----  | -----------
BlockHost            | `Null` | Prevents specified hosts from processing package files.
PackageName          | `Null` | Allows specifying a different package name apart from the name of the directory a package resides in.
SuppressNotification | `True` | Prevents a balloon notification from displaying upon a successful deployment. A value of `False` in `powerpkg.conf` changes this behavior.

## Package File Creation

## Results

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
