Function Get-LDAPComputer {
    Param (
        [string] $Filter,
        [string] $SearchBase
    )

    # Add 'LDAP://' to SearchBase 
    $SearchBase.TrimStart('LDAP://') | Out-Null
    $SearchBase = 'LDAP://' + $SearchBase

    # Set the filter to require an objectCategory of Computer 
    $Filter = "(&(objectCategory=Computer)($($Filter)))" 

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

    $results = @()
    foreach($result in $searcher.FindAll()) {
        $result = ($result | Select-Object -ExpandProperty Properties)
        $result = New-Object -TypeName PSCustomObject -Property $result
        $infoTable = ConvertFrom-StringData -StringData ([string]$result.info).Replace(";","`n")
        $result | Add-Member -NotePropertyMembers $infoTable
        $results += $result
    }

    $results
}

Function Get-LDAPUser {
    Param (
        [string] $Filter,
        [string] $SearchBase
    )

    # Add 'LDAP://' to SearchBase 
    $SearchBase.TrimStart('LDAP://') | Out-Null
    $SearchBase = 'LDAP://' + $SearchBase

    # Set the filter to require an objectCategory of Computer 
    $Filter = "(&(objectCategory=User)($($Filter)))" 

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

    $results = @()
    foreach($result in $searcher.FindAll()) {
        $result = ($result | Select-Object -ExpandProperty Properties)
        $result = New-Object -TypeName PSCustomObject -Property $result
        $results += $result
    }

    $results
}
