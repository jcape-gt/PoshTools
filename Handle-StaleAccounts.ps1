
# -----[ Customize as needed ]----- #
$disabledCompDays = 35
$disabledUserDays = 35

$deletedCompDays = 60
$deletedUserDays = 60

$disabledUsersFileLocation = '[fileLocation]'
$disabledCompsFileLocation = '[fileLocation]'

# Don't disable accounts contained in these OUs
$reservedOUs = @('Reserved')

$SearchBase = 'OU=TESTOU,DC=TESTDC'

# --------------------------------- #

<#    
.DESCRIPTION
This function is a base for returing LDAP (AD) objects from a directory services. 
It can be used even where active directory modules are not installed. Searches
are recursive, so that a defined search base includes contents of all children containers. 

.PARAMETER Filter
A string filter formatted as LDAP query syntax

.PARAMETER SearchBase
The search base from which the directory searcher begins its search 

.RETURN 
A list of System.DirectoryServices.DirectoryEntry objects matching the Filter criteria
under the SearchBase subdomain

.EXAMPLE 
$searchBase = "OU=Benning,OU=Installations,DC=nase,DC=ds,DC=army,DC=mil"
$filter = "(&(objectCategory=Computer)(name=bennwki31000*))"
Get-LDAPObject -SearchBase $searchBase -Filter $Filter
#>
Function Get-LDAPObject {
    Param (
        [string] $Filter,
        [string] $SearchBase
    )

    # Add 'LDAP://' to SearchBase 
    $SearchBase.TrimStart('LDAP://') | Out-Null
    $SearchBase = 'LDAP://' + $SearchBase

    # Instantiate the base directory 
    if(![string]::IsNullOrEmpty($SearchBase)) {
        $domain = New-Object System.DirectoryServices.DirectoryEntry($SearchBase)
    }
    else {
        $domain = New-Object System.DirectoryServices.DirectoryEntry
    }

    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = $domain
    $searcher.Filter = $Filter
    $searcher.SearchScope = "Subtree"
    $searcher.SizeLimit = 30000
    $searcher.PageSize = 1000

    $results = @()
    foreach($result in $searcher.FindAll()) {
        $results += $result.GetDirectoryEntry()
    }

    $searcher.Dispose()
    $results
}

<#    
.DESCRIPTION
This function is a base for returing LDAP (AD) computer objects from a directory services. 
It can be used even where active directory modules are not installed. Searches
are recursive, so that a defined search base includes contents of all children containers. 

.PARAMETER Filter
A string filter formatted as LDAP query syntax

.PARAMETER SearchBase
The search base from which the directory searcher begins its search 

.RETURN 
A list of System.DirectoryServices.DirectoryEntry objects matching the Filter criteria
under the SearchBase subdomain

.EXAMPLE 
$searchBase = "OU=TESTOU,DC=TESTDC"
$filter = "(name=testcomp*)"
Get-LDAPComputer -SearchBase $searchBase -Filter $Filter
#>
Function Get-LDAPComputer {
    Param (
        [string] $Filter,
        [Parameter(Mandatory=$true)]
        [string] $SearchBase
    )

    # Condition the filter
    if(![String]::IsNullOrEmpty($Filter)) {
        $Filter = "(" + $Filter + ")"
    }
    $Filter = "(&(objectCategory=Computer)$($Filter))" 

    Get-LDAPObject -Filter $Filter -SearchBase $SearchBase
}

<#    
.DESCRIPTION
This function is a base for returing LDAP (AD) user objects from a directory services. 
It can be used even where active directory modules are not installed. Searches
are recursive, so that a defined search base includes contents of all children containers. 

.PARAMETER Filter
A string filter formatted as LDAP query syntax

.PARAMETER SearchBase
The search base from which the directory searcher begins its search 

.RETURN 
A list of System.DirectoryServices.DirectoryEntry objects matching the Filter criteria
under the SearchBase subdomain

.EXAMPLE 
$searchBase = "OU=TESTOU,DC=TESTDC"
$filter = "(name=cape, jesse)"
Get-LDAPUser -SearchBase $searchBase -Filter $Filter
#>
Function Get-LDAPUser {
    Param (
        [string] $Filter,
        [Parameter(Mandatory=$true)]
        [string] $SearchBase
    )

    # Condition the filter
    if(![String]::IsNullOrEmpty($Filter)) {
        $Filter = "(" + $Filter + ")"
    }
    $Filter = "(&(objectCategory=User)$($Filter))" 

    Get-LDAPObject -Filter $Filter -SearchBase $SearchBase
}

<#    
.DESCRIPTION
Gets computer objects that have been stale for the provided number of days

.PARAMETER Days
The the minimum number of days to designate a computer object as stale

.RETURN 
A list of stale System.DirectoryServices.DirectoryEntry computer objects

.EXAMPLE 
Get-ExpiredComputer -Days 30
#>
Function Get-ExpiredComputer {
    Param(
        [parameter(Mandatory=$true)]
        [int]$Days,
        [string]$SearchBase
    )

    if($Days -gt 0) {
        $Days = -$Days
    }

    $logonThresholdTimestamp = [DateTime]::Now.AddDays($Days).ToFileTime().ToString()
    $filter = "lastLogonTimeStamp <= $logonThresholdTimestamp"

    Get-LDAPComputer -Filter $filter -SearchBase $SearchBase
}

<#    
.DESCRIPTION
Gets user objects that have been stale for the provided number of days

.PARAMETER Days
The the minimum number of days to designate a user object as stale

.RETURN 
A list of stale System.DirectoryServices.DirectoryEntry user objects

.EXAMPLE 
Get-ExpiredUser -Days 30
#>
Function Get-ExpiredUser {
    Param(
        [parameter(Mandatory=$true)]
        [int]$Days,
        [string]$SearchBase
    )

    if($Days -gt 0) {
        $Days = -$Days
    }

    $logonThresholdTimestamp = [DateTime]::Now.AddDays($Days).ToFileTime().ToString()
    $filter = "lastLogonTimeStamp<=$logonThresholdTimestamp"

    $users = Get-LDAPUser -Filter $filter -SearchBase $SearchBase
    $users = $users | ?{$_.distinguishedName.Value -notlike "*Deployed*"}
    $users = $users | ?{$_.distinguishedName.Value -notlike "*VIP*"}
    $users
}

<#    
.DESCRIPTION
Appends the provided text to the target directory object's description property.
- This function updates an active directory object, and can only be run by an
  account with the proper AD privileges. 

.PARAMETER ADObject
A valid System.DirectoryServices.DirectoryEntry object 

.PARAMETER Description 
A string message to append to the current the ADObject's description

.PARAMETER Commit
A switch designating whether or not the changes should be committed immediately

.EXAMPLE 
Update-ADObjectDescription -ADObject $ValidObject -Description "[stale]" -Commit
#>
Function Update-ADObjectDescription {
    Param(
        [parameter(Mandatory=$true)]
        $ADObject,
        [parameter(Mandatory=$true)]
        $Description,
        [switch]
        $Commit
    )

    $ADObject.description = "$($ADObject.description) $Description"

    if($Commit.IsPresent) {
        try
        {
            $ADObject.CommitChanges()
        }
        catch
        {
            Write-Host "could not commit description changes for " $ADObject.distinguishedName
        }
    }
}

<#    
.DESCRIPTION
Disables the targeted active diretory objects 
- This function updates an active directory object, and can only be run by an
  account with the proper AD privileges. 

.PARAMETER ADObjects
A list of valid System.DirectoryServices.DirectoryEntry objects 

.EXAMPLE 
Disable-ADObjects -ADObjects $ValidObjectList
#>
Function Disable-ADObjects {
    Param(
        [parameter(Mandatory=$true)]
        $ADObjects
    )

    $staleText = "Stale Disabled"
    $date = "$(Get-Date -Format d)"

    # [testing]: for now just update the description 
    foreach($ADObject in $ADObjects) {
        
        # Disable AD object by altering the UAC value
        $newUAC = $ADObject.Properties["UserAccountControl"][0] -bor 2
        $ADObject.Properties["UserAccountControl"][0] = $newUAC
        
        # Add a note to the account description
        if($ADObject.description -notlike "*$staleText*") {
            Update-ADObjectDescription -ADObject $ADObject -Description "[$staleText $date]"
        }

        #Write-Host $ADObject.Properties["distinguishedName"]
        try
        {
            $ADObject.CommitChanges()
        }
        catch
        {
            Write-Host "could not commit description changes for " $ADObject.distinguishedName
        }
    }
}

<#    
.DESCRIPTION
[TESTING: Not yet functional]
Deletes the targeted active diretory objects 
- This function updates an active directory object, and can only be run by an
  account with the proper AD privileges. 

.PARAMETER ADObjects
A list of valid System.DirectoryServices.DirectoryEntry objects 

.EXAMPLE 
Delete-ADObjects -ADObjects $ValidObjectList
#>
Function Delete-ADObject {
    Param(
        [parameter(Mandatory=$true)]
        $ADObjects
    )

    $date = "$(Get-Date -Format d)"

    # [testing]: for now just update the description 
    foreach($ADObject in $ADObjects) {
        # Add a note to the account description
        if($ADObject.description -notcontains "Stale Deleted") {
            Update-ADObjectDescription -ADObject $ADObject -Description "[Stale Deleted $date]"
            Write-Host "[New Stale]"
        }
        else {
            Write-Host "[Already Stale]"
        }
    }
}

<#    
.DESCRIPTION
Saves a list of System.DirectoryServices.DirectoryEntry objects to csv

.PARAMETER ADObjects
A list of valid System.DirectoryServices.DirectoryEntry objects 

.PARAMETER LiteralPath
A literal path to which the file is saved

.PARAMETER DateAppended
A switch to automatically append the date to the filename

.EXAMPLE 
$LiteralPath = "C:\ADObjects.csv"
Export-ADObjectList -ADObjects $ValidObjectList -LiteralPath $LiteralPath -DateAppended
#>
Function Export-ADObjectList {
    Param(
        [parameter(Mandatory=$true)]
        $ADObjects,
        [parameter(Mandatory=$true)]
        [string]$LiteralPath,
        [switch]$DateAppend
    )

    $resultList = @();

    foreach($ADObject in $ADObjects) {
        $props = $ADObject | select-object -ExpandProperty Properties
        $hash = @{}

        foreach($key in $props.Keys) { 
            $hash."$key" = "$($props[$key])"
        }
        $resultList += new-object -TypeName PSCustomObject -Property $hash
    }

    # Append date to file names
    if($DateAppend.IsPresent) {
        $index = $LiteralPath.LastIndexOf('.')
        $Extension = $LiteralPath.Substring($index)
    
        $LiteralPath = "$($LiteralPath.Substring(0, $index))_$(Get-Date -Format d)$Extension"
    }

    $LiteralPath = $LiteralPath.Replace('/','-')
    $resultList | Export-Csv -LiteralPath $LiteralPath -NoTypeInformation
}


<#    
.DESCRIPTION
Saves a list of System.DirectoryServices.DirectoryEntry objects to csv

.PARAMETER ADObjects
A list of valid System.DirectoryServices.DirectoryEntry objects 

.PARAMETER LiteralPath
A literal path to which the file is saved

.PARAMETER DateAppended
A switch to automatically append the date to the filename

.EXAMPLE 
$LiteralPath = "C:\ADObjects.csv"
Export-ADObjectListLite -ADObjects $ValidObjectList -LiteralPath $LiteralPath -DateAppended
#>
Function Export-ADObjectListLite {
    Param(
        [parameter(Mandatory=$true)]
        $ADObjects,
        [parameter(Mandatory=$true)]
        [string]$LiteralPath,
        [switch]$DateAppend
    )

    # Append date to file names
    if($DateAppend.IsPresent) {
        $index = $LiteralPath.LastIndexOf('.')
        $Extension = $LiteralPath.Substring($index)
    
        $LiteralPath = "$($LiteralPath.Substring(0, $index))_$(Get-Date -Format d)$Extension"
    }

    $LiteralPath = $LiteralPath.Replace('/','-')
    $List = $ADObjects | Select-Object -ExpandProperty distinguishedName 
    $ADObjects | select-object -Property @{Name="DistinguishedName"; Expression={$_.distinguishedName.Value}} |  export-csv -LiteralPath $LiteralPath -NoTypeInformation
}

Function Handle-StaleAccounts {
    Param(
        [parameter(Mandatory=$true)]
        $ReservedOUs,
        [parameter(Mandatory=$true)]
        [int]$DisabledCompDays,
        [parameter(Mandatory=$true)]
        [int]$DisabledUserDays,
        [parameter(Mandatory=$true)]
        [int]$DeletedCompDays,
        [parameter(Mandatory=$true)]
        [int]$DeletedUserDays,
        [parameter(Mandatory=$true)]
        [string]$DisabledUsersFileLocation,
        [parameter(Mandatory=$true)]
        [string]$DisabledCompsFileLocation,
        [string]$SearchBase = "OU=Benning,OU=Installations,DC=nase,DC=ds,DC=army,DC=mil",
        [switch]$WhatIf
    )

    # Print preliminary information
    Write-Host "Disabled Computer Account Days:    $DisabledCompDays"
    Write-Host "Disabled User Account Days:        $DisabledUserDays"
    Write-Host "Disabled Computer Account Report:  $DisabledCompsFileLocation"
    Write-Host "Disabled User Account Report:      $DisabledUsersFileLocation"

    Write-Host "Getting expired objects..."

    # Get expired users and computers
    $comps = Get-ExpiredComputer -Days $disabledComputerDays
    $users = Get-ExpiredUser -Days $disabledUserDays

    Write-Host "Found $($users.Count) expired users"
    Write-Host "Found $($comps.Count) expired computers"

    # Disable AD users
    if(!$WhatIf.IsPresent) {
        # Disable expired AD users and export list to CSV
        Write-Host "Disabling expired users..."
        Disable-ADObjects -ADObjects $users
    }

    # Write disabled users to file
    Write-Host "Writing expired users to file..."
    Export-ADObjectListLite -ADObjects $users -LiteralPath $DisabledUsersFileLocation -DateAppend

    # Disable expired AD computers and export list to CSV
    if(!$WhatIf.IsPresent) {
        Write-Host "Disabling expired computers..."
        Disable-ADObjects -ADObjects $comps
    }

    # Write disabled computers to file
    Write-Host "Writing expired computers to file..."
    Export-ADObjectListLite -ADObjects $comps -LiteralPath $DisabledCompsFileLocation -DateAppend

    Write-Host "Finished!"
}
