# Passwortabfrage und Sicherung als SecureString
function Get-Password {
    <#
    .SYNOPSIS
    Liest ein Passwort von der Konsole ein und gibt es als SecureString zurück.
    .DESCRIPTION
    Diese Funktion liest ein Passwort von der Konsole ein und wandelt es in einen SecureString um. Das Passwort wird zweimal eingegeben und überprüft, um sicherzustellen, dass es korrekt eingegeben wurde. Es wird auch überprüft, ob das Passwort den Anforderungen an Komplexität entspricht, die über die Parameter $MinimumLength, $MinimumUpperCase, $MinimumLowerCase und $MinimumDigit festgelegt werden können.

    .EXAMPLE
    PS C:\> $password = Get-Password -MinimumLength 8 -MinimumUpperCase 1 -MinimumLowerCase 1 -MinimumDigit 1

    Gibt eine Passwortabfrage auf der Konsole aus und gibt das eingegebene Passwort als SecureString zurück. Das Passwort muss mindestens 8 Zeichen lang sein und mindestens einen Großbuchstaben, einen Kleinbuchstaben und eine Ziffer enthalten.

    .NOTES
    Diese Funktion erfordert PowerShell 2.0 oder höher.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MinimumLength = 8,
        [Parameter()]
        [int]$MinimumUpperCase = 1,
        [Parameter()]
        [int]$MinimumLowerCase = 1,
        [Parameter()]
        [int]$MinimumDigit = 1
    )

    # Passwort abfragen und in SecureString umwandeln
    do {
        $securePassword = Read-Host "Geben Sie ein sicheres Passwort ein" -AsSecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

        if ($password.Length -lt $MinimumLength) {
            Write-Error "Das Passwort muss mindestens $MinimumLength Zeichen lang sein."
            continue
        }

        if (($password -cmatch "[A-Z]") -and ($password -cmatch "[a-z]") -and ($password -cmatch "[0-9]")) {
            $countUpperCase = ($password -replace "[^A-Z]").Length
            $countLowerCase = ($password -replace "[^a-z]").Length
            $countDigit = ($password -replace "[^\d]").Length

            if (($countUpperCase -ge $MinimumUpperCase) -and ($countLowerCase -ge $MinimumLowerCase) -and ($countDigit -ge $MinimumDigit)) {
                $securePasswordConfirm = Read-Host "Geben Sie das Passwort zur Bestätigung ein" -AsSecureString
                $passwordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordConfirm))

                if ($password -ne $passwordConfirm) {
                    Write-Error "Die Passwörter stimmen nicht überein."
                    continue
                }

                return $securePassword
            }
        }

        Write-Error "Das Passwort erfüllt nicht die Anforderungen an Komplexität. Es muss mindestens $MinimumUpperCase Großbuchstaben, $MinimumLowerCase Kleinbuchstaben und $MinimumDigit Ziffern enthalten."
    } while ($true)
}


# Backup-Funktion mit 7zip# Backup-Funktion mit 7zip
function Backup-Folder {
    <#
    .SYNOPSIS
        Erstellt ein 7zip-Archiv eines Ordners mit optional benutzerdefiniertem Namen und einem Kennwort. Alte Backups werden automatisch gelöscht.
    .PARAMETER SourceFolder
        Der Pfad des zu sichernden Ordners.
    .PARAMETER BackupName
        Der Name des Backups. Wenn nicht angegeben, wird das aktuelle Datum und die aktuelle Zeit verwendet.
    .PARAMETER Password
        Das Kennwort, das zur Verschlüsselung des 7zip-Archivs verwendet werden soll. Der Wert muss vom Typ SecureString sein.
    .EXAMPLE
        Backup-Folder -SourceFolder 'C:\Users\Benutzer\Documents' -Password $SecurePassword
    .EXAMPLE
        Backup-Folder -SourceFolder 'C:\Users\Benutzer\Documents' -BackupName 'Mein Backup' -Password $SecurePassword
    #>

    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType 'Container'})]
        [string]$SourceFolder,

        [Parameter(Mandatory = $false)]
        [string]$BackupName,

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Password
    )

    # Wenn kein Backup-Name angegeben wurde, wird der ursprüngliche Ordnername verwendet.
    if (!$BackupName) {
        $BackupName = (Split-Path $SourceFolder -Leaf)
    }

    # Erstellt den Pfad, in dem das Backup gespeichert wird, wenn er noch nicht existiert.
    $BackupPath = "$env:USERPROFILE\OneDrive\06 - Backups\$BackupName"
    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath | Out-Null
    }

    # Erstellt den Namen und Pfad des 7zip-Archivs, das erstellt werden soll.
    $Date = (Get-Date).ToString("yyyy-MM")
    $ArchiveName = "$Date-$BackupName.7z"
    $ArchivePath = Join-Path $BackupPath $ArchiveName

    # Parameter für das Compress-7Zip-Cmdlet.
    $ZipArgs = @{
        Path = $SourceFolder
        CompressionLevel = 'Ultra'
        CompressionMethod = 'LZMA2'
        SecurePassword = $Password
        ArchiveFileName = $ArchivePath
        EncryptFilenames = $true
    }

    # Speichert die aktuelle Zeit vor der Komprimierung des Ordners.
    $StartTime = Get-Date

    # Ausgabe, welche Datei gerade komprimiert wird.
    Write-Output "Komprimiere: $BackupName"

    # Komprimiert den Ordner mit 7zip.
    Compress-7Zip @ZipArgs | Out-Null

    # Speichert die Zeit nach der Komprimierung des Ordners und berechnet die Dauer.
    $EndTime = Get-Date
    $Duration = New-TimeSpan -Start $StartTime -End $EndTime

    # Entfernt alte Backups, wenn es mehr als 12 Backups gibt.
    $BackupList = Get-ChildItem $BackupPath -Filter *.7z
    if ($BackupList.Count -gt 12) {
        $OldestBackup = $BackupList | Sort-Object CreationTime | Select-Object -First 1
        Remove-Item $OldestBackup.FullName
    }

    # Berechnet die Dauer des Backup-Vorgangs und Ausgabe, dass das Backup erfolgreich erstellt wurde.
    $DurationString = "{0:F3}" -f $Duration.TotalSeconds
    Write-Output -NoNewline "Backup erstellt: $ArchiveName in $DurationString Sekunden"
    Write-Output ""
}

# Main-Skript
$Password = Get-Password

# Backup-Folder-Funktion aufrufen für jeden Ordner mit individuellem Backup-Namen
$BackupFolders = @(
    @{Name="Bilder"; Path="$env:USERPROFILE\OneDrive\01 - Bilder\Eigene Aufnahmen"; BackupName="Bilder"},
    @{Name="y-mume"; Path="$env:USERPROFILE\.mume"; BackupName="x-mume"}
)
foreach ($Folder in $BackupFolders) {
    Backup-Folder -SourceFolder $Folder.Path -BackupName $Folder.BackupName -Password $Password
}

