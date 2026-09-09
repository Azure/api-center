#requires -Version 5.1
<#
.SYNOPSIS
    Configures Git Credential Manager for an Entra-protected API Center marketplace Git endpoint.

.DESCRIPTION
    Discovers the API Center OAuth resource metadata and Entra authorization endpoints, then writes
    host-scoped GCM generic OAuth settings. No access tokens or client secrets are stored by this script.

.PARAMETER DataApiHost
    API Center data-plane hostname or HTTPS origin. The Endpoint alias is retained for compatibility.

.PARAMETER ClientId
    Application (client) ID of an Entra public client that has the Azure API Center Data.Read.All
    delegated permission. Configure the fixed localhost callback as a Mobile and desktop redirect URI
    and enable public client flows for the app registration.

.PARAMETER Scope
    Optional OAuth scope override. By default, Data.Read.All is selected from protected-resource
    discovery. If it is not advertised, the first advertised scope is used.

.PARAMETER RedirectPort
    Fixed localhost port used for the OAuth authorization-code callback. Register the resulting URI,
    for example http://localhost:8400/, under the app's Mobile and desktop applications platform.

.PARAMETER CredentialStore
    GCM credential store backend. The default, dpapi, avoids the Windows Credential Manager size
    limit for large Entra tokens.

.PARAMETER ClearExisting
    Removes the cached credential for the endpoint host after writing the GCM configuration.

.PARAMETER DryRun
    Resolves and displays the configuration without modifying Git config or cached credentials.

.EXAMPLE
    .\scripts\Set-ApiCenterGitCredentialManager.ps1 -DataApiHost '<data-api-host>' -ClientId '<public-client-app-id>' -DryRun

.EXAMPLE
    .\scripts\Set-ApiCenterGitCredentialManager.ps1 -DataApiHost '<data-api-host>' -ClientId '<public-client-app-id>' -ClearExisting
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [Alias('Endpoint')]
    [string] $DataApiHost,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string] $ClientId,

    [string] $Scope,

    [ValidateRange(1024, 65535)]
    [int] $RedirectPort = 8400,

    [ValidateSet('global', 'local', 'system')]
    [string] $ConfigScope = 'global',

    [ValidateSet('dpapi', 'wincredman', 'cache', 'none')]
    [string] $CredentialStore = 'dpapi',

    [switch] $ClearExisting,

    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    Write-Verbose 'TLS protocol selection is managed by the current runtime.'
}

function Get-Json {
    param([Parameter(Mandatory)][string] $Uri)

    Write-Verbose "GET $Uri"
    Invoke-RestMethod -Method Get -Uri $Uri -Headers @{ Accept = 'application/json' }
}

function Set-HostGitConfig {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Value
    )

    & git config "--$ConfigScope" "$script:GitConfigKey.$Name" $Value
    if ($LASTEXITCODE -ne 0) {
        throw "git config failed while writing '$Name'."
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is not installed or is not available on PATH.'
}

& git credential-manager --version *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Git Credential Manager is not installed or is not available through git credential-manager.'
}

$dataApiHostValue = $DataApiHost.Trim()
if ($dataApiHostValue -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
    $dataApiHostValue = "https://$dataApiHostValue"
}

$dataApiUri = $null
if (-not [Uri]::TryCreate($dataApiHostValue, [UriKind]::Absolute, [ref] $dataApiUri) -or $dataApiUri.Scheme -ne 'https') {
    throw 'DataApiHost must be a hostname or absolute HTTPS origin.'
}
if (-not [string]::IsNullOrEmpty($dataApiUri.UserInfo) -or -not [string]::IsNullOrEmpty($dataApiUri.Query) -or -not [string]::IsNullOrEmpty($dataApiUri.Fragment)) {
    throw 'DataApiHost must not contain user information, a query, or a fragment.'
}

$dataApiPath = $dataApiUri.AbsolutePath.TrimEnd('/')
if ($dataApiPath -and $dataApiPath -notmatch '/plugins/marketplace\.git$') {
    throw 'DataApiHost must not contain a path.'
}

$origin = '{0}://{1}' -f $dataApiUri.Scheme, $dataApiUri.Authority
$redirectUri = "http://localhost:$RedirectPort/"
$protectedResourceMetadataUri = "$origin/.well-known/oauth-protected-resource"
Write-Host "Discovering OAuth configuration from $protectedResourceMetadataUri" -ForegroundColor Cyan

$protectedResourceMetadata = Get-Json -Uri $protectedResourceMetadataUri
$resource = [string] $protectedResourceMetadata.resource
$authorizationServer = [string] @($protectedResourceMetadata.authorization_servers)[0]
$advertisedScopes = @($protectedResourceMetadata.scopes_supported | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ([string]::IsNullOrWhiteSpace($authorizationServer)) {
    throw "Protected-resource metadata did not advertise an authorization server."
}

$authorizationServer = $authorizationServer.TrimEnd('/')
$authorizationMetadata = Get-Json -Uri "$authorizationServer/.well-known/openid-configuration"
$authorizationEndpoint = [string] $authorizationMetadata.authorization_endpoint
$tokenEndpoint = [string] $authorizationMetadata.token_endpoint

if ([string]::IsNullOrWhiteSpace($authorizationEndpoint) -or [string]::IsNullOrWhiteSpace($tokenEndpoint)) {
    throw 'Authorization-server metadata did not include authorization and token endpoints.'
}

if (-not [string]::IsNullOrWhiteSpace($Scope)) {
    $resolvedScope = $Scope.Trim()
} else {
    $resolvedScope = [string] @($advertisedScopes | Where-Object { $_ -match '(^|/)Data\.Read\.All$' })[0]
    if ([string]::IsNullOrWhiteSpace($resolvedScope)) {
        $resolvedScope = [string] $advertisedScopes[0]
    }
    if ([string]::IsNullOrWhiteSpace($resolvedScope) -and -not [string]::IsNullOrWhiteSpace($resource)) {
        $resolvedScope = "$($resource.TrimEnd('/'))/.default"
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedScope)) {
    throw 'Could not determine an OAuth scope. Pass -Scope explicitly.'
}
if ($resolvedScope -notmatch '(^|\s)offline_access(\s|$)') {
    $resolvedScope = "$resolvedScope offline_access"
}

$script:GitConfigKey = "credential.$origin"
Write-Host ''
Write-Host 'Resolved GCM configuration:' -ForegroundColor Cyan
Write-Host "  Data API host     : $origin"
Write-Host "  Client ID         : $ClientId"
Write-Host "  Resource          : $resource"
Write-Host "  Scope             : $resolvedScope"
Write-Host "  Authorization     : $authorizationEndpoint"
Write-Host "  Token             : $tokenEndpoint"
Write-Host "  Redirect          : $redirectUri (Mobile and desktop application)"
Write-Host "  Credential store  : $CredentialStore (host-scoped)"

if ($DryRun) {
    Write-Host 'Dry run complete; Git config was not changed.' -ForegroundColor Yellow
    return
}

$gitSettings = [ordered] @{
    provider                 = 'generic'
    oauthClientId            = $ClientId
    oauthRedirectUri         = $redirectUri
    oauthScopes              = $resolvedScope
    oauthAuthorizeEndpoint   = $authorizationEndpoint
    oauthTokenEndpoint       = $tokenEndpoint
    oauthUseClientAuthHeader = 'false'
    credentialStore          = $CredentialStore
}
foreach ($setting in $gitSettings.GetEnumerator()) {
    Set-HostGitConfig -Name $setting.Key -Value $setting.Value
}

# Device code is intentionally unsupported. Remove a value written by an older version of this script.
& git config "--$ConfigScope" --unset-all "$script:GitConfigKey.oauthDeviceEndpoint" 2> $null

if ($ClearExisting) {
    "protocol=https`nhost=$($dataApiUri.Authority)`n" | & git credential reject
    if ($LASTEXITCODE -ne 0) {
        throw 'Git Credential Manager could not clear the existing credential.'
    }
}

Write-Host ''
Write-Host "Configured GCM for $origin." -ForegroundColor Green