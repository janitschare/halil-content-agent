**HOLD — den Referenz-Leak beheben und die neue Bewegungsebene gezielt mit zwei Clients prüfen. Kein neuer Client→Gameplay-Autoritätsbypass im gelieferten Diff erkennbar.**

Prüfbasis: ausschließlich der angegebene Diff `41f423c… → ab5ec5c…`. Der Shell-Prozess konnte nicht gestartet werden; tatsächlicher HEAD, Arbeitsbaum und Git-Historie sind **UNKNOWN**. Keine Dateien verändert, keine Tests oder Studio-Sitzungen ausgeführt.

**CONFIRMED FROM CODE**

1. **P2 — Entfernte Figuren bleiben unbegrenzt in Animationstabellen gespeichert.**  
   **Ort:** `ultimatepitch/src/AuroraFX.lua:163`, Einträge bei `:192` und `:200`, Bereinigung ausschließlich innerhalb der Figurenschleife ab `:211`.  
   **Mechanismus:** `receive` und `celebrate` verwenden starke Character-Schlüssel. Entfernte Characters erscheinen nicht mehr in `characters()` und erreichen deshalb die zeitabhängige Bereinigung nicht. Auch abgelaufene Einträge außerhalb der Kamerareichweite werden nicht entfernt. Wiederholte Spielerwechsel oder Respawns können diese Tabellen dauerhaft vergrößern.  
   **Minimale Reproduktion:** Client A beobachtet, wie B Ballbesitz erhält; B verlässt innerhalb von 0,3 Sekunden die Sitzung. Nach Ablauf der Annahmezeit bleibt Bs alter Character Schlüssel in `receive`. Alternativ während des Torjubels respawnen. Tabellen im Debugger kontrollieren.  
   **Minimaler Fix:** Beide Tabellen ebenfalls mit schwachen Schlüsseln anlegen; alternativ entfernte Characters und abgelaufene Einträge unabhängig von Reichweite und aktueller Figurenliste löschen.  
   **Test erforderlich:** Wiederholte Besitzwechsel mit anschließendem Respawn/Verlassen; prüfen, dass alte Schlüssel nach Bereinigung beziehungsweise Garbage Collection verschwinden. Der Lebenszyklusfehler ist aus dem Code bestätigt; seine Speicherwirkung wurde nicht gemessen.

Die neuen Gelenkänderungen schreiben `Motor6D.Transform`; Roblox kennzeichnet diese Eigenschaft als **nicht repliziert**. Daraus folgt hier kein belegter Eingriff in Ballbesitz, Schussgeschwindigkeit oder Torwertung. [Roblox-API](https://create.roblox.com/docs/reference/engine/classes/Motor6D)

Die Serverergänzung setzt nach einem bereits erfassten Tor ausschließlich Bot-Sprünge. Sie übernimmt keine neue Client-Eingabe und verändert im sichtbaren Ausschnitt weder Torattribution noch Aurora-Kausalität.

**NEEDS ROBLOX STUDIO**

- **Kleinster Regressionstest:** Zwei Clients, ein R15-Spieler plus Bot. Sprint/Dribbling → normaler Pass/Schuss → Aurora → Torjubel. Beide Ansichten auf konkurrierende Gelenkschreibzugriffe und dauerhaft zurückbleibende Posen prüfen; anschließend Kameradistanz über/unter 150 Studs wechseln und respawnen.
- `jointsOf()` speichert seine erste Gelenkauswahl dauerhaft (`AuroraFX.lua:166–175`). Ob beim tatsächlichen Spawn unvollständige Gelenke gecacht werden können, ist ohne Implementierung von `joint()` und Laufzeitnachweis offen. Deshalb **kein zweiter bestätigter Befund**.
- Focus-Wechsel, Touch und Reduced Motion mit dieser Sequenz prüfen. `startMotion()` enthält selbst keine erkennbare Präferenzabfrage; welche Figurenanimationen die bestehende Reduced-Motion-Einstellung ausschließen soll, ist nicht dokumentiert.

**INFORMATION MISSING**

Kick/Pass/Shot/Aurora-Remotehandler, Schema-Prüfung, Rate Limits, Stamina, Bewegungsplausibilität, Netzwerkbesitz und Token-Invalidierung fehlen im Diff. Ihre Sicherheit bleibt **UNVERIFIED**; „unverändert“ ist kein Sicherheitsnachweis.

`build.ps1`, `build.py`, `default.project.json`, vollständige HUD-/Grafik-/Soundpfade und Tests sind nicht enthalten. Dazu gibt es keine erneute Freigabe oder zusätzliche Befunde.

**Teststatus:** Keine Tests erneut ausgeführt. In der Git-Historie dokumentierte grüne Ergebnisse konnte ich weder einsehen noch unabhängig bestätigen. Die bereitgestellten SOLO-/Live-Sync-Angaben sind Fremdnachweise; die ausdrücklich ausstehende Zwei-Client-Regression bleibt offen. Ein neuer vollständiger Zehn-Client-Test ist hierfür nicht erforderlich.