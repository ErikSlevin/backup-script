function Get-Password {
    <#
    .SYNOPSIS
    Diese Funktion liest ein Passwort von der Konsole ein und gibt es als SecureString zurück.

    .DESCRIPTION
    Diese Funktion liest ein Passwort von der Konsole ein und wandelt es in einen SecureString um.
    Es wird empfohlen, ein sicheres Passwort zu verwenden, um die Sicherheit des Systems zu gewährleisten.
    Die Funktion überprüft das Passwort auf Länge und Komplexität, um sicherzustellen, dass es ausreichend sicher ist.

    .PARAMETER MinimumLength
    Die minimale Länge des Passworts. Der Standardwert ist 8.

    .PARAMETER MinimumUpperCase
    Die minimale Anzahl von Großbuchstaben, die das Passwort enthalten muss. Der Standardwert ist 1.

    .PARAMETER MinimumLowerCase
    Die minimale Anzahl von Kleinbuchstaben, die das Passwort enthalten muss. Der Standardwert ist 1.

    .PARAMETER MinimumDigit
    Die minimale Anzahl von Ziffern, die das Passwort enthalten muss. Der Standardwert ist 1.

    .EXAMPLE
    PS C:\> $password = Get-Password -MinimumLength 8 -MinimumUpperCase 1 -MinimumLowerCase 1 -MinimumDigit 1

    Gibt eine Passwortabfrage auf der Konsole aus und gibt das eingegebene Passwort als SecureString zurück.
    Das Passwort muss mindestens 8 Zeichen lang sein und mindestens einen Großbuchstaben, einen Kleinbuchstaben und eine Ziffer enthalten.

    .NOTES
    Diese Funktion erfordert PowerShell 2.0 oder höher.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MinimumLength = 8,                  # Minimale Länge des Passworts
        [Parameter()]
        [int]$MinimumUpperCase = 1,               # Minimale Anzahl an Großbuchstaben
        [Parameter()]
        [int]$MinimumLowerCase = 1,               # Minimale Anzahl an Kleinbuchstaben
        [Parameter()]
        [int]$MinimumDigit = 1                    # Minimale Anzahl an Ziffern
    )

    # Passwort abfragen und in SecureString umwandeln
    do {
        $securePassword = Read-Host "Geben Sie ein sicheres Passwort ein" -AsSecureString
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

        if ($password.Length -lt $MinimumLength) {  # Wenn das Passwort zu kurz ist, Fehlermeldung ausgeben und Schleife erneut durchlaufen
            Write-Error "Das Passwort muss mindestens $MinimumLength Zeichen lang sein."
            continue
        }

        # Wenn das Passwort mindestens eine Großbuchstabe, eine Kleinbuchstabe und eine Ziffer enthält
        if (($password -cmatch "[A-Z]") -and ($password -cmatch "[a-z]") -and ($password -cmatch "[0-9]")) {

            # Anzahl der Großbuchstaben, Kleinbuchstaben und Ziffern im Passwort zählen
            $countUpperCase = ($password -replace "[^A-Z]").Length
            $countLowerCase = ($password -replace "[^a-z]").Length
            $countDigit = ($password -replace "[^\d]").Length

            # Wenn das Passwort die Mindestanforderungen erfüllt
            if (($countUpperCase -ge $MinimumUpperCase) -and ($countLowerCase -ge $MinimumLowerCase) -and ($countDigit -ge $MinimumDigit)) {
                $securePasswordConfirm = Read-Host "Geben Sie das Passwort zur Bestätigung ein" -AsSecureString
                $passwordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordConfirm))

                # Wenn das bestätigte Passwort nicht mit dem eingegebenen Passwort übereinstimmt, Fehlermeldung ausgeben und Schleife erneut durchlaufen
                if ($password -ne $passwordConfirm) {
                    Write-Error "Die Passwörter stimmen nicht überein."
                    continue
                }

                # Wenn alle Anforderungen erfüllt sind, das Passwort zurückgeben
                return $securePassword
            }
        }

        # Wenn das Passwort nicht die Mindestanforderungen erfüllt, Fehlermeldung ausgeben und Schleife erneut durchlaufen
        Write-Error "Das Passwort erfüllt nicht die Anforderungen an Komplexität. Es muss mindestens $MinimumUpperCase Großbuchstaben, $MinimumLowerCase Kleinbuchstaben und $MinimumDigit Ziffern enthalten."
    } while ($true)
}
function Backup-Folder {
    <#
    .SYNOPSIS
        Erstellt ein 7-Zip-Archiv eines Ordners mit optional benutzerdefiniertem Namen und einem Kennwort. 
        Alte Backups werden automatisch gelöscht.
        
    .PARAMETER SourceFolder
        Der Pfad des Ordners, der gesichert werden soll.
        
    .PARAMETER BackupName
        Der Name des Backups. Wenn dieser Parameter nicht angegeben wird, wird das aktuelle Datum und die aktuelle Zeit als Name verwendet.
        
    .PARAMETER Password
        Das Kennwort, das zur Verschlüsselung des 7-Zip-Archivs verwendet wird. 
        Der Wert muss vom Typ SecureString sein.
        
    .EXAMPLE
        Backup-Folder -SourceFolder 'C:\Users\Benutzer\Documents' -Password $SecurePassword
        
        Erstellt ein Backup des Ordners "C:\Users\Benutzer\Documents" mit einem automatisch generierten Namen, 
        der das aktuelle Datum und die aktuelle Zeit enthält. Das Backup wird mit dem angegebenen Passwort verschlüsselt.
        
    .EXAMPLE
        Backup-Folder -SourceFolder 'C:\Users\Benutzer\Documents' -BackupName 'Mein Backup' -Password $SecurePassword
        
        Erstellt ein Backup des Ordners "C:\Users\Benutzer\Documents" mit dem angegebenen Namen "Mein Backup". 
        Das Backup wird mit dem angegebenen Passwort verschlüsselt.
        
    .NOTES
        Dieses Skript verwendet das Cmdlet Compress-7Zip von PowerShell, 
        das Teil des Moduls 7Zip4PowerShell ist. 
        Stellen Sie sicher, dass das Modul auf Ihrem System installiert ist, 
        bevor Sie dieses Skript verwenden.
        
        Dieses Skript löscht alte Backups, wenn mehr als 12 Backups im Backup-Ordner vorhanden sind. 
        Wenn Sie eine andere Anzahl von Backups beibehalten möchten, 
        können Sie den Code anpassen, indem Sie die Anzahl in Zeile 58 ändern.
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

    <#
    .SYNOPSIS
    Kopiert oder verschiebt Dateien und Verzeichnisse, die dem angegebenen Suchmuster entsprechen, in ein Backup-Verzeichnis.

    .DESCRIPTION
    Die Funktion "Move-BackupFiles" durchsucht das angegebene Verzeichnis nach Dateien und Verzeichnissen, die dem
    angegebenen Suchmuster entsprechen, und kopiert oder verschiebt sie in ein Backup-Verzeichnis. Die Dateien und
    Verzeichnisse werden entsprechend umbenannt und im Backup-Verzeichnis gespeichert. Das Backup-Verzeichnis wird
    automatisch erstellt, wenn es nicht bereits vorhanden ist.

    .PARAMETER BackupName
    Der Name des Backup-Verzeichnisses, in das die Dateien und Verzeichnisse kopiert oder verschoben werden sollen.
    Dieser Parameter ist erforderlich.

    .PARAMETER SearchPattern
    Das Suchmuster, das zum Durchsuchen des Quellverzeichnisses verwendet werden soll. Wenn dieser Parameter nicht
    angegeben wird, werden alle Dateien und Verzeichnisse im Quellverzeichnis durchsucht.

    .PARAMETER SearchFolder
    Das Verzeichnis, das durchsucht werden soll. Wenn dieser Parameter nicht angegeben wird, wird das Verzeichnis
    "$env:USERPROFILE\Downloads" verwendet.

    .PARAMETER TargetFolder
    Das Verzeichnis, in das die Dateien und Verzeichnisse kopiert oder verschoben werden sollen. Wenn dieser Parameter
    nicht angegeben wird, wird das Verzeichnis "$env:USERPROFILE\Downloads" verwendet.

    .PARAMETER Copy
    Kopiert die Dateien und Verzeichnisse anstelle des Verschiebens, wenn dieser Schalter angegeben wird.

    .PARAMETER Move
    Verschiebt die Dateien und Verzeichnisse anstelle des Kopierens, wenn dieser Schalter angegeben wird.

    .PARAMETER Recurse
    Durchsucht das Quellverzeichnis rekursiv, wenn dieser Schalter angegeben wird.

    .PARAMETER NoRename
    Verwendet die ursprünglichen Dateinamen ohne Umbenennung, wenn dieser Schalter angegeben wird.

    .EXAMPLE
    Move-BackupFiles -BackupName "MeinBackup" -SearchPattern "*.txt" -SearchFolder "C:\Users\Max\Documents" -TargetFolder "D:\Backups" -Move

    Sucht nach allen Dateien im Verzeichnis "C:\Users\Max\Documents" mit der Erweiterung ".txt" und verschiebt sie in das Verzeichnis "D:\Backups\MeinBackup", ohne sie umzubenennen.

    .EXAMPLE
    Move-BackupFiles -BackupName "MeinBackup" -SearchFolder "C:\Users\Max\Documents" -Copy

    Sucht nach allen Dateien und Verzeichnissen im Verzeichnis "C:\Users\Max\Documents" und kopiert sie in das Verzeichnis "C:\Users\Max\Downloads\MeinBackup", ohne sie umzubenennen.

    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$BackupName,
        [string]$SearchPattern,
        [string]$SearchFolder = "$env:USERPROFILE\Downloads",
        [string]$TargetFolder = "$env:USERPROFILE\Downloads",
        [switch]$Copy,
        [switch]$Move = !$Copy,
        [switch]$Recurse,
        [switch]$NoRename
    )

    # Durchsuche das Quellverzeichnis nach passenden Dateien
    $items = Get-ChildItem -Path $SearchFolder -File | Where-Object { $_.Name -match $SearchPattern }

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

                # Kopiere/verschiebe den gesamten Inhalt des Verzeichnisses, wenn die -Recurse-Option angegeben wurde
                if ($Recurse) {
                    $destinationSubdirectory = Join-Path $TargetFolder\$BackupName $relativePath.Substring(1)
                    Copy-Item $item.FullName\* $destinationSubdirectory -Recurse -Force
                }

            } else {
                # Wenn es sich um eine Datei handelt, kopiere/verschiebe sie ins Zielverzeichnis und benenne sie um
                $newName = $item.Name

                if (!$NoRename) {
                    if ($item.Extension -eq '.gz' -and $item.Name.Contains('.tar')) {
                        $newName = '{0}-{1}-Backup.tar.gz' -f $date, $BackupName
                    } else {
                        $newName = '{0}-{1}-Backup{2}' -f $date, $BackupName, $item.Extension
                    }
                }

                $destinationFile = Join-Path $TargetFolder\$BackupName $newName

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
    <#
    .SYNOPSIS
    Die Funktion "Copy-RemoteData" kopiert Daten von einem Remote-Server auf einen lokalen Computer.

    .DESCRIPTION
    Die Funktion "Copy-RemoteData" ermöglicht das Kopieren von Daten von einem Remote-Server auf einen lokalen Computer.
    Es ist möglich, einen Servernamen, einen Pfad auf dem Remote-Server, einen Namen für den Ordner, in dem die Daten
    gespeichert werden sollen, und ein optionales Zielverzeichnis auf dem lokalen Computer anzugeben. Das Zielverzeichnis
    auf dem lokalen Computer ist standardmäßig das Verzeichnis "Downloads" im Benutzerverzeichnis.

    .PARAMETER serverName
    Der Name des Remote-Servers, von dem die Daten kopiert werden sollen.

    .PARAMETER remotePath
    Der Pfad auf dem Remote-Server, von dem die Daten kopiert werden sollen.

    .PARAMETER name
    Der Name des Ordners, in dem die Daten gespeichert werden sollen.

    .PARAMETER destinationPath
    Ein optionales Zielverzeichnis auf dem lokalen Computer, in das die Daten kopiert werden sollen. Standardmäßig ist das
    Zielverzeichnis "Downloads" im Benutzerverzeichnis.

    .EXAMPLE
    Copy-RemoteData -serverName "RemoteServer01" -remotePath "/data" -name "DataBackup"

    Dieses Beispiel kopiert Daten aus dem Ordner "/data" auf dem Remote-Server "RemoteServer01" in einen Ordner mit
    dem Namen "DataBackup" im Verzeichnis "Downloads" des lokalen Computers.

    .EXAMPLE
    Copy-RemoteData -serverName "RemoteServer01" -remotePath "/data" -name "DataBackup" -destinationPath "C:\Backup"

    Dieses Beispiel kopiert Daten aus dem Ordner "/data" auf dem Remote-Server "RemoteServer01" in einen Ordner mit
    dem Namen "DataBackup" im Verzeichnis "C:\Backup" des lokalen Computers.

    .NOTES
    Die Funktion "Copy-RemoteData" verwendet den SCP-Befehl zum Kopieren von Daten von einem Remote-Server auf einen
    lokalen Computer. Um diese Funktion ausführen zu können, muss der SCP-Befehl auf dem lokalen Computer verfügbar sein.
    #>

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
Move-BackupFiles -BackupName "Draytek" -SearchPattern '^V165_\d{8}_Modem_424_STD\.cfg$'

# ======================================
#               Bitwarden
# ======================================
Move-BackupFiles -BackupName "Bitwarden" -SearchPattern 'bitwarden_export_(\d{14}).json'

# ======================================
#              Portainer                
# ======================================
Move-BackupFiles -BackupName "Portainer" -SearchPattern 'portainer-backup_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.tar\.gz'

# ======================================
#                 Unifi
# ======================================
Move-BackupFiles -BackupName "Unifi" -SearchPattern '^.*(unifi|network).*(\.unf|\.unifi)$'

# ======================================
#                 Heimdal
# ======================================
Move-BackupFiles -BackupName "Heimdal" -SearchPattern 'heimdallexport.json'

# ======================================
#               Diskstation
# ======================================
Move-BackupFiles -BackupName "Diskstation" -SearchPattern 'Diskstation_[0-9]{8}\.dss'

# ======================================
#                GitHub
# ======================================
Move-BackupFiles -BackupName "GitHub" -SearchFolder $env:USERPROFILE\Documents\GitHub -Copy -Recurse -NoRename


# ======================================
#                   SSH
# ======================================
Move-BackupFiles -BackupName "SSH" -SearchFolder $env:USERPROFILE\.ssh -Copy -Recurse -NoRename

# ======================================
#                  CURA
# ======================================
# Suchen Sie nach dem Ordner mit der höchsten Versionsnummer im Pfad
$SearchFolder = Get-ChildItem $env:APPDATA\cura\ -Directory | Sort-Object @{ Expression = { [regex]::Replace($_.Name, '.*(\d+(\.\d+)*)$', '$1') } } -Descending
$SelectedFolder = $SearchFolder | Select-Object -First 1
$SearchFolder = Join-Path $SelectedFolder.FullName "quality_changes"
$filePath = Join-Path $SearchFolder "WICHTIG - LESEN!.txt"
Set-Content -Path $filePath  -Value "Backup aus $SearchFolder"
Move-BackupFiles -BackupName "Cura" -SearchPattern '.*\.(txt|cfg)$' -SearchFolder $SearchFolder -Copy -NoRename

# ======================================
#                 PiHole
# ======================================
Copy-RemoteData -serverName "Docker-Pi-1" -remotePath "/home/erik/backup/*-pihole-backup.tar.gz" -name "PiHole"

# ======================================
#              Homeassistant
# ======================================
Copy-RemoteData -serverName "Homeassistant" -remotePath "/backup/*.tar" -name "Homeassitant"



foreach ($Folder in ($BackupFolders | Sort-Object -Unique -Property BackupName)) {
    if (Backup-Folder -SourceFolder $Folder.Path -BackupName $Folder.BackupName -Password $Password) {
        Remove-Item $Folder.Path -Recurse -Force
    }
}