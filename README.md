# PowerShell Invoke-Build Task Runner for Azure DevOps Pipelines

## Description

This Azure DevOps extension allows for the creation of Azure DevOps build and release pipeline tasks to run PowerShell Invoke-Build tasks.

## License

[MIT](./LICENSE)

## Requirements

This project requires [NPM](https://www.npmjs.com/get-npm).

It also requires `Invoke-Build`:

```powershell
Install-Module -Scope 'CurrentUser' -Repository 'PSGallery' -Name 'InvokeBuild' -MinimumVersion 5.4.1
```

You will also need version 4 of GitVersion:

```powershell
choco install GitVersion.Portable --version=4.0.0
```

## Building Locally

```powershell
Invoke-Build -File .\build\build.ps1 -Task Build
```

## Publishing Locally

```powershell
Invoke-Build -File .\build\build.ps1 -Task PublishExtension -VssPublisherPAT $VssPublisherPAT
```

## Azure DevOps Build Pipeline

Configure a YAML Build and use `build/AzDo_Build.yaml`

## Azure DevOps Release Pipeline

* Set VssPublisherPAT secure variable with the Visual Studio Marketplace PAT of the publisher.
* Create the rest of the pipeline (to-do)

## Versioning

To release a new version, create a new tag from master, then build and publish.
