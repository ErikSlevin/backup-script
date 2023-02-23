# Passwortabfrage und Sicherung als SecureString
function Get-Password {
    <#
    .SYNOPSIS
    Liest ein Passwort von der Konsole ein und gibt es als SecureString zurück.
    
    .DESCRIPTION
    Diese Funktion liest ein Passwort von der Konsole ein und wandelt es in einen SecureString um. Das Passwort wird zweimal eingegeben und überprüft, um sicherzustellen, dass es korrekt eingegeben wurde.
    
    .EXAMPLE
    PS C:\> $password = Get-Password
    
    Gibt eine Passwortabfrage auf der Konsole aus und gibt das eingegebene Passwort als SecureString zurück.
    
    .NOTES
    Diese Funktion erfordert PowerShell 2.0 oder höher.
    #>

    # Passwort abfragen und in SecureString umwandeln
    $securePassword = Read-Host "Enter password" -AsSecureString
    $securePasswordConfirm = Read-Host "Confirm password" -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
    $passwordConfirm = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePasswordConfirm))
    if ($password -ne $passwordConfirm) {
        Write-Error "Passwords do not match."
        exit
    }
    return $securePassword
}


# Backup-Funktion mit 7zip
function Backup-Folder {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType 'Container'})]
        [string]$SourceFolder,

        [Parameter(Mandatory = $false)]
        [string]$BackupName,

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Password
    )

    if (!$BackupName) {
        $BackupName = (Get-Date).ToString("yyyy-MM")
    }

    $BackupPath = "C:\Users\erik\OneDrive\06 - Backups\$BackupName"

    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath | Out-Null
    }

    $Date = (Get-Date).ToString("yyyy-MM-dd")

    $ArchiveName = "$Date-$BackupName.7z"
    $ArchivePath = Join-Path $BackupPath $ArchiveName
    $PasswordString = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

    $ZipArgs = @{
        Path = $SourceFolder
        CompressionLevel = 'Ultra'
        Password = $PasswordString
        ArchiveFileName = $ArchivePath
        EncryptFilenames = $true
    }

    Compress-7Zip @ZipArgs | Out-Null

    $BackupList = Get-ChildItem $BackupPath -Filter *.7z
    if ($BackupList.Count -gt 12) {
        $OldestBackup = $BackupList | Sort-Object CreationTime | Select-Object -First 1
        Remove-Item $OldestBackup.FullName
    }
}

# Main-Skript
$Password = Get-Password

# Backup-Folder-Funktion aufrufen für jeden Ordner mit individuellem Backup-Namen
$BackupFolders = @(
    @{Name="y-Games"; Path="C:\Users\erik\Saved Games"; BackupName="x-games"},
    @{Name="y-SSH"; Path="C:\Users\erik\.ssh"; BackupName="x-SSH"},
    @{Name="y-mume"; Path="C:\Users\erik\.mume"; BackupName="x-mume"}
)
foreach ($Folder in $BackupFolders) {
    Backup-Folder -SourceFolder $Folder.Path -BackupName $Folder.BackupName -Password $Password
}
