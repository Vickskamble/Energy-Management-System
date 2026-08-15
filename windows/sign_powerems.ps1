param(
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [string]$CertSubject = "CN=PowerEMS, O=Brilliants Automation and Software Solutions, C=IN"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Target)) {
    Write-Host "[sign] ERROR: target not found: $Target"
    exit 1
}

$Target = (Resolve-Path -LiteralPath $Target).Path

$signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\x64\\" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $signtool) {
    Write-Host "[sign] ERROR: signtool.exe not found under Windows Kits."
    exit 1
}

$cert = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object {
        $_.Subject -like "*PowerEMS*" -and
        ([string]$_.EnhancedKeyUsageList) -match "Code Signing"
    } |
    Select-Object -First 1

if (-not $cert) {
    Write-Host "[sign] Self-signed code-signing certificate not found - creating it..."
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $CertSubject `
        -CertStoreLocation Cert:\CurrentUser\My `
        -KeyExportPolicy Exportable `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears(3)
}

function Invoke-Sign([string[]]$Arguments) {
    $null = & $signtool @Arguments
    return $LASTEXITCODE
}

# NOTE: signtool stops parsing options at the first positional (file) argument,
# so the target file must always come LAST.

$base = @("sign", "/fd", "SHA256", "/sha1", $cert.Thumbprint)

$exitCode = Invoke-Sign @($base + @("/tr", "http://timestamp.digicert.com", "/td", "SHA256", $Target))
if ($exitCode -ne 0) {
    Write-Host "[sign] Timestamped signing failed (offline?), retrying without timestamp..."
    $exitCode = Invoke-Sign @($base + @($Target))
}

if ($exitCode -ne 0) {
    Write-Host "[sign] ERROR: signtool failed with exit code $exitCode"
    exit 1
}

Write-Host "[sign] Signed: $Target"
exit 0