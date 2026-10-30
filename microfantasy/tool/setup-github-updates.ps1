param(
    [string]$Repository = 'Asdii/V90-Fantasy-Designer',
    [string]$Keystore = (Join-Path $env:USERPROFILE '.android/debug.keystore'),
    [string]$KeyAlias = 'androiddebugkey',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$localGh = Join-Path $root 'outputs/toolchains/gh/bin/gh.exe'
$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
$gh = if ($ghCommand) { $ghCommand.Source } elseif (Test-Path -LiteralPath $localGh) { $localGh } else { $null }
if (-not $gh) { throw 'Install GitHub CLI: winget install --id GitHub.cli --exact; then run this script again.' }
if ($Repository -ne 'Asdii/V90-Fantasy-Designer') { throw 'The app update URL is configured for Asdii/V90-Fantasy-Designer.' }
if (-not (Test-Path -LiteralPath $Keystore -PathType Leaf)) { throw "Signing key not found: $Keystore. Do not generate a replacement for an installed APK." }
$keytoolCommand = Get-Command keytool -ErrorAction SilentlyContinue
$keytool = if ($keytoolCommand) { $keytoolCommand.Source } else { 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' }
if (-not (Test-Path -LiteralPath $keytool)) { throw 'Java keytool is required to verify the signing certificate.' }

# Preserve the key used for the existing development APK. Never commit it or
# pass secrets in command-line arguments. Custom keystores can use env passwords.
$priorToken = $env:GH_TOKEN
$priorStore = $env:MICROFANTASY_SETUP_STORE_PASSWORD
$priorKey = $env:MICROFANTASY_SETUP_KEY_PASSWORD
$priorPrompt = $env:GIT_TERMINAL_PROMPT
$priorInteractive = $env:GCM_INTERACTIVE
try {
    if (-not $env:MICROFANTASY_SETUP_STORE_PASSWORD) { $env:MICROFANTASY_SETUP_STORE_PASSWORD = 'android' }
    if (-not $env:MICROFANTASY_SETUP_KEY_PASSWORD) { $env:MICROFANTASY_SETUP_KEY_PASSWORD = 'android' }
    $keyInfo = & $keytool '-J-Duser.language=en' -list -v -keystore $Keystore '-storepass:env' MICROFANTASY_SETUP_STORE_PASSWORD -alias $KeyAlias 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the signing key. Verify its alias/password.' }
    $match = [regex]::Match(($keyInfo -join "`n"), 'SHA256:\s*([A-Fa-f0-9:]{95})')
    if (-not $match.Success) { throw 'Could not identify the signing certificate.' }
    $fingerprint = $match.Groups[1].Value.Replace(':', '').ToLowerInvariant()

    & $gh auth status --hostname github.com *> $null
    if ($LASTEXITCODE -ne 0) {
        # Use the user's existing Git HTTPS login for this repository only.
        # Capture credentials in memory; never print or write them to disk.
        $env:GIT_TERMINAL_PROMPT = '0'
        $env:GCM_INTERACTIVE = 'never'
        $credential = "protocol=https`nhost=github.com`n`n" | git -c credential.interactive=false credential fill 2>$null
        if ($LASTEXITCODE -eq 0) {
            $passwordLine = $credential | Where-Object { $_ -like 'password=*' } | Select-Object -First 1
            if ($passwordLine) { $env:GH_TOKEN = $passwordLine.Substring(9) }
        }
        $credential = $null
        $passwordLine = $null
    }
    $repoInfo = & $gh repo view $Repository --json nameWithOwner,viewerPermission,isPrivate 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Sign in first: `"$gh`" auth login --hostname github.com --web" }
    $repo = $repoInfo | ConvertFrom-Json
    if ($repo.nameWithOwner -ne $Repository -or $repo.isPrivate -or $repo.viewerPermission -notin @('ADMIN', 'MAINTAIN', 'WRITE')) {
        throw 'A public release repository and write access are required.'
    }
    Write-Host "Repository verified: $Repository"
    Write-Host "Signing certificate SHA-256: $fingerprint"
    if ($CheckOnly) { Write-Host 'Ready to provision encrypted Actions secrets.'; return }

    $existing = & $gh variable get MICROFANTASY_SIGNING_SHA256 --repo $Repository 2>$null
    if ($LASTEXITCODE -eq 0 -and $existing.Trim() -ne $fingerprint) { throw 'The repository already uses another signer. Refusing to change it.' }
    $secretJson = & $gh secret list --repo $Repository --json name
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect repository secrets.' }
    $names = @($secretJson | ConvertFrom-Json | ForEach-Object { $_.name })
    if (-not $existing -and $names -contains 'MICROFANTASY_KEYSTORE_BASE64') {
        throw 'An existing signing secret has no fingerprint record; verify it before replacing anything.'
    }
    $secrets = @{
        MICROFANTASY_KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Keystore)))
        MICROFANTASY_STORE_PASSWORD = $env:MICROFANTASY_SETUP_STORE_PASSWORD
        MICROFANTASY_KEY_PASSWORD = $env:MICROFANTASY_SETUP_KEY_PASSWORD
        MICROFANTASY_KEY_ALIAS = $KeyAlias
    }
    foreach ($name in $secrets.Keys) {
        $secrets[$name] | & $gh secret set $name --repo $Repository
        if ($LASTEXITCODE -ne 0) { throw "Could not save $name. Run setup again before publishing." }
    }
    $fingerprint | & $gh variable set MICROFANTASY_SIGNING_SHA256 --repo $Repository
    if ($LASTEXITCODE -ne 0) { throw 'Could not save the public signing fingerprint.' }
    Write-Host 'Signing configured. Commit and push main to publish Android updates.'
} finally {
    $env:GH_TOKEN = $priorToken
    $env:MICROFANTASY_SETUP_STORE_PASSWORD = $priorStore
    $env:MICROFANTASY_SETUP_KEY_PASSWORD = $priorKey
    $env:GIT_TERMINAL_PROMPT = $priorPrompt
    $env:GCM_INTERACTIVE = $priorInteractive
    $credential = $null
    $passwordLine = $null
    $secrets = $null
}
