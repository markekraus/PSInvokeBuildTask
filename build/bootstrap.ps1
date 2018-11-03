Param(
    [Switch]
    $InstallNugetProvider,

    [Switch]
    $InstallPowerShellGet,

    [switch]
    $UpdatePowerShellGet,

    [switch]
    $InstallInvokeBuild,

    [Switch]
    $RegisterRepository,

    [Switch]
    $UnregisterRepository,

    [PSCredential]
    $AzdoCredential,

    [string]
    $PSRepositoryName = $env:PSRepositoryName,

    [string]
    $PSRepositoryUri = $env:PSRepositoryUri,

    [switch]
    $PSGalleryFallback
)

function Set-BuildVariableFromBoolString {
    [CmdletBinding()]
    param (
        [string]
        $VariableName
    )
    process {
        $EnvVariable = Get-Item "env:\$VariableName" -ErrorAction SilentlyContinue
        if( -not $Script:PSBoundParameters.ContainsKey($VariableName) -and $EnvVariable.Value ) {
            'Attempting to derive {0} from environment' -f $VariableName
            $Out = $false
            if([bool]::TryParse($EnvVariable.Value, [ref]$Out)) {
                '{0} derived from environment' -f $VariableName
                Set-Variable -Scope Script -Name $VariableName -Value $Out
            } else {
                '{0} environment variable does not contain a valid Bool string' -f $VariableName
            }
        }
    }
}

function Set-Credential {
    [CmdletBinding()]
    param ()
    end {
        if(-not $Script:AzdoCredential) {
            'Attempting to create AzdoCredential from System_AccessToken'
            try {
                $SecureToken = $env:System_AccessToken | 
                    ConvertTo-SecureString -AsPlainText -Force -ErrorAction 'Stop'
                $Script:AzdoCredential = [PSCredential]::new(
                    'VSTS',
                    $SecureToken
                )
                'Created AzdoCredential from System_AccessToken'
            }
            catch {
                'Unable to create Azure DevOps credentials from environment.'
                $_ | Out-String
            }
        } else {
            Throw 'AzdoCredential Not supplied'
        }
    }
}

if ($InstallNugetProvider) {
    Install-PackageProvider Nuget -Force -Verbose -ErrorAction 'Stop'
}

if ($InstallPowerShellGet) {
    Install-Module -Name PowerShellGet -Force -Verbose -ErrorAction 'Stop'
}

if ($UpdatePowerShellGet) {
    Update-Module -Force PowerShellGet -Verbose -ErrorAction 'Stop'
}

if ($RegisterRepository) {
    if ($PSRepositoryName) {
        'Repository name supplied'
    } else {
        'Repository name was not supplied.'
        throw 'Repository name was not supplied.'
    }

    Set-Credential

    'Registering PS repository {0} with name {1}' -f $PSRepositoryUri, $PSRepositoryName
    $registerPSRepositorySplat = @{
        InstallationPolicy = 'Trusted'
        Name = $PSRepositoryName
        SourceLocation = $PSRepositoryUri
        Credential = $AzdoCredential
        Verbose = $true
        ErrorAction = 'Stop'
    }
    try {
        Register-PSRepository @registerPSRepositorySplat
        'Registered PS repository {0} with name {1}' -f $PSRepositoryUri, $PSRepositoryName
    }
    catch {
        'Registering repository failed'
        $_ | Out-String
        Throw 'Registering repository failed'
    }
}

if ($InstallInvokeBuild) {
    Set-BuildVariableFromBoolString -VariableName 'PSGalleryFallback'

    if ($PSRepositoryName) {
        'Repository name supplied'
        $Repository = $PSRepositoryName
    } else {
        'Repository name was not supplied.'
        if (-not $PSGalleryFallback) {
            throw 'Repository name was not supplied.'
        }
    } 
    if ($PSRepositoryName -and $PSGalleryFallback) {
        'PSGalleryFallback enabled'
        $Repository = $PSRepositoryName, 'PSGallery'
    }
    

    $installModuleSplat = @{
        Name = 'InvokeBuild' 
        RequiredVersion = '5.4.1'
        Scope = 'CurrentUser' 
        Force = $true
        AllowClobber = $true
        Repository = $Repository
        ErrorAction = 'Stop'
        Verbose = $true
    }

    try {
        Set-Credential -ErrorAction Stop
        $installModuleSplat['Credential'] = $AzdoCredential
    } Catch {
        # NOOP
    }

    try {
        'Installing module {0} version {1} from {2} as {3}' -f @(
            $installModuleSplat['Name'],
            $installModuleSplat['RequiredVersion'],
            ($installModuleSplat['Repository'] -join ', '),
            $installModuleSplat.Credential.Username
        )
        Install-Module @installModuleSplat
    }
    catch {
        'Installing module failed'
        $_ | Out-String
        $Failed = $true
    }

    if ($Failed) {
        throw 'failed to install module'
    }
}

if ($UnregisterRepository) {
    if ($PSRepositoryName) {
        'Repository name supplied'
    } else {
        'Repository name was not supplied.'
        throw 'Repository name was not supplied.'
    }

    'Unregistering Repository {0}' -f $PSRepositoryName 
    try {
        Unregister-PSRepository -Name $PSRepositoryName -ErrorAction 'Stop'
    }
    catch {
        'Unregistering Repository failed'
        $_ | Out-String
        throw 'Unregistering Repository failed'
    }
}