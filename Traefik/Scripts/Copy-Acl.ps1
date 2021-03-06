<#
.SYNOPSIS 
Copy the ACL from one file to other files

.DESCRIPTION
Takes a file and copies its ACL to one or more other files.

.PARAMETER FromPath
Path of the File to get the ACL from.

.PARAMETER Destination
Path to one or more files to copy the ACL to.

.PARAMETER Passthru
Returns an object representing the security descriptor.  By default, this cmdlet does not generate any output.

.INPUTS
You can Pipeline any object with a Property named "PSPath", "FullName" or "Destination".

.EXAMPLE
PS> Copy-Acl Referencefile.txt (dir c:\temp\*xml)

.EXAMPLE
PS> dir c:\files *.xml -recurse | Copy-Acl ReferenceFile.txt

.LINK
Get-Acl
Set-Acl

.NOTES
Author:  Jeffrey Snover

#>
#requires -Version 2.0
[CmdletBinding(SupportsShouldProcess=$true)]
param(
[Parameter(position=0,Mandatory=$true)]
[String]$FromPath,

[Parameter(Position=1,Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
[Alias("PSpath","fullname")]
[String[]]$Destination,

[Parameter(Mandatory=$false)]
[Switch]$PassThru
)
Begin
{
    if (! (Test-Path $FromPath))
    {
        $ErrorRecord = New-Object System.Management.Automation.ErrorRecord  (
            (New-Object Exception "FromPath ($fromPath) does not point to an existing object"),
            "Copy-Acl.TestPath",
            "ObjectNotFound",
            $FromPath
         )

        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    $acl = Get-Acl $FromPath
}
Process
{
    foreach ($Dest in @($Destination))
    {
        if ($pscmdlet.ShouldProcess($Dest))
        {
            Set-Acl -Path $Dest -AclObject $acl -Passthru:$PassThru
        }
    }
}
