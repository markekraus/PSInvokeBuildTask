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
    $Inputs[$InputItem.Name] = Get-VstsInput -Name 'Task'
}
