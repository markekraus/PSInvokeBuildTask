[CmdletBinding()]
Param()

$Task = Get-VstsInput -Name 'Task' -Require
$File = Get-VstsInput -Name 'File' -Require
$ParameterJson = Get-VstsInput -Name 'ParameterJson'

'Task: {0}' -f $Task
'File: {0}' -f $File
'ParameterJson:'
'---'
$ParameterJson
'---'
'Env:'
'---'
Get-ChildItem env: | sort Name | ft Name,Value -AutoSize
'---'
'Variable:'
'---'
Get-ChildItem variable: | sort Name | ft Name,Value -AutoSize
'---'
'PSModulePath: {0}' -f $env:PSModulePath
