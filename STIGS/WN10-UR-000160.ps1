<#
.SYNOPSIS
    This PowerShell script ensures that The Restore files and directories user right must only be assigned to the Administrators group. Inappropriate granting of user rights can provide system, administrative, and other high level capabilities. Accounts with the "Restore files and directories" user right can circumvent file and directory permissions and could allow access to sensitive data. It could also be used to over-write more current data.
.NOTES
    Author          : Cherine Joseph
    LinkedIn        : linkedin.com/in/cherine-joseph
    GitHub          : github.com/cherinejoseph
    Date Created    : 2025-07-31
    Last Modified   : 2025-07-31
    Version         : 1.0
    CVEs            : N/A
    Plugin IDs      : N/A
    STIG-ID         : WN10-UR-000160

.TESTED ON
    Date(s) Tested  : 2025-07-31
    Tested By       : Cherine Joseph
    Systems Tested  : Windows 10
    PowerShell Ver. : PowerShell ISE

.USAGE
    Please download the script and execute as administrator. 
    Example syntax:
    PS C:\> .\STIG-ID-WN10-UR-000160-Remediation.ps1
#>

# Enable verbose output
$VerbosePreference = "Continue"

# Function to log messages
function Log-Message {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )
    switch ($Level) {
        "INFO"  { Write-Host "[INFO] $Message" -ForegroundColor Green }
        "WARN"  { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[ERROR] $Message" -ForegroundColor Red }
    }
}

# Function to verify administrative privileges
function Check-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log-Message "This script must be run as an Administrator. Exiting." "ERROR"
        exit 1
    }
}

# Function to get current policy configuration
function Get-CurrentPolicy {
    param ([string]$PolicyName)
    try {
        Log-Message "Retrieving current policy settings for '$PolicyName'..." "INFO"
        $policyOutput = secedit /export /areas USER_RIGHTS /cfg "$env:TEMP\SecurityConfig.inf" | Out-Null
        $policyLines = Get-Content "$env:TEMP\SecurityConfig.inf"
        $policySetting = $policyLines | Where-Object { $_ -match "^$PolicyName\s*=" } | ForEach-Object { ($_ -split "=")[1].Trim() }
        Remove-Item "$env:TEMP\SecurityConfig.inf" -Force
        return $policySetting
    } catch {
        Log-Message "Failed to retrieve current policy configuration. Error: $_" "ERROR"
        exit 1
    }
}

# Function to set the policy
function Set-Policy {
    param (
        [string]$PolicyName,
        [string]$Accounts
    )
    try {
        Log-Message "Configuring policy '$PolicyName' to include: $Accounts..." "INFO"
        $tempInf = "$env:TEMP\UpdatedSecurityConfig.inf"
        $tempSdb = "$env:TEMP\Security.sdb"

        # Export current settings
        secedit /export /areas USER_RIGHTS /cfg $tempInf | Out-Null

        # Modify the policy in the INF file
        (Get-Content $tempInf) -replace "($PolicyName\s*=).*", "`$1 $Accounts" | Set-Content $tempInf

        # Apply the updated policy
        secedit /configure /db $tempSdb /cfg $tempInf /areas USER_RIGHTS | Out-Null

        # Clean up temporary files
        Remove-Item $tempInf, $tempSdb -Force
        Log-Message "Policy '$PolicyName' updated successfully." "INFO"
    } catch {
        Log-Message "Failed to update policy '$PolicyName'. Error: $_" "ERROR"
        exit 1
    }
}

# Function to verify the updated policy
function Verify-Policy {
    param (
        [string]$PolicyName,
        [string]$ExpectedAccounts
    )
    $currentPolicy = Get-CurrentPolicy -PolicyName $PolicyName
    if ($currentPolicy -eq $ExpectedAccounts) {
        Log-Message "Verification successful: '$PolicyName' is correctly set to '$ExpectedAccounts'." "INFO"
        return $true
    } else {
        Log-Message "Verification failed: '$PolicyName' is set to '$currentPolicy', expected '$ExpectedAccounts'." "ERROR"
        return $false
    }
}

# Main Script Execution
Check-AdminPrivileges

$PolicyName = "SeRestorePrivilege"  # Internal name for "Restore files and directories"
$Accounts = "*S-1-5-32-544"         # SID for the Administrators group

# Step 1: Retrieve current policy settings
$currentPolicy = Get-CurrentPolicy -PolicyName $PolicyName

if ($null -eq $currentPolicy) {
    Log-Message "'Restore files and directories' policy is not currently set." "WARN"
} else {
    Log-Message "Current 'Restore files and directories' policy: $currentPolicy" "INFO"
}

# Step 2: Set the policy
Set-Policy -PolicyName $PolicyName -Accounts $Accounts

# Step 3: Verify the updated policy
if (-not (Verify-Policy -PolicyName $PolicyName -ExpectedAccounts $Accounts)) {
    Log-Message "Failed to verify updated policy. Exiting." "ERROR"
    exit 1
}

Log-Message "Policy configuration process completed successfully." "INFO"
