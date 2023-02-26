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
    Compress-7Zip @ZipArgs > $null

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
    Write-Output "Backup erstellt: $ArchiveName in $DurationString Sekunden"
    Write-Output ""
}
function Move-BackupFiles {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$BackupName,
        [string]$SearchPattern = "",
        [string]$SearchFolder = "$env:USERPROFILE\Downloads",
        [string]$TargetFolder = "$env:USERPROFILE\Downloads",
        [switch]$Copy,
        [switch]$Move,
        [switch]$Recurse,
        [switch]$NoRename
    )

    # Durchsuche das Quellverzeichnis nach passenden Dateien
    $items = Get-ChildItem -Path $SearchFolder -Recurse:$Recurse

    # Wenn mindestens eine passende Datei oder ein passendes Verzeichnis gefunden wurde
    if ($items) {
        # Erstelle das Zielverzeichnis, falls es nicht bereits vorhanden ist
        if (!(Test-Path $TargetFolder\$BackupName)) {
            New-Item -ItemType Directory -Path $TargetFolder\$BackupName | Out-Null
        }

        # Kopieren/Verschieben alle passenden Dateien/Verzeichnisse in das Zielverzeichnis und benenne sie um
        $date = Get-Date -Format "yyyy-MM"
        foreach ($item in $items) {
            $relativePath = $item.FullName.Substring($SearchFolder.Length)
            if ($item.PSIsContainer) {
                # Wenn es sich um ein Verzeichnis handelt, erstelle es im Zielverzeichnis
                $destinationDirectory = Join-Path $TargetFolder\$BackupName $relativePath
                New-Item -ItemType Directory -Path $destinationDirectory | Out-Null
            } else {
                # Wenn es sich um eine Datei handelt, kopiere/verschiebe sie ins Zielverzeichnis und benenne sie um
                $newName = $item.Name
                if (!$NoRename) {
                    $newName = '{0}-{1}-{3}-Backup.{2}' -f $date, $BackupName, $item.NameString ,$item.Extension.TrimStart('.')
                }
                $destinationFile = Join-Path $TargetFolder\$BackupName $relativePath.Replace($item.Name, $newName)
                if ($Copy) {
                    Copy-Item $item.FullName $destinationFile
                } elseif ($Move) {
                    Move-Item $item.FullName $destinationFile
                }
            }
        }

        # Hinzufügen des neuen Eintrags zu $BackupFolders
        $global:BackupFolders += [PSCustomObject] @{
            Path = "$TargetFolder\$BackupName"
            BackupName = $BackupName
        }
    } else {
        # Wenn keine passende Datei oder Verzeichnis gefunden wurde, gib eine Warnung aus
        Write-Warning "Keine Dateien oder Verzeichnisse mit dem Suchmuster '$SearchPattern' im Verzeichnis '$SearchFolder' gefunden. Backup '$BackupName' wurde nicht erstellt."
    }
}

function Copy-RemoteData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$serverName, # Name des Remote-Servers

        [Parameter(Mandatory=$true, Position=1)]
        [string]$remotePath, # Pfad auf dem Remote-Server

        [Parameter(Mandatory=$true, Position=2)]
        [string]$name, # Name des Ordners, in dem die Daten gespeichert werden

        [Parameter(Position=3)]
        [string]$destinationPath = "$env:USERPROFILE\Downloads" # Standardzielverzeichnis auf dem lokalen Computer
    )

    # Kombinieren von Servernamen und Pfad auf dem Remote-Server zu einem SCP-kompatiblen Pfad
    $sourcePath = "$serverName`:$remotePath"

    # Verzeichnis für die Dateien erstellen
    $directoryPath = Join-Path $destinationPath $name
    New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null

    # Ausführen des scp-Befehls, um die Daten in das Verzeichnis zu kopieren
    scp $sourcePath $directoryPath > $null

    # Hinzufügen des Verzeichnisses zur globalen Sicherungsliste
    $global:BackupFolders += [PSCustomObject] @{
        Path = $directoryPath
        BackupName = $name
    }
}

# Main-Skript
$Password = Get-Password

# Initialisiere das Array $BackupFolders als leeres Array
$global:BackupFolders = @()


# ======================================
#           Draytek Backup
# ======================================
Move-BackupFiles -BackupName "Draytek" -SearchPattern '.*modem.*\.cfg$'

# ======================================
#               Bitwarden
# ======================================
Move-BackupFiles -BackupName "Bitwarden" -SearchPattern '.*bitwarden.*\.json$'

# ======================================
#              Portainer                
# ======================================
Move-BackupFiles -BackupName "Portainer" -SearchPattern '.*portainer-backup.*\.tar.gz$'

# ======================================
#                 Unifi
# ======================================
Move-BackupFiles -BackupName "Unifi" -SearchPattern '.*\.(unf|unifi)$'

# ======================================
#                 Heimdal
# ======================================
Move-BackupFiles -BackupName "Heimdal" -SearchPattern '.*heimdallexport.*\.json$'

# ======================================
#               Diskstation
# ======================================
Move-BackupFiles -BackupName "Diskstation" -SearchPattern '.*diskstation.*\.dss$'

# ======================================
#                  CURA
# ======================================
# Suchen Sie nach dem Ordner mit der höchsten Versionsnummer im Pfad
$SearchFolder = Get-ChildItem $env:APPDATA\cura\ -Directory | Sort-Object @{ Expression = { [regex]::Replace($_.Name, '.*(\d+(\.\d+)*)$', '$1') } } -Descending
$SelectedFolder = $SearchFolder | Select-Object -First 1
$SearchFolder = Join-Path $SelectedFolder.FullName "quality_changes"
Move-BackupFiles -BackupName "Cura" -SearchPattern '.*\.(txt|cfg)$' -SearchFolder $SearchFolder -Mode "Copy"

# ======================================
#                 PiHole
# ======================================
Copy-RemoteData -serverName "Docker-Pi-1" -remotePath "/home/erik/backup/*-pihole-backup.tar.gz" -name "PiHole"

# ======================================
#                GitHub
# ======================================
Move-BackupFiles -BackupName "GitHub" -SearchFolder $env:USERPROFILE\Documents\GitHub\ -Copy -Recurse -NoRename


foreach ($Folder in $BackupFolders) {
    Backup-Folder -SourceFolder $Folder.Path -BackupName $Folder.BackupName -Password $Password
}