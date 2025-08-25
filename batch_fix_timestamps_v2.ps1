# EXIF Timestamp Batch-Korrektur - KORRIGIERTE VERSION
# Automatische Korrektur fuer mehrere Ordner basierend auf Dateinamen
# Format: YYMMDD_HHMMSS_XXXXX.jpg/dng

param(
    [Parameter(Mandatory=$false)]
    [string]$BasePath = "C:\Fotos Negative\2025",
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

# Funktion zum Parsen des Datums aus dem Dateinamen
function Parse-DateFromFilename {
    param([string]$filename)
    
    if ($filename -match '^(\d{2})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})') {
        $year = "20" + $matches[1]
        $month = $matches[2]
        $day = $matches[3]
        $hour = $matches[4]
        $minute = $matches[5]
        $second = $matches[6]
        
        try {
            return Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second
        } catch {
            return $null
        }
    }
    return $null
}

# Funktion zum Korrigieren eines einzelnen Ordners - KORRIGIERT
function Fix-FolderTimestamps {
    param([string]$folderPath)
    
    if (-not (Test-Path $folderPath)) {
        Write-Host "Fehler: Ordner nicht gefunden: $folderPath" -ForegroundColor Red
        return @{ Processed = 0; Errors = 1; FolderName = Split-Path $folderPath -Leaf }
    }
    
    $folderName = Split-Path $folderPath -Leaf
    Write-Host ""
    Write-Host "BEARBEITE ORDNER: $folderName" -ForegroundColor Cyan
    
    # KORRIGIERT: Verwende separate Filter statt Include
    $jpgFiles = Get-ChildItem -Path $folderPath -Filter "*.jpg" -File
    $jpegFiles = Get-ChildItem -Path $folderPath -Filter "*.jpeg" -File  
    $dngFiles = Get-ChildItem -Path $folderPath -Filter "*.dng" -File
    
    $imageFiles = @()
    $imageFiles += $jpgFiles
    $imageFiles += $jpegFiles
    $imageFiles += $dngFiles
    
    if ($imageFiles.Count -eq 0) {
        Write-Host "   Keine Bilddateien gefunden" -ForegroundColor Yellow
        return @{ Processed = 0; Errors = 0; FolderName = $folderName }
    }
    
    Write-Host "   Gefunden: $($imageFiles.Count) Bilddateien" -ForegroundColor White
    
    $processedCount = 0
    $errorCount = 0
    $skippedCount = 0
    
    foreach ($file in $imageFiles) {
        $correctDate = Parse-DateFromFilename -filename $file.Name
        
        if ($correctDate) {
            # Pruefe ob bereits korrekt
            $currentCreated = $file.CreationTime
            if ($correctDate.Date -eq $currentCreated.Date -and 
                [Math]::Abs(($correctDate - $currentCreated).TotalHours) -lt 2) {
                $skippedCount++
                continue
            }
            
            try {
                if ($WhatIf) {
                    Write-Host "   [TEST] $($file.Name) -> $($correctDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
                } else {
                    $file.CreationTime = $correctDate
                    $file.LastWriteTime = $correctDate
                }
                $processedCount++
                
                # Progress alle 20 Dateien
                if ($processedCount % 20 -eq 0) {
                    Write-Host "   Verarbeitet: $processedCount von $($imageFiles.Count)..." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "   Fehler bei $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
                $errorCount++
            }
        } else {
            Write-Host "   $($file.Name) - Datum nicht parsebar" -ForegroundColor Red
            $errorCount++
        }
    }
    
    if (-not $WhatIf) {
        if ($errorCount -eq 0) {
            Write-Host "   $processedCount Dateien korrigiert, $skippedCount bereits korrekt" -ForegroundColor Green
        } else {
            Write-Host "   $processedCount korrigiert, $skippedCount uebersprungen, $errorCount Fehler" -ForegroundColor Yellow
        }
    }
    
    return @{ 
        Processed = $processedCount
        Errors = $errorCount
        FolderName = $folderName
        Skipped = ($processedCount -eq 0 -and $errorCount -eq 0 -and $skippedCount -gt 0)
    }
}
# Hauptskript
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       EXIF TIMESTAMP BATCH-KORREKTUR V2" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "WHAT-IF MODUS: Keine Aenderungen werden vorgenommen" -ForegroundColor Yellow
}

Write-Host "Basis-Pfad: $BasePath" -ForegroundColor White

# Sammle alle relevanten Ordner
$folders = Get-ChildItem -Path $BasePath -Directory | 
           Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}' } |
           Sort-Object Name

if ($folders.Count -eq 0) {
    Write-Host "Keine Datumsordner gefunden in: $BasePath" -ForegroundColor Red
    exit 1
}

Write-Host "Gefunden: $($folders.Count) Datumsordner" -ForegroundColor White
Write-Host ""

# Interaktive Auswahl oder alle verarbeiten
$response = Read-Host "Alle Ordner verarbeiten? (j/n) oder 'l' fuer Liste"

if ($response -eq 'l') {
    Write-Host ""
    Write-Host "Verfuegbare Ordner:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $folders.Count; $i++) {
        $folder = $folders[$i]
        # KORRIGIERT: Separate Zaehlung fuer jeden Dateityp
        $jpgCount = (Get-ChildItem -Path $folder.FullName -Filter "*.jpg" -File).Count
        $jpegCount = (Get-ChildItem -Path $folder.FullName -Filter "*.jpeg" -File).Count
        $dngCount = (Get-ChildItem -Path $folder.FullName -Filter "*.dng" -File).Count
        $totalCount = $jpgCount + $jpegCount + $dngCount
        
        Write-Host "$($i+1). $($folder.Name) ($totalCount Dateien)" -ForegroundColor White
    }
    
    $selection = Read-Host "Ordner-Nummern eingeben (z.B. 1,3,5) oder 'all' fuer alle"
    
    if ($selection -ne 'all') {
        try {
            $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
            $selectedFolders = @()
            foreach ($index in $indices) {
                if ($index -ge 0 -and $index -lt $folders.Count) {
                    $selectedFolders += $folders[$index]
                }
            }
            $folders = $selectedFolders
        } catch {
            Write-Host "Ungueltige Eingabe. Verwende alle Ordner." -ForegroundColor Yellow
        }
    }
}
elseif ($response -ne 'j' -and $response -ne 'J') {
    Write-Host "Abgebrochen." -ForegroundColor Yellow
    exit 0
}

# Verarbeite Ordner
$results = @()
$totalProcessed = 0
$totalErrors = 0

foreach ($folder in $folders) {
    $result = Fix-FolderTimestamps -folderPath $folder.FullName
    $results += $result
    
    $totalProcessed += $result.Processed
    $totalErrors += $result.Errors
}

# Zusammenfassung
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                    ZUSAMMENFASSUNG" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "Verarbeitete Ordner: $($folders.Count)" -ForegroundColor White
Write-Host "Gesamt Dateien korrigiert: $totalProcessed" -ForegroundColor Green
if ($totalErrors -eq 0) {
    Write-Host "Gesamt Fehler: $totalErrors" -ForegroundColor Green
} else {
    Write-Host "Gesamt Fehler: $totalErrors" -ForegroundColor Red
}

Write-Host ""
Write-Host "Details:" -ForegroundColor White
foreach ($result in $results) {
    if ($result.Skipped) {
        $status = "ALLE BEREITS KORREKT"
        $color = 'Yellow'
    } elseif ($result.Errors -eq 0) {
        $status = "OK"
        $color = 'Green'
    } else {
        $status = "FEHLER"
        $color = 'Red'
    }
    
    Write-Host "  $($result.FolderName): $($result.Processed) Dateien korrigiert - $status" -ForegroundColor $color
}

if (-not $WhatIf) {
    Write-Host ""
    Write-Host "Batch-Korrektur abgeschlossen!" -ForegroundColor Green
    Write-Host "Hinweis: Druecken Sie F5 im Windows Explorer um die Aenderungen zu sehen." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "What-If Analyse abgeschlossen. Fuehren Sie ohne -WhatIf aus fuer echte Aenderungen." -ForegroundColor Yellow
}
