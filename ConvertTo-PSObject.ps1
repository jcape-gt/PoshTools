<#
.SYNOPSIS
    This function converts a delimited record or table into custom PSObjects
.DESCRIPTION
    The function takes as input a 2D string array to parse into a list of PSObjects
    The function allows for custom delimiters
    [TODO] - Implement piping to facilitate more flexible input types 
.RETURN
    A list of custom PSObjects 
#>
function ConvertTo-PSObject {
    param(
        [parameter(Mandatory=$true)]
        [string[]]$table,
        [parameter(Mandatory=$false)]
        [string[]]$fieldDefinitions=$null,
        [parameter(Mandatory=$false)]
        [string]$delimiter = " "
    )

    if($fieldDefinitions) {
        $fieldDefs = $fieldDefinitions
    }
    else {
        $fieldDefs = $table[0].Split($delimiter);
    }

    $results = @();

    foreach($record in $table) {
        $values = @()
        $values += $record.Split(" ");
        $props = @{}

        for($i=0; $i -lt $fieldDefs.Count; $i++) {
             $props.Add($fieldDefs[$i], $values[$i])
        }

        $newobj = New-Object -TypeName PSObject -Prop $props

        $results += $newobj
    }

    return $results
}
