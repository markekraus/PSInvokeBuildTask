[CmdletBinding()]
Param()

$TaskJsonFile = Join-Path $PSScriptRoot 'task.json'
$TaskJsonData = Get-Content -raw $TaskJsonFile | ConvertFrom-Json

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
