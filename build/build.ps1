[CmdletBinding()]
Param(
    [Parameter()]
    [String]
    $ProjectRoot = (Resolve-Path (Join-path $BuildRoot '..')).Path,

    [Parameter()]
    [String]
    $ExtensionsPath,

    [Parameter()]
    $OutputPath,

    [Parameter()]
    $VssExtensionManifest,

    [Parameter()]
    $DependenciesFile,

    [Parameter()]
    $BuildVersion
)

Set-BuildHeader {
	param($Path)
    Write-Build Green ('=' * 80)
    Write-Build Green ('                Task {0}' -f $Path)
    if(($Synopsis = Get-BuildSynopsis $Task)) {
        Write-Build Green ('                {0}' -f $Synopsis)
    }
    Write-Build Green ('-' * 80)
	# task location in a script
    Write-Build Green ('At {0}:{1}' -f $Task.InvocationInfo.ScriptName, $Task.InvocationInfo.ScriptLineNumber)
    Write-Build Green ' '
}

# Define footers similar to default but change the color to DarkGray.
Set-BuildFooter {
	param($Path)
    Write-Build DarkGray ('Done {0}, {1}' -f $Path, $Task.Elapsed)
    Write-Build Green ('=' * 80)
    Write-Build Green ' '
    Write-Build Green ' '
}

Task Initialize {
    $Script:ConfigPath = Join-Path $ProjectRoot 'config'

    if (-not $DependenciesFile) {
        $Script:DependenciesFile = Join-Path $ConfigPath 'dependenceis.json'
    }

    if( -not $ExtensionsPath) {
        $Script:ExtensionsPath = Join-Path $ProjectRoot 'extensions'
    }

    if (-not $OutputPath -and $env:Build_ArtifactStagingDirectory) {
        $Script:OutputPath = Join-Path $env:Build_ArtifactStagingDirectory 'bin'
    }
    if (-not $OutputPath){
        $Script:OutputPath = Join-Path $ProjectRoot 'bin'
    }

    $Script:StagingPath = Join-Path $OutputPath 'staging'

    $Script:ExtensionList = [System.Collections.Generic.List[PSObject]]::new()

    if (-not $VssExtensionManifest) {
        $script:VssExtensionManifest = Join-Path $ExtensionsPath 'vss-extension.json'
    }

    $script:VssExtensionStagingManifest = Join-Path $StagingPath 'vss-extension.json'

    'ProjectRoot:                 {0}' -f $Script:ProjectRoot
    'ConfigPath:                  {0}' -f $Script:ConfigPath
    'DependenciesFile:            {0}' -f $Script:DependenciesFile
    'ExtensionsPath:              {0}' -f $Script:ExtensionsPath
    'VstsTaskSdkVersion:          {0}' -f $Script:VstsTaskSdkVersion
    'OutputPath:                  {0}' -f $Script:OutputPath
    'StagingPath:                 {0}' -f $Script:StagingPath
    'VssExtensionManifest:        {0}' -f $Script:VssExtensionManifest
    'VssExtensionStagingManifest: {0}' -f $Script:VssExtensionStagingManifest
}

Task IdentifyExtensions Initialize, {
    'Enumerating extensions from {0}..' -f $StagingPath
    ' '
    Get-ChildItem -Path $StagingPath -Directory | ForEach-Object {
        if ($_.Name -eq 'images') {
            'Skipping images'
            return
        }
        'Found Extension {0} ' -f $_.Name
        $ExtensionList.Add($_)
    }
}

Task StageExtension Initialize, CreatePaths, {
    $OriginalManifest = Get-Item $VssExtensionManifest -ErrorAction Stop

    'Copying {0} to {1}' -f $OriginalManifest.FullName, $VssExtensionStagingManifest
    Copy-Item $OriginalManifest.FullName $VssExtensionStagingManifest -Force -Verbose
    ' '

    'Copying items from {0} to {1}' -f $ExtensionsPath, $StagingPath
    Get-ChildItem -Path $ExtensionsPath | Foreach-Object {
        if ($_.FullName -eq $OriginalManifest.FullName) {
            'Skipping {0}' -f $_.Name
            return
        }
        if ($_.PSIsContainer) {
            'Copying Directory {0} to {1}' -f $_.Name, $StagingPath
            Copy-Item $_.FullName $StagingPath -Container -Recurse -Force -Verbose
        } else {
            'Copying File {0} to {1}' -f $_.Name, $StagingPath
            Copy-Item $_.FullName $StagingPath -force -Verbose
        }
    }
}

Task GetDependencies Initialize, {
    'Retrieving Dependencies from {0}' -f $DependenciesFile
    $Script:DependenciesData = Get-Content -Raw $DependenciesFile | ConvertFrom-Json
}

Task RestorePSModules Initialize, IdentifyExtensions, GetDependencies, {
    if($ExtensionList.Count -lt 1) {
        'No Extensions found. Ensure StageExtension Task has been run.'
        return
    }

    foreach ($Extension in $ExtensionList) {
        $Dependencies = $DependenciesData.PowerShell | Where-Object {$_.Phases -contains 'RestorePSModules'}
        $ps_modulesPath = Join-Path $Extension.FullName 'ps_modules'
        'Ensuring {0}' -f $ps_modulesPath
        New-Item -ItemType Directory -Path $ps_modulesPath -Force
        Foreach ($Dependency in $Dependencies) {
            'Restoring Module {0} Version {1} to extension {2}' -f $Dependency.Name, $Dependency.Version, $Extension.Name

            $ModulePath = Join-Path $ps_modulesPath $Dependency.Name
            $ModulePathBak = Join-Path $ps_modulesPath ('{0}_bak' -f $Dependency.Name)
            $ModulePathFull = Join-Path $ModulePathBak $Dependency.Version
            $ModulePathTmp = Join-Path $ps_modulesPath $Dependency.Version

            Try {
                'Removing {0}' -f $ModulePath 
                Remove-Item -Path $ModulePath -Force -Recurse -ErrorAction Stop -Verbose
            } catch [System.Management.Automation.ItemNotFoundException] {
                # We don't care it doesn't exist
            } catch {
                # We do care about other issues.
                Write-Error -ErrorRecord $_
            }

            'Saving Module {0} version {1} to path {2}' -f $Dependency.Name, $Dependency.Version, $ps_modulesPath
            Save-Module -Name $Dependency.Name -Path $ps_modulesPath -RequiredVersion $Dependency.Version -Force -ErrorAction Stop -Verbose
            Move-Item $ModulePath $ModulePathBak -Verbose
            Move-Item $ModulePathFull $ps_modulesPath -Verbose
            Rename-Item $ModulePathTmp $ModulePath -Verbose
            Remove-Item -Force $ModulePathBak -Recurse -Confirm:$false
            ' '
        }
        ' '
    }
}

Task CreatePaths Initialize, {
    $Paths = @(
        $OutputPath,
        $StagingPath
    )
    foreach ($Path in $Paths) {
        'Ensuring {0}' -f $Path
        New-Item -ItemType Directory -Path $Path -Force
    }
}

Task Clean Initialize, {
    $Paths = @(
        $OutputPath,
        $StagingPath
    )
    foreach ($Path in $Paths) {
        'Removing {0}' -f $Path
        Try {
            Remove-Item -Path $Path -Force -Recurse -ErrorAction Stop
        } catch [System.Management.Automation.ItemNotFoundException] {
            # We don't care it doesn't exist
        } catch {
            # We do care about other issues.
            Write-Error -ErrorRecord $_
        }
    }
}

Task BuildExtension Initialize, CreatePaths, {
    Push-Location $StagingPath -Verbose
    try {
        'Executing'
        "tfx extension create --manifest-globs $VssExtensionStagingManifest --output-path $OutputPath --no-prompt"
        tfx extension create --manifest-globs $VssExtensionStagingManifest --output-path $OutputPath --no-prompt
    } finally {
        Pop-Location -Verbose
    }
}

Task VersionBump Initialize, {
    if(-not $BuildVersion) {
        try {
            'Locating GitVersion binary'
            $GitVersion = Get-Command -CommandType Application -Name 'GitVersion' -ErrorAction 'stop'
        } catch {
            'Unable to find GitVersion binary'
            $PSCmdlet.ThrowTerminatingError($_)
        }
        Push-Location $ProjectRoot
        'Executing GitVersion'
        $GitVersion = GitVersion | ConvertFrom-Json
        Pop-Location
        $BuildVersion = $GitVersion.NuGetVersionV2
    } else {
        'Verison {0} supplied as parameter' -f $BuildVersion
    }

    $NewVersion, $PreRelease = $BuildVersion -split '-'
    $PreRelease = -join $PreRelease
    
    $Manifest = Import-PowerShellDataFile -Path $ManifestPath

    if(-not $Manifest.PrivateData) {
        'PrivateData not found in original manifest'
        $Manifest['PrivateData'] = @{}
    }

    'Updating {0} with version {1}' -f $ManifestPath, $NewVersion
    Update-ModuleManifest -ModuleVersion $NewVersion -Path $ManifestPath

    if ($PreRelease) {
        'Updating {0} with Prelease {1}' -f $ManifestPath, $Prerelease
        Update-ModuleManifest -Path $ManifestPath -Prerelease $Prerelease
    } else {
        'Removing Prelease'
        # Update-ModuleManifest does not support commenting out Prerelease.
        # Using regex to replace the entry instead
        $ManifestText = Get-Content -Path $ManifestPath | 
            ForEach-Object { 
                $PSItem -replace '^(\s*)Prerelease', '$1# Prerelease'
            }
        $ManifestText | Set-Content -Encoding 'UTF8' -Path $ManifestPath
    }

    $NewManifest = Import-PowerShellDataFile -Path $ManifestPath

    'OldManifestVersion:    {0}' -f $Manifest['ModuleVersion']
    'BuildVersion:          {0}' -f $BuildVersion
    'NewVersion:            {0}' -f $NewVersion
    'PreRelease:            {0}' -f $PreRelease
    'NewManifestVersion:    {0}' -f $NewManifest['ModuleVersion']
    'NewManifestPrerelease: {0}' -f $NewManifest.PrivateData.PSData.Prerelease
}
