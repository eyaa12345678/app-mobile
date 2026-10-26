[CmdletBinding()]
param(
    [ValidateRange(1, 65535)]
    [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Keep credentials in this process; never write them to the project or registry.
$previousPassword = $env:MAIL_PASSWORD
Push-Location $PSScriptRoot
try {
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        $jdkCandidates = @()
        if ($env:JAVA_HOME) { $jdkCandidates += $env:JAVA_HOME }
        $jdkFolder = Join-Path $env:USERPROFILE '.jdks'
        if (Test-Path $jdkFolder) {
            $jdkCandidates += @(Get-ChildItem $jdkFolder -Directory | Sort-Object Name -Descending | ForEach-Object { $_.FullName })
        }
        foreach ($candidate in $jdkCandidates) {
            if ((Test-Path (Join-Path $candidate 'bin\java.exe')) -and (Test-Path (Join-Path $candidate 'bin\javac.exe'))) {
                $env:JAVA_HOME = $candidate
                $env:Path = (Join-Path $candidate 'bin') + [IO.Path]::PathSeparator + $env:Path
                break
            }
        }
    }
    if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
        throw 'Java introuvable. Installez un JDK 21 et configurez JAVA_HOME, puis relancez ce script.'
    }

    $maven = Get-Command mvn.cmd -ErrorAction SilentlyContinue
    if (-not $maven) { $maven = Get-Command mvn -ErrorAction SilentlyContinue }
    $mavenPath = if ($maven) { $maven.Source } else { $null }
    if (-not $mavenPath) {
        $jetbrainsFolder = Join-Path $env:ProgramFiles 'JetBrains'
        if (Test-Path $jetbrainsFolder) {
            foreach ($idea in @(Get-ChildItem $jetbrainsFolder -Directory -Filter 'IntelliJ IDEA*' | Sort-Object Name -Descending)) {
                $candidate = Join-Path $idea.FullName 'plugins\maven\lib\maven3\bin\mvn.cmd'
                if (Test-Path $candidate) { $mavenPath = $candidate; break }
            }
        }
    }
    if (-not $mavenPath) {
        throw 'Maven introuvable. Ajoutez son dossier bin au PATH, puis relancez ce script.'
    }

    Write-Host 'Construction du backend...' -ForegroundColor Cyan
    & $mavenPath '-DskipTests' 'package'
    if ($LASTEXITCODE -ne 0) { throw 'La compilation a echoue. Corrigez les erreurs Maven affichees ci-dessus.' }

    $gmailAddress = (Read-Host 'Adresse Gmail du compte ayant cree le mot de passe application').Trim()
    if ([string]::IsNullOrWhiteSpace($gmailAddress) -or $gmailAddress -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
        throw 'Adresse email invalide. Relancez le script avec votre adresse Gmail complete.'
    }
    $smtpSecret = Read-Host 'Mot de passe application Google (16 caracteres, saisie masquee)' -AsSecureString
    try {
        $env:MAIL_PASSWORD = ([System.Net.NetworkCredential]::new('', $smtpSecret)).Password.Replace(' ', '')
    } finally {
        $smtpSecret.Dispose()
    }
    if ([string]::IsNullOrEmpty($env:MAIL_PASSWORD) -or $env:MAIL_PASSWORD.Length -ne 16) {
        throw 'Le mot de passe application doit contenir 16 caracteres (espaces ignores). Utilisez le code genere par Google.'
    }
    $env:MAIL_HOST = 'smtp.gmail.com'
    $env:MAIL_PORT = '587'
    $env:MAIL_USERNAME = $gmailAddress
    $env:MAIL_FROM = $gmailAddress
    $env:MAIL_SMTP_AUTH = 'true'
    $env:MAIL_STARTTLS = 'true'

    Write-Host "Demarrage sur http://localhost:$Port ; verification SMTP avant ouverture du serveur..." -ForegroundColor Cyan
    Write-Host 'Ce controle SMTP ne transmet aucun email. Gardez cette fenetre ouverte.'
    & java '-jar' 'target\medicare-backend-1.0.0.jar' '--spring.profiles.active=dev' "--server.port=$Port" '--spring.mail.test-connection=true' '--spring.mail.properties.mail.debug=false'
    if ($LASTEXITCODE -ne 0) {
        throw 'Le backend ne peut pas demarrer. Consultez la derniere cause affichee : AuthenticationFailedException = compte/code Google ; connexion refusee ou delai = reseau SMTP ; port already in use = autre backend deja lance.'
    }
} finally {
    $env:MAIL_PASSWORD = $previousPassword
    Pop-Location
}
