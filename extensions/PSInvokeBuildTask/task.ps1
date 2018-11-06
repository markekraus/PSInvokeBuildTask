[CmdletBinding()]
Param()

# Append PSModulePath with the Task's ps_modules folder
$PS_ModulesPath = Join-Path $PSScriptRoot 'ps_modules'
$env:PSModulePath = '{0}{1}{2}' -f @(
    $env:PSModulePath,
    [System.IO.Path]::PathSeparator,
    $PS_ModulesPath
)

# Import task.json data
$TaskJsonFile = Join-Path $PSScriptRoot 'task.json'
$TaskJsonData = Get-Content -raw $TaskJsonFile | ConvertFrom-Json

# Retrieve task inputs
$Inputs = @{}
foreach ($InputItem in $TaskJsonData.Inputs) {
    $Params = @{
        Name = $InputItem.Name
        Require = $InputItem.required -eq $true
        AsBool = $InputItem.type -eq 'boolean'
        AsInt = $InputItem.options.IsInt -eq $true
    }
    $Inputs[$InputItem.Name] = Get-VstsInput @Params
}

$Params = @{}

# Parse Parameters
if ($Inputs.ParameterJson) {
    try {
        $Parameters = $Inputs.ParameterJson | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Throw ('ParameterJson input contains invalid JSON: {0}' -f $_.Exception.Message)
    }

    # User supplied null JSON literal which we don't know how to interpret
    if (-not $Parameters) {
        Throw 'ParameterJson only supports a single key/value pair object. null is not supported.'
    }

    # User supplied an array, number, or boolean which we do not know how to interpret
    if ($Parameters.PSObject.TypeNames -notcontains 'System.Management.Automation.PSCustomObject') {
        Throw ('ParameterJson only supports a single key/value pair object. {0} is not supported.' -f $Parameters.PSObject.TypeNames[0])
    }

    # Convert the Object to HashTable to reuse as a Parameter Splat
    $ParameterNames = $Parameters.PSObject.Properties.Name
    foreach ($ParameterName in $ParameterNames) {
        $Params[$ParameterName] = $Parameters.$ParameterName
    }
}

# Set the Task, File, and Result parameters
$Params['Task'] = $Inputs.Task
$Params['File'] = $Inputs.File
$Params['Result'] = 'Result'

try {
    Invoke-Build @Params
} finally {
    # This ensures a report of results is printed even if Invoke-Build has errors.
    $Result.Tasks | Format-Table Elapsed, Name, Error -AutoSize 
}
