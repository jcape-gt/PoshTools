$adapters = Get-WmiObject -Class 'Win32_NetworkAdapter'

Write-Host "Total adapter count: $($adapters.Count)" 

$ethernetAdapters = @()
$wirelessAdapters = @()

# Get relevant adapters
foreach($adapter in $adapters) {
    
    # Get all ethernet adapters
    if(($adapter.AdapterTypeId -eq 0) -and ($adapter.PhysicalAdapter)) {
        $ethernetAdapters += $adapter
    }

    # Get all wireless adapters
    if($adapter.AdapterTypeId -eq 9) {
        $wirelessAdapters += $adapter
    }
}

Write-Host "Ethernet adapter count: $($ethernetAdapters.Count)" 
Write-Host "Wireless adapter count: $($wirelessAdapters.Count)" 

foreach($adapter in $ethernetAdapters) {
    Write-Host " --- Status of adapter $($adapter.Name)"

    # Verify availability
    if($adapter.Availability -eq 3) {
        Write-Host "`t ..Availability OK."
    }
    else {
        Write-Host "`t ..Availability ERROR. Value $($adapter.Availability)"
    }

    # Verify configuration
    if($adapter.ConfigManagerErrorCode -eq 0) {
        Write-Host "`t ..Configuration OK."
    }
    else {
        Write-Host "`t ..Configuration ERROR. Value $($adapter.ConfigManagerErrorCode)"
    }

    # Verify configuration
    if($adapter.NetConnectionStatus -eq 2) {
        Write-Host "`t ..Network Connection OK."
    }
    else {
        Write-Host "`t ..Network Connection ERROR. Value $($adapter.ConfigManagerErrorCode)"
    }

    # Verify configuration
    if($adapter.NetEnabled) {
        Write-Host "`t ..Adapter is Enabled."
    }
    else {
        Write-Host "`t ..Adapter is DISABLED. Enable Adapter."
    }
}
