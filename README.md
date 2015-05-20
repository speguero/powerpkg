# powerpkg

A Windows application deployment script with an emphasis on simplicity and standardization.

## Sections:
1. [Requirement](#requirement)
2. [Philosophy](#philosophy)
3. [Package File](#package-file)
4. [Script Configuration File](#script-configuration-file)
5. [Package Directory Structure](#package-directory-structure)
6. [Result](#result)
7. [Debugging](#debugging)

## Requirement

Before reading through this documentation, please note that a minimum of **PowerShell 2.0** is required to utilize this project. However, PowerShell 3.0+ is recommended.

## Philosophy

**One** script to perform **all** functions.

The sole purpose of `powerpkg` is to enable maintainability when managing application deployments on the Windows platform. This allows an administrator to consolidate an unsustainable collection of unique scripts into one PowerShell script.

Modifying the script itself is not necessary, as it processes custom instructions, or `task entries`, in an accompanying JSON and/or CSV `package file`, leaving the original codebase of said script intact.

However, `powerpkg` was purposely designed to process one package file per directory. For this reason, a package file should only fulfill one specific purpose, such as performing the installation of an application, and remain accompanied by a replicated variant of the script inside a separate directory, forming a `package`.

## Package File

## Script Configuration

The script configuration file (`powerpkg.conf`) is not required for the utilization of `powerpkg.ps1`.

Type                 | Value  | Description
----                 | -----  | -----------
BlockHost            | `Null` | Prevents specified hosts from processing package files.
PackageName          | `Null` | Allows specifying a different package name apart from the name of the directory a package resides in.
SuppressNotification | `True` | Prevents a balloon notification from displaying upon a successful deployment. A value of `False` in `powerpkg.conf` changes this behavior.

## Package Directory Structure

Consider the following recommended package structure:

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

Within this collection, we have directory `example_package1`, which is associated with one particular application. However, within it lies two packages, `install` and `uninstall`. Both packages perform two different functions for `example_package1`. Within these packages are individual package files that hold specific instructions for their accompanying script, `powerpkg.ps1`, to process.

The same is true for directory `example_package2`.

## Result

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
