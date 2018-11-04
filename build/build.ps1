[CmdletBinding()]
Param(
    [Parameter()]
    [String]
    $ProjectRoot = (Resolve-Path (Join-path $BuildRoot '..')).Path,

    [Parameter()]
    [String]
    $ExtensionsPath,

    [Parameter()]
    [string]
    $VstsTaskSdkVersion = '0.11.0',

    [Parameter()]
    $OutputPath,

    [Parameter()]
    $VssExtensionManifest
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
    if( -not $ExtensionsPath) {
        $Script:ExtensionsPath = Join-Path $ProjectRoot 'extensions'
    }

    if (-not $OutputPath -and $env:Build_ArtifactStagingDirectory) {
        $Script:OutputPath = Join-Path $env:Build_ArtifactStagingDirectory 'bin'
    }
    if (-not $OutputPath){
        $Script:OutputPath = Join-Path $ProjectRoot 'bin'
    }

    $Script:ExtensionList = [System.Collections.Generic.List[PSObject]]::new()

    if (-not $VssExtensionManifest) {
        $script:VssExtensionManifest = Join-Path $ExtensionsPath 'vss-extension.json'
    }

    'ProjectRoot:          {0}' -f $Script:ProjectRoot
    'ExtensionsPath:       {0}' -f $Script:ExtensionsPath
    'VstsTaskSdkVersion:   {0}' -f $Script:VstsTaskSdkVersion
    'OutputPath:           {0}' -f $Script:OutputPath
    'VssExtensionManifest: {0}' -f $Script:VssExtensionManifest
}

Task IdentifyExtensions Initialize, {
    'Enumerating extensions from {0}..' -f $ExtensionsPath
    ' '
    Get-ChildItem -Path $ExtensionsPath -Directory | ForEach-Object {
        if ($_.Name -eq 'images') {
            'Skipping images'
            return
        }
        'Found Extension {0} ' -f $_.Name
        $ExtensionList.Add($_)
    }
}

Task RestoreVstsTaskSdk Initialize, IdentifyExtensions, {
    foreach ($Extension in $ExtensionList) {
        'Restoring VstsTaskSdk to extension {0}' -f $Extension.Name
        
        $ps_modulesPath = Join-Path $Extension.FullName 'ps_modules'
        $VstsTaskSdkPath = Join-Path $ps_modulesPath 'VstsTaskSdk'
        $VstsTaskSdkBakPath = Join-Path $ps_modulesPath 'VstsTaskSdk_bak'
        $VstsTaskSdkFullPath = Join-Path $VstsTaskSdkBakPath $VstsTaskSdkVersion
        $VstsTaskSdkTmpPath = Join-Path $ps_modulesPath $VstsTaskSdkVersion

        'Ensuring {0}' -f $ps_modulesPath
        New-Item -ItemType Directory -Path $ps_modulesPath -Force

        'Restoring VstsTaskSdk version {0} to {1}' -f $VstsTaskSdkVersion, $ps_modulesPath
        Save-Module -Name VstsTaskSdk -Path $ps_modulesPath -RequiredVersion $VstsTaskSdkVersion -Force -ErrorAction Stop -Verbose 
        Move-Item $VstsTaskSdkPath $VstsTaskSdkBakPath -Verbose
        Move-Item $VstsTaskSdkFullPath $ps_modulesPath -Verbose
        Rename-Item $VstsTaskSdkTmpPath $VstsTaskSdkPath -Verbose
        Remove-Item -Force $VstsTaskSdkBakPath -Recurse -Confirm:$false
        ' '
    }
}

Task CreatePaths Initialize, {
    $Paths = @(
        $OutputPath
    )
    foreach ($Path in $Paths) {
        'Ensuring {0}' -f $Path
        New-Item -ItemType Directory -Path $Path -Force
    }
}

Task BuildExtension Initialize, CreatePaths, {
    Push-Location $ExtensionsPath -Verbose
    try {
        'Executing'
        "tfx extension create --manifest-globs $VssExtensionManifest --output-path $OutputPath --no-prompt"
        tfx extension create --manifest-globs $VssExtensionManifest --output-path $OutputPath --no-prompt
    } finally {
        Pop-Location -Verbose
    }
}
