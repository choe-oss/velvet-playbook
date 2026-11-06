function Write-SetupProgress {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] [$ScriptName] $Message"
}
