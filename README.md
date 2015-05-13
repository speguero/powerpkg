# powerpkg

A Windows package deployment script with an emphasis on simplicity and standardization.

As you may notice, there isn't much documentation on this particular project, but please stick around, as there is more work to be done before documentation can come into play.

## Configuration:

The script configuration file (`powerpkg.conf`) is not required for the utilization of `powerpkg.ps1`.

### Default Settings:

Type                 | Value  | Description
----                 | -----  | -----------
SuppressNotification | `True` | Prevents a balloon notification from displaying upon a successful deployment. A value of `False` in `powerpkg.conf` changes this behavior.
BlockHost            | `Null` | Prevents specified hosts from processing package files.

## Debugging:

### Exit Codes:

Code | Description
---- | -----------
1    | A task entry terminated with a non-zero exit status.
2    | An exception rose from a task entry.
4    | A host has been blocked from processing package files.
5    | A package file was not found.
6    | No task entries were processed.
7    | A task entry is missing required information.
