[CmdletBinding()]
Param()

$TaskJsonFile = Join-Path $PSScriptRoot 'task.json'
$TaskJsonData = Get-Content -raw $TaskJsonFile | ConvertFrom-Json

$Inputs = @{}
foreach ($InputItem in $TaskJsonData.Inputs) {
    $Params = @{
        Name = $InputItem.Name
        Require = $InputItem.required
        AsBool = $InputItem.type -eq 'boolean'
    }
    $Inputs[$InputItem.Name] = Get-VstsInput -Name 'Task'
}
