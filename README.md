# useful-batch-files

Batch and PowerShell files for Windows, which I find useful for my daily work

(by Achim Barczok 2021, achim@lostfile.de) 
 
 
## resize1080.cmd

Creates an jpg with 1080 pixel width.
Draw the image file on the cmd-File to generate a new image in the same folder.

Requires IrfanView. (32 bit, but can easily be adopted to 64 bit)

## renamereports.ps1

PowerShell script which strips time codes from file names.
(I use them for file exported by an analytics software)

## ollama.ahk

Klickt Fehlermeldungen in Lightroom Classic weg, wenn das Plug-in LRGeniusTagAI einen Timeout-Fehler macht. Scheint seit 22.8.2025 nicht mehr notwendig zu sein mit der aktuellen Version des Plug-ins.

## fix_by_foldername_clean.ps1

Korrigiert Aufnahmedatum von Bildern, die man per Messenger zugesendet bekommen hat und deshalb als Aufnahmedatum in Exif als Aufnahmedatum das Import-Datum bekommt, obwohl Lightroom für den Dateinamen beim Umbenennen den Zeitstempel für den Empfang des Bilds enthält. Wenn man den Ordner in YYYY-MM-DD umbenennt, wird das außerdem noch dieser Tag für den Zeitstempel berücksichtigt, weil ja auch der Zeitstempel für den Empfang des Bilds nicht der Zeitstempel für das Aufnahmedatum ist.
