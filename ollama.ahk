; AutoHotkey v2 Script für OllamaAPI Fehlerdialog
; Sucht nach dem "OK" Button im Lightroom/OllamaAPI Fehlerfenster

#SingleInstance Force
Persistent

; Globale Variable für Monitoring-Status
Monitoring := false

; Hotkey zum Starten/Stoppen (F9)
F9:: {
    global Monitoring
    if (Monitoring) {
        Monitoring := false
        SetTimer(CheckForOllamaError, 0)
        TrayTip("Überwachung gestoppt", "AutoClicker")
    } else {
        Monitoring := true
        SetTimer(CheckForOllamaError, 300)  ; Alle 300ms prüfen
        TrayTip("Überwachung gestartet - Drücke F9 zum Stoppen", "AutoClicker")
    }
}

; F8 für manuellen Test
F8:: {
    TrayTip("Manueller Test...", "Debug")
    CheckForOllamaError()
}

; ESC zum Beenden
Esc::ExitApp

CheckForOllamaError() {
    ; Nur nach sehr spezifischen Fenstern suchen
    windowFound := false
    hwnd := 0
    
    ; Methode 1: Suche EXAKT nach "Fehler" Titel UND OllamaAPI Text
    if WinExist("Fehler") {
        testHwnd := WinExist("Fehler")
        try {
            windowText := WinGetText(testHwnd)
            ; Nur wenn SOWOHL "Fehler" im Titel ALS AUCH "OllamaAPI" im Text
            if (InStr(windowText, "OllamaAPI") > 0 and InStr(windowText, "POST request failed") > 0) {
                hwnd := testHwnd
                windowFound := true
                TrayTip("OllamaAPI Fehlerfenster bestätigt", "Debug")
            }
        } catch {
            ; Ignoriere
        }
    }
    
    ; Nur wenn wir das richtige Fenster gefunden haben
    if windowFound and hwnd > 0 {
        ; Aktiviere das Fenster
        WinActivate(hwnd)
        Sleep(200)
        
        ; Versuche zuerst Enter (sicherste Methode)
        Send("{Enter}")
        TrayTip("Enter an OllamaAPI Fehler gesendet", "Erfolg")
        
        ; Stoppe die Überwachung für 3 Sekunden um mehrfaches Klicken zu verhindern
        global Monitoring
        Monitoring := false
        SetTimer(CheckForOllamaError, 0)
        
        ; Warte und starte dann neu
        Sleep(3000)
        if (Monitoring := true) {  ; Falls Benutzer nicht manuell gestoppt hat
            Monitoring := true
            SetTimer(CheckForOllamaError, 300)
        }
        return
    }
    
    ; Debug: Zeige alle 20 Sekunden dass Script läuft (weniger Spam)
    static LastDebug := 0
    if (A_TickCount - LastDebug > 20000) {
        TrayTip("Script läuft - suche nur nach OllamaAPI Fehlern", "Debug")
        LastDebug := A_TickCount
    }
}

; F7 für manuelles Klicken an aktueller Mausposition
F7:: {
    MouseGetPos(&x, &y)
    Click(x, y)
    TrayTip("Geklickt an Position: " . x . ", " . y, "Manueller Klick")
}

; F6 für Enter-Taste (oft funktioniert Enter als OK)
F6:: {
    Send("{Enter}")
    TrayTip("Enter gesendet", "Alternative")
}

; Zeige Hilfe beim Start
TrayTip("F9 = Start/Stop Überwachung`nF8 = Test`nF7 = Klick an Mausposition`nF6 = Enter senden`nESC = Beenden", "OllamaAPI Error Clicker")