# Marketplace Git — Client Authentication (Entra ID)

The `marketplace.git` endpoint is protected by Microsoft Entra ID. Standard git clients (e.g. GitHub Copilot CLI, Claude Code) authenticate through **Git Credential Manager (GCM)** using OAuth. This page explains the one-time setup.

## How it works

GCM performs an interactive Entra sign-in and returns the access token to git. Because git/GCM transmit tokens as the **password of HTTP Basic**, the Data API (for AzureRbac catalogs) advertises a `WWW-Authenticate: Basic` challenge on `marketplace.git` 401s and accepts the token from the Basic password — translating it to a Bearer token internally. This is required: git/curl will not send a Basic credential against a Bearer-only challenge.

## 1. Register a public client app (recommended)

Register a dedicated Entra application (or reuse the catalog Portal's `authentication.clientId`):

1. **App registrations → New registration.** Single tenant is fine.
2. **Authentication → Add a platform → Mobile and desktop applications** → add the fixed loopback redirect URI `http://localhost:8400/`.
3. **Authentication → Advanced settings → Allow public client flows → Yes.**
4. **API permissions → Add a permission → APIs my organization uses →** select **Azure API Center** → **Delegated** → `Data.Read.All` → **Add**, then grant consent.
5. Copy the **Application (client) ID**.

The redirect URI must appear only under **Mobile and desktop applications**, not under **Single-page application**. Use `http`, include the fixed port and trailing slash exactly, and do not register `https://localhost`. GCM uses authorization code with PKCE and listens on this loopback URI for the browser callback.

## 2. Run the setup script (one-time per machine)

Use [`scripts/Set-ApiCenterGitCredentialManager.ps1`](Set-ApiCenterGitCredentialManager.ps1) from the repository root.

### Prerequisites

- Windows PowerShell 5.1 or PowerShell 7.
- Git for Windows with Git Credential Manager (GCM). Verify with `git credential-manager --version`.
- The API Center data-plane hostname, for example `myapic.data.uksouth.azure-apicenter.ms`.
- The **Application (client) ID** from step 1. No client secret is required.

From the repository root, preview the discovered OAuth settings without changing Git configuration:

```powershell
.\scripts\Set-ApiCenterGitCredentialManager.ps1 `
    -DataApiHost '<DATA_API_HOST>' `
    -ClientId '<YOUR_PUBLIC_CLIENT_APP_ID>' `
    -DryRun
```

Review the displayed resource, scope, tenant endpoints, and redirect URI. Then apply the configuration:

```powershell
.\scripts\Set-ApiCenterGitCredentialManager.ps1 `
    -DataApiHost '<DATA_API_HOST>' `
    -ClientId '<YOUR_PUBLIC_CLIENT_APP_ID>'
```

Use `-ClearExisting` if Git previously cached an incorrect username or credential for this host. Use a different `-RedirectPort` only if port `8400` is unavailable; the exact replacement URI must also be registered in Entra under **Mobile and desktop applications**.

The script discovers the tenant, OAuth endpoints, and scope, then writes host-scoped GCM settings. It does not need the workspace path and does not request or store a client secret or access token. The former `-Endpoint` parameter name remains available as an alias for compatibility.

## 3. Clone

```powershell
git clone 'https://<DATA_API_HOST>/workspaces/<WORKSPACE>/plugins/marketplace.git'
```

The first clone opens a browser for Entra sign-in. Cancel any terminal username prompt: it means OAuth failed, and the preceding GCM or Entra error contains the actual cause. After successful sign-in, GCM caches a refresh token and renews access tokens without opening the browser each time.

## Manual Git configuration (alternative)

Add this block to your global git config (`~/.gitconfig`), replacing the placeholders:

```ini
[credential "https://<DATA_API_HOST>"]
    provider = generic
    oauthClientId = <YOUR_PUBLIC_CLIENT_APP_ID>
    oauthRedirectUri = http://localhost:8400/
    oauthScopes = https://azure-apicenter.net/Data.Read.All offline_access
    oauthAuthorizeEndpoint = https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/authorize
    oauthTokenEndpoint = https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token
    oauthUseClientAuthHeader = false
    credentialStore = dpapi
```

- `<DATA_API_HOST>` — your catalog's data-plane host, e.g. `myapic.data.uksouth.azure-apicenter.ms` (the `dataApiHostName` from the portal resource).
- `<TENANT_ID>` — your Entra tenant GUID. You can discover the host's tenant and scope from `https://<DATA_API_HOST>/.well-known/oauth-protected-resource`.
- `oauthRedirectUri` must exactly match the URI registered under the Entra app's **Mobile and desktop applications** platform. A fixed port avoids ambiguity because GCM otherwise replaces an unqualified `http://localhost` redirect with a random available port at runtime.
- `credentialStore = dpapi` is host-scoped and avoids the Windows Credential Manager size limit for large Entra tokens (`Failed to write item to store. [0x6f7]`). On macOS/Linux this line can be omitted.

<details>
<summary><code>Set-ApiCenterGitCredentialManager.ps1</code> (standalone host-only variant)</summary>

```powershell
#requires -Version 5.1
<#
.SYNOPSIS
    Configure Git Credential Manager (GCM) generic-OAuth for an Entra-protected
    Git-over-HTTP host (e.g. Azure API Center 'marketplace.git'), auto-discovering
    the OAuth endpoints, issuer and scope from the host itself.

.DESCRIPTION
    Discovery chain (no hard-coded tenant/endpoints):
      1. GET https://<host>/.well-known/oauth-protected-resource   (RFC 9728)
           -> resource (audience id), authorization_servers[0] (issuer),
              scopes_supported (the scope to request)
         Fallback: parse  WWW-Authenticate: Bearer authorization_uri="..."
                   from the 401 challenge if the metadata doc is unavailable.
      2. GET <issuer>/.well-known/openid-configuration             (OIDC / RFC 8414)
           -> authorization_endpoint, token_endpoint, device_authorization_endpoint
      3. Write the resulting GCM generic-OAuth keys to git config.

    The script uses browser-based authorization code with PKCE. Device code is not configured.

.PARAMETER Hostname
    The Git host. Scheme optional, path ignored. e.g. test-v2-stage-5.azure-api.net

.PARAMETER ClientId
    Public-client (app) ID used to sign the user in (the OAuth *caller*). REQUIRED.
    It must be (a) authorized to request the resource scope
    (e.g. https://azure-apicenter.net/user_impersonation) and (b) configured as a public
    client: the fixed loopback redirect under "Mobile and desktop applications" plus
    "Allow public client flows".
    Good choices: the API Center portal's app (portals/default -> authentication.clientId),
    or your own app registration granted the API Center delegated permission.
    WARNING: Microsoft first-party clients such as the Azure CLI client
    (04b07795-8ddb-461a-bbee-02f9e1bf7b46) do NOT work for Azure API Center - they fail
    with AADSTS65002 because 1P-to-1P token requests require preauthorization by the API owner.

.PARAMETER Scope
    Override the OAuth scope string. If omitted, 'scopes_supported' from discovery is
    used (falling back to '<resource>/.default'). 'offline_access' is always appended.

.PARAMETER RedirectPort
    Fixed localhost callback port. Defaults to 8400. Register
    'http://localhost:<port>/' under "Mobile and desktop applications".

.PARAMETER ConfigScope
    git config target: global (default), local, or system.

.PARAMETER CredentialStore
    GCM credential store backend, written HOST-SCOPED (credential.<host>.credentialStore)
    so only this host is affected - other hosts keep their existing/default store.
    Defaults to 'dpapi' (file-based, DPAPI-encrypted) which avoids the Windows Credential
    Manager ~2.5 KB blob limit that makes large Entra tokens fail to persist with
    "Failed to write item to store. [0x6f7]". Use 'wincredman' for the Windows default,
    'cache' for in-memory only, or 'none' to disable persistence.

.PARAMETER ClearExisting
    Erase any cached credential for the host before configuring (clears a stale
    username/password you may have typed earlier).

.PARAMETER DryRun
    Print the resolved configuration without writing anything.

.EXAMPLE
    .\Set-ApiCenterGitCredentialManager.ps1 -Hostname rokolesnikov-test-apic.data.uksouth.azure-apicenter.ms -ClientId 3ec39262-a731-49dd-95b9-69e27641fceb -ClearExisting

.EXAMPLE
    .\Set-ApiCenterGitCredentialManager.ps1 -Hostname myapic.data.<region>.azure-apicenter.ms -ClientId <your-public-client-app-id> -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Hostname,

    [Parameter(Mandatory)]
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
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

# ---------- helpers ----------
function Get-Json([string] $Url) {
    Write-Verbose "GET $Url"
    return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = 'application/json' }
}

function Get-WwwAuthenticate([string] $Url) {
    # Version-safe: HttpClient does not throw on 401 and exposes response headers uniformly.
    try { Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue } catch { }
    $client = [System.Net.Http.HttpClient]::new()
    try {
        $resp = $client.GetAsync($Url).GetAwaiter().GetResult()
        if ($resp.Headers.Contains('WWW-Authenticate')) {
            return ($resp.Headers.GetValues('WWW-Authenticate') -join ', ')
        }
        return $null
    } finally { $client.Dispose() }
}

# ---------- normalize host -> origin ----------
$raw = $Hostname.Trim()
if ($raw -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $raw = "https://$raw" }
$u = [Uri]$raw
$origin = '{0}://{1}' -f $u.Scheme, $u.Authority    # scheme + host[:non-default-port]
$redirectUri = "http://localhost:$RedirectPort/"
Write-Host "Target host : $origin" -ForegroundColor Cyan

# ---------- 1) protected-resource metadata (RFC 9728) ----------
$resource = $null; $issuer = $null; $scopesSupported = @()
$prmUrl = "$origin/.well-known/oauth-protected-resource"
try {
    $prm = Get-Json $prmUrl
    $resource        = $prm.resource
    $issuer          = @($prm.authorization_servers)[0]
    $scopesSupported = @($prm.scopes_supported)
    Write-Host "Discovered  : $prmUrl" -ForegroundColor Green
} catch {
    Write-Warning "Protected-resource metadata unavailable ($($_.Exception.Message)); using WWW-Authenticate fallback."
}

# ---------- 1b) fallback: authorization_uri from the 401 challenge ----------
if (-not $issuer) {
    $probe = "$origin/.well-known/oauth-protected-resource"  # anonymous; if it 401s we still get the header
    $www = Get-WwwAuthenticate $probe
    if ($www -match 'authorization_uri="?([^",\s]+)"?') { $issuer = $Matches[1] }
    if (-not $resource -and $www -match '\bresource="?([^",\s]+)"?') { $resource = $Matches[1] }
    if ($issuer) { Write-Host "Discovered  : authorization_uri via WWW-Authenticate" -ForegroundColor Green }
}
if (-not $issuer) { throw "Could not determine the authorization server (issuer) for $origin." }

# ---------- 2) authorization-server metadata (OIDC / RFC 8414) ----------
$issuerTrim = $issuer.TrimEnd('/')
$asMeta = $null
foreach ($wk in @("$issuerTrim/.well-known/openid-configuration", "$issuerTrim/.well-known/oauth-authorization-server")) {
    try { $m = Get-Json $wk; if ($m.authorization_endpoint) { $asMeta = $m; break } } catch { }
}
if (-not $asMeta) { throw "Could not read authorization-server metadata from issuer '$issuer'." }
$authorizeEp = $asMeta.authorization_endpoint
$tokenEp     = $asMeta.token_endpoint

# ---------- 3) scope ----------
if ($Scope) {
    $scopes = $Scope
} elseif ($scopesSupported.Count -gt 0) {
    $scopes = ($scopesSupported -join ' ')
} elseif ($resource) {
    $scopes = "$($resource.TrimEnd('/'))/.default"
} else {
    throw "Could not determine an OAuth scope (no -Scope, no scopes_supported, no resource)."
}
if ($scopes -notmatch '(^|\s)offline_access(\s|$)') { $scopes = "$scopes offline_access" }

# ---------- summary ----------
$resourceShown = if ($resource) { $resource } else { '(n/a)' }
Write-Host ''
Write-Host 'Resolved configuration:' -ForegroundColor Cyan
Write-Host ("  resource (id)   : {0}" -f $resourceShown)
Write-Host ("  issuer          : {0}" -f $issuer)
Write-Host ("  clientId        : {0}" -f $ClientId)
Write-Host ("  scopes          : {0}" -f $scopes)
Write-Host ("  authorizeEp     : {0}" -f $authorizeEp)
Write-Host ("  tokenEp         : {0}" -f $tokenEp)
Write-Host ("  redirect        : {0}" -f $redirectUri)
Write-Host ("  credentialStore : {0}  (host-scoped)" -f $CredentialStore)
Write-Host ''

if ($DryRun) { Write-Host 'Dry run - no git config written.' -ForegroundColor Yellow; return }

# ---------- 4) write git config ----------
$key = "credential.$origin"
$scopeFlag = "--$ConfigScope"
function Set-GitConfig([string] $Name, [string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    git config $scopeFlag "$key.$Name" $Value | Out-Null
}
Set-GitConfig 'provider'                'generic'
Set-GitConfig 'oauthClientId'           $ClientId
Set-GitConfig 'oauthRedirectUri'        $redirectUri
Set-GitConfig 'oauthScopes'             $scopes
Set-GitConfig 'oauthAuthorizeEndpoint'  $authorizeEp
Set-GitConfig 'oauthTokenEndpoint'      $tokenEp
Set-GitConfig 'oauthUseClientAuthHeader' 'false'   # public client (PKCE, no secret)
Set-GitConfig 'credentialStore'          $CredentialStore   # host-scoped store; dpapi avoids wincred 0x6f7 on large tokens
git config $scopeFlag --unset-all "$key.oauthDeviceEndpoint" 2>$null
Write-Host "Wrote $ConfigScope git config under [$key]." -ForegroundColor Green

# ---------- 5) optionally clear cached credential ----------
if ($ClearExisting) {
    Write-Host "Clearing cached credential for $($u.Authority) ..." -ForegroundColor Cyan
    "protocol=$($u.Scheme)`nhost=$($u.Authority)`n" | git credential reject 2>$null
}

Write-Host ''
Write-Host 'Done. Test with a clone, e.g.:' -ForegroundColor Cyan
Write-Host "  git clone $origin/workspaces/default/plugins/marketplace.git"
Write-Host ''
Write-Host 'NOTE: GCM returns the Entra token as the Basic *password*. The server must' -ForegroundColor DarkYellow
Write-Host '      accept that (APIM Basic->Bearer policy or backend change), or the clone' -ForegroundColor DarkYellow
Write-Host '      will still 401 after a successful sign-in.' -ForegroundColor DarkYellow
```

</details>

## Troubleshooting

| Symptom | Cause / Fix |
|---------|-------------|
| `AADSTS7000218: … 'client_assertion' or 'client_secret'` | The app is not a public client. Register `http://localhost:8400/` under **Mobile and desktop applications** and enable **Allow public client flows**. |
| `AADSTS9002327: Tokens issued for the 'Single-Page Application' client-type…` | Entra classified the callback as an SPA redirect. Ensure the exact configured URI (default `http://localhost:8400/`) exists only under **Mobile and desktop applications**, remove the same URI from **Single-page application**, rerun the setup script with `-ClearExisting`, and allow time for Entra configuration propagation. Do not use `https://localhost`. |
| `AADSTS65002: … must be configured via preauthorization` | You used a Microsoft first-party client (e.g. the Azure CLI client). Register and use your own app per step 1. |
| `fatal: Failed to write item to store. [0x6f7]` | Set host-scoped `credentialStore = dpapi` (step 2). |
| Git asks `Username for 'https://…'` after browser sign-in | GCM's OAuth exchange failed and Git fell back to an interactive Basic prompt. Cancel with `Ctrl+C`; entering a username cannot fix it. Diagnose the preceding Entra/GCM error first. |
| 401 after a successful sign-in | The catalog is not AzureRbac, or the token lacks `Data.Read.All` / the required RBAC role. Confirm `https://<DATA_API_HOST>/.well-known/oauth-protected-resource` lists `Data.Read.All`. |
| Clone fails with a `500` right after sign-in (empty body) | Known issue on builds before the `JwtBearerTokenHelper` fix: any `Basic`-authenticated request threw during request logging (before auth), yielding an empty 500. Update to the latest Data API build. Engineering detail: [Marketplace Git — Auth Pipeline Internals](../../Copilot/DataAPI/marketplace-git-auth-internals.md). |