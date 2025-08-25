# INTELLIGENTE ORDNER-DATUM KORREKTUR - Korrigierte Version
# Aendert nur das DATUM in Dateinamen, behaelt Zeit und Nummer bei

param(
    [Parameter(Mandatory=$false)]
    [string]$BasePath = "C:\Fotos Negative\2025",
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false,
    [Parameter(Mandatory=$false)]
    [switch]$RenameFiles = $true,
    [Parameter(Mandatory=$false)]
    [switch]$FixExif = $true
)

# ExifTool vom Desktop
$exiftoolPath = "C:\Users\achim\Desktop\exiftool\exiftool.exe"

# Funktion zum Parsen des Datums aus dem Ordnernamen
function Parse-DateFromFolderName {
    param([string]$folderName)
    
    if ($folderName -match '^(\d{4})-(\d{2})-(\d{2})') {
        try {
            $year = $matches[1]
            $month = $matches[2] 
            $day = $matches[3]
            return Get-Date -Year $year -Month $month -Day $day
        } catch {
            return $null
        }
    }
    return $null
}

# Funktion zum Parsen des kompletten Datums/Zeit aus dem Dateinamen
function Parse-DateTimeFromFilename {
    param([string]$filename)
    
    if ($filename -match '^(\d{2})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})_(\d+)') {
        return @{
            YearShort = $matches[1]
            Month = $matches[2]
            Day = $matches[3]
            Hour = $matches[4]
            Minute = $matches[5]
            Second = $matches[6]
            Number = $matches[7]
            HasValidFormat = $true
        }
    }
    return @{ HasValidFormat = $false }
}

# Funktion zum Generieren des neuen Dateinamens
function Generate-UpdatedFilename {
    param([string]$oldFilename, [DateTime]$newDate)
    
    $extension = [System.IO.Path]::GetExtension($oldFilename)
    $fileInfo = Parse-DateTimeFromFilename -filename $oldFilename
    
    if (-not $fileInfo.HasValidFormat) {
        return $null
    }
    
    # Verwende neues Datum, aber behalte Zeit und Nummer bei
    $yearShort = $newDate.ToString("yy")
    $month = $newDate.ToString("MM")
    $day = $newDate.ToString("dd")
    
    $newFilename = "${yearShort}${month}${day}_$($fileInfo.Hour)$($fileInfo.Minute)$($fileInfo.Second)_$($fileInfo.Number)${extension}"
    
    return $newFilename
}

# Funktion zum Korrigieren eines Ordners
function Fix-FolderByName {
    param([string]$folderPath)
    
    $folderName = Split-Path $folderPath -Leaf
    Write-Host ""
    Write-Host "BEARBEITE ORDNER: $folderName" -ForegroundColor Cyan
    
    # Parse Datum aus Ordnername
    $masterDate = Parse-DateFromFolderName -folderName $folderName
    if (-not $masterDate) {
        Write-Host "   Kann Datum nicht aus Ordnername parsen: $folderName" -ForegroundColor Red
        Write-Host "   Erwartetes Format: YYYY-MM-DD" -ForegroundColor Yellow
        return @{ Processed = 0; Errors = 1; FolderName = $folderName; Renamed = 0; Skipped = 0 }
    }
    
    Write-Host "   Master-Datum aus Ordnername: $($masterDate.ToString('yyyy-MM-dd'))" -ForegroundColor Green
    
    # Sammle alle Bilddateien
    $jpgFiles = Get-ChildItem -Path $folderPath -Filter "*.jpg" -File
    $jpegFiles = Get-ChildItem -Path $folderPath -Filter "*.jpeg" -File
    $dngFiles = Get-ChildItem -Path $folderPath -Filter "*.dng" -File
    
    $imageFiles = @()
    $imageFiles += $jpgFiles
    $imageFiles += $jpegFiles  
    $imageFiles += $dngFiles
    
    if ($imageFiles.Count -eq 0) {
        Write-Host "   Keine Bilddateien gefunden" -ForegroundColor Yellow
        return @{ Processed = 0; Errors = 0; FolderName = $folderName; Renamed = 0; Skipped = 0 }
    }
    
    Write-Host "   Gefunden: $($imageFiles.Count) Bilddateien" -ForegroundColor White
    
    $processedCount = 0
    $errorCount = 0
    $renamedCount = 0
    $skippedCount = 0
    
    # Phase 1: Dateinamen anpassen
    if ($RenameFiles) {
        Write-Host "   Phase 1: Dateinamen-Datum anpassen..." -ForegroundColor Yellow
        
        foreach ($file in $imageFiles) {
            try {
                $newFilename = Generate-UpdatedFilename -oldFilename $file.Name -newDate $masterDate
                
                if (-not $newFilename) {
                    Write-Host "   $($file.Name) - Format nicht erkannt, ueberspringe" -ForegroundColor Gray
                    $skippedCount++
                    continue
                }
                
                if ($file.Name -eq $newFilename) {
                    Write-Host "   $($file.Name) - Datum bereits korrekt" -ForegroundColor Gray
                    continue
                }
                
                $newPath = Join-Path $folderPath $newFilename
                
                if ($WhatIf) {
                    Write-Host "   [TEST] $($file.Name) -> $newFilename" -ForegroundColor Gray
                } else {
                    # Pruefe ob Zieldatei bereits existiert
                    if (Test-Path $newPath) {
                        Write-Host "   Warnung: $newFilename existiert bereits - ueberspringe" -ForegroundColor Yellow
                        continue
                    }
                    
                    Rename-Item $file.FullName $newPath
                    Write-Host "   Umbenannt: $($file.Name) -> $newFilename" -ForegroundColor Green
                }
                $renamedCount++
                
            } catch {
                Write-Host "   Fehler beim Umbenennen $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        }
    }
    
    # Phase 2: EXIF-Daten korrigieren
    if ($FixExif) {
        Write-Host "   Phase 2: EXIF-Daten korrigieren..." -ForegroundColor Yellow
        
        # Sammle aktuelle Dateien nach eventuellem Umbenennen
        $currentFiles = Get-ChildItem -Path $folderPath -Include "*.jpg","*.jpeg","*.dng" -File
        
        foreach ($file in $currentFiles) {
            try {
                # Parse Zeit aus dem eventuell neuen Dateinamen
                $fileInfo = Parse-DateTimeFromFilename -filename $file.Name
                
                if (-not $fileInfo.HasValidFormat) {
                    Write-Host "   $($file.Name) - EXIF: Format nicht erkannt, ueberspringe" -ForegroundColor Gray
                    continue
                }
                
                # Erstelle vollstaendiges DateTime mit Ordnerdatum und Datei-Zeit
                $fullDateTime = Get-Date -Year $masterDate.Year -Month $masterDate.Month -Day $masterDate.Day -Hour $fileInfo.Hour -Minute $fileInfo.Minute -Second $fileInfo.Second
                
                $exifDateFormat = $fullDateTime.ToString("yyyy:MM:dd HH:mm:ss")
                
                if ($WhatIf) {
                    Write-Host "   [TEST] EXIF $($file.Name) -> $exifDateFormat" -ForegroundColor Gray
                    $processedCount++
                } else {
                    # ExifTool Kommando
                    $result = & $exiftoolPath `
                        "-DateTimeOriginal=$exifDateFormat" `
                        "-CreateDate=$exifDateFormat" `
                        "-ModifyDate=$exifDateFormat" `
                        "-overwrite_original" `
                        $file.FullName 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        $processedCount++
                        
                        # Progress alle 25 Dateien
                        if ($processedCount % 25 -eq 0) {
                            Write-Host "   EXIF bearbeitet: $processedCount von $($currentFiles.Count)..." -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "   ExifTool Fehler bei $($file.Name): $result" -ForegroundColor Red
                        $errorCount++
                    }
                }
                
            } catch {
                Write-Host "   Fehler bei EXIF-Korrektur $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        }
    }
    
    # Zusammenfassung fuer diesen Ordner
    if (-not $WhatIf) {
        $summary = @()
        if ($RenameFiles -and $renamedCount -gt 0) {
            $summary += "$renamedCount Dateinamen angepasst"
        }
        if ($RenameFiles -and $skippedCount -gt 0) {
            $summary += "$skippedCount Format nicht erkannt"
        }
        if ($FixExif -and $processedCount -gt 0) {
            $summary += "$processedCount EXIF-Daten korrigiert"
        }
        
        if ($errorCount -eq 0 -and ($renamedCount -gt 0 -or $processedCount -gt 0)) {
            Write-Host "   Erfolgreich: $($summary -join ', ')" -ForegroundColor Green
        } elseif ($errorCount -gt 0) {
            Write-Host "   Mit Fehlern: $($summary -join ', '), $errorCount Fehler" -ForegroundColor Yellow
        } else {
            Write-Host "   Nichts zu tun (bereits korrekt oder kein erkanntes Format)" -ForegroundColor Green
        }
    }
    
    return @{
        Processed = $processedCount
        Errors = $errorCount
        FolderName = $folderName
        Renamed = $renamedCount
        Skipped = $skippedCount
    }
}
# Hauptskript
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   INTELLIGENTE ORDNER-DATUM KORREKTUR - MESSENGER BILDER" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "Dieses Skript passt NUR das DATUM in Dateinamen an, behaelt Zeit und Nummer bei." -ForegroundColor White
Write-Host "Beispiel: 250509_030107_97912.jpg -> 250508_030107_97912.jpg" -ForegroundColor Green
Write-Host "EXIF-Datum wird entsprechend auf 2025-05-08 03:01:07 gesetzt." -ForegroundColor Green
Write-Host ""

# Teste ExifTool (nur wenn EXIF-Korrektur gewuenscht)
if ($FixExif) {
    if (-not (Test-Path $exiftoolPath)) {
        Write-Host "ExifTool nicht gefunden: $exiftoolPath" -ForegroundColor Red
        Write-Host "Fuer EXIF-Korrektur wird ExifTool benoetigt." -ForegroundColor Yellow
        Write-Host "Verwenden Sie -FixExif:`$false um nur Dateinamen zu aendern." -ForegroundColor Yellow
        exit 1
    }

    try {
        $version = & $exiftoolPath -ver 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "ExifTool: Version $version" -ForegroundColor Green
        } else {
            Write-Host "ExifTool Fehler: $version" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "Kann ExifTool nicht ausfuehren: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

if ($WhatIf) {
    Write-Host "WHAT-IF MODUS: Keine Aenderungen werden vorgenommen" -ForegroundColor Yellow
}

Write-Host "Basis-Pfad: $BasePath" -ForegroundColor White
Write-Host "Dateinamen anpassen: $(if($RenameFiles) {'Ja'} else {'Nein'})" -ForegroundColor White  
Write-Host "EXIF-Daten anpassen: $(if($FixExif) {'Ja'} else {'Nein'})" -ForegroundColor White

# Sammle alle Datumsordner
$folders = Get-ChildItem -Path $BasePath -Directory | 
           Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } |
           Sort-Object Name

if ($folders.Count -eq 0) {
    Write-Host "Keine Datumsordner gefunden in: $BasePath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Gefunden: $($folders.Count) Datumsordner" -ForegroundColor White
Write-Host ""

# Liste anzeigen
Write-Host "VERFUEGBARE ORDNER:" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow

for ($i = 0; $i -lt $folders.Count; $i++) {
    $folder = $folders[$i]
    # Zaehle Bilddateien
    $jpgCount = (Get-ChildItem -Path $folder.FullName -Filter "*.jpg" -File).Count
    $jpegCount = (Get-ChildItem -Path $folder.FullName -Filter "*.jpeg" -File).Count
    $dngCount = (Get-ChildItem -Path $folder.FullName -Filter "*.dng" -File).Count
    $totalCount = $jpgCount + $jpegCount + $dngCount
    
    $numberPart = "$($i+1).".PadRight(4)
    $namePart = "$($folder.Name)".PadRight(35)
    $countPart = "($totalCount Dateien)"
    
    Write-Host "$numberPart $namePart $countPart" -ForegroundColor White
}

Write-Host ""
Write-Host "FUNKTIONSWEISE:" -ForegroundColor Cyan
Write-Host "- Ordnername '2025-05-08' wird als Master-Datum verwendet" -ForegroundColor White
Write-Host "- Nur das DATUM im Dateinamen wird geaendert:" -ForegroundColor White
Write-Host "  250509_030107_97912.jpg -> 250508_030107_97912.jpg" -ForegroundColor Green
Write-Host "- Zeit (03:01:07) und Nummer (97912) bleiben unveraendert" -ForegroundColor White
Write-Host "- EXIF-Datum wird auf 2025-05-08 03:01:07 gesetzt" -ForegroundColor White
Write-Host ""

Write-Host "AUSWAHL-OPTIONEN:" -ForegroundColor Cyan
Write-Host "- Einzelne Ordner: z.B. '3' oder '1,5,8' oder '10-15'" -ForegroundColor White
Write-Host "- Alle Ordner: 'all' oder 'alle'" -ForegroundColor White
Write-Host "- Abbrechen: 'q' oder 'quit'" -ForegroundColor White
Write-Host ""

$selection = Read-Host "Ihre Auswahl"

if ($selection -eq 'q' -or $selection -eq 'quit') {
    Write-Host "Abgebrochen." -ForegroundColor Yellow
    exit 0
}

# Parse Auswahl
$selectedFolders = @()

if ($selection -eq 'all' -or $selection -eq 'alle') {
    $selectedFolders = $folders
    Write-Host "Alle $($folders.Count) Ordner ausgewaehlt." -ForegroundColor Green
} else {
    try {
        $indices = @()
        
        # Verschiedene Eingabeformate behandeln
        if ($selection -match '^[\d,\s]+$') {
            $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
        }
        elseif ($selection -match '^(\d+)-(\d+)$') {
            $start = [int]$matches[1] - 1
            $end = [int]$matches[2] - 1
            if ($start -le $end) {
                $indices = $start..$end
            } else {
                throw "Ungueltiger Bereich"
            }
        }
        elseif ($selection -match '^\d+$') {
            $indices = @([int]$selection - 1)
        }
        else {
            throw "Ungueltiges Format"
        }
        
        # Validiere und sammle Ordner
        foreach ($index in $indices) {
            if ($index -ge 0 -and $index -lt $folders.Count) {
                $selectedFolders += $folders[$index]
            } else {
                Write-Host "Warnung: Index $($index + 1) ist ungueltig (1-$($folders.Count))" -ForegroundColor Yellow
            }
        }
        
        if ($selectedFolders.Count -eq 0) {
            Write-Host "Keine gueltigen Ordner ausgewaehlt." -ForegroundColor Red
            exit 0
        }
        
        Write-Host "Ausgewaehlt: $($selectedFolders.Count) Ordner" -ForegroundColor Green
        foreach ($folder in $selectedFolders) {
            Write-Host "  - $($folder.Name)" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "Ungueltige Eingabe: $selection" -ForegroundColor Red
        Write-Host "Verwenden Sie z.B.: 1, 3,5,7, 10-15, oder 'all'" -ForegroundColor Yellow
        exit 0
    }
}

# Bestaetigung
Write-Host ""
if ($WhatIf) {
    Write-Host "TEST-MODUS: Wuerde $($selectedFolders.Count) Ordner verarbeiten." -ForegroundColor Yellow
} else {
    Write-Host "ACHTUNG: Dies aendert Dateinamen und EXIF-Metadaten in $($selectedFolders.Count) Ordnern!" -ForegroundColor Yellow
    Write-Host "Nur das DATUM in Dateinamen wird angepasst (Zeit/Nummer bleiben gleich)" -ForegroundColor White
    $confirm = Read-Host "Fortfahren? (j/n)"
    if ($confirm -ne 'j' -and $confirm -ne 'J') {
        Write-Host "Abgebrochen." -ForegroundColor Yellow
        exit 0
    }
}

# Verarbeite ausgewaehlte Ordner
$results = @()
$totalProcessed = 0
$totalErrors = 0
$totalRenamed = 0
$totalSkipped = 0

Write-Host ""
Write-Host "Starte intelligente Ordner-Datum Korrektur fuer $($selectedFolders.Count) Ordner..." -ForegroundColor Green

foreach ($folder in $selectedFolders) {
    $result = Fix-FolderByName -folderPath $folder.FullName
    $results += $result
    
    $totalProcessed += $result.Processed
    $totalErrors += $result.Errors
    $totalRenamed += $result.Renamed
    $totalSkipped += $result.Skipped
}

# Zusammenfassung
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                    ZUSAMMENFASSUNG" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "Verarbeitete Ordner: $($selectedFolders.Count)" -ForegroundColor White
if ($RenameFiles) {
    Write-Host "Dateinamen angepasst: $totalRenamed" -ForegroundColor Green
    if ($totalSkipped -gt 0) {
        Write-Host "Format nicht erkannt: $totalSkipped" -ForegroundColor Yellow
    }
}
if ($FixExif) {
    Write-Host "EXIF-Daten korrigiert: $totalProcessed" -ForegroundColor Green
}
if ($totalErrors -eq 0) {
    Write-Host "Fehler: $totalErrors" -ForegroundColor Green
} else {
    Write-Host "Fehler: $totalErrors" -ForegroundColor Red
}

Write-Host ""
Write-Host "Details pro Ordner:" -ForegroundColor White
foreach ($result in $results) {
    $details = @()
    if ($RenameFiles -and $result.Renamed -gt 0) {
        $details += "$($result.Renamed) Namen angepasst"
    }
    if ($RenameFiles -and $result.Skipped -gt 0) {
        $details += "$($result.Skipped) Format nicht erkannt"
    }
    if ($FixExif -and $result.Processed -gt 0) {
        $details += "$($result.Processed) EXIF korrigiert"
    }
    
    if ($result.Errors -eq 0) {
        $status = if ($details.Count -gt 0) { $details -join ', ' } else { "OK" }
        $color = 'Green'
    } else {
        $status = "FEHLER ($($result.Errors))"
        $color = 'Red'
    }
    
    Write-Host "  $($result.FolderName): $status" -ForegroundColor $color
}

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "INTELLIGENTE ORDNER-DATUM KORREKTUR ABGESCHLOSSEN!" -ForegroundColor Green
    Write-Host "Dateinamen-Datum und EXIF-Daten basieren jetzt auf den Ordnernamen." -ForegroundColor White
    Write-Host "Zeit und Dateinummern wurden beibehalten - perfekt fuer Messenger-Bilder!" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "What-If Test abgeschlossen." -ForegroundColor Yellow
    Write-Host "Fuehren Sie ohne -WhatIf aus fuer echte Aenderungen." -ForegroundColor Cyan
}
