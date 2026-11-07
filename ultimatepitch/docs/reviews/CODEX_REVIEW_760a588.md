**HOLD — Test-Harness gegen falsche Erfolgsmeldungen absichern, Build-Konfiguration angleichen und anschließend einen gezielten 2-Client-KickAnim-Test ausführen.**

Grundlage: ausschließlich der bereitgestellte Diff `6ca3bf4 → 760a588`. Der Shellzugriff scheiterte; tatsächliches HEAD, Arbeitsbaum und Git-Testhistorie konnten nicht unabhängig bestätigt werden. Keine Dateien verändert, keine Builds oder Studio-Tests ausgeführt.

**CONFIRMED FROM CODE**

1. **P2 — Test meldet Erfolg trotz ausgefallener Clients oder fehlender Animation.**  
   **Ort:** `ultimatepitch/tests/UP_KickAnimHarness.server.lua:64`  
   **Mechanismus:** Nach dem Berichts-Timeout wird bedingungslos `ok = true` gesetzt. Weder zwei Endberichte noch Pass-Anfragen, Animationen oder gemeldete Clientfehler werden vorausgesetzt. Damit kann ein vollständig ausgefallener Probe-Lauf grün erscheinen.  
   **Minimale Reproduktion:** In einem Test-Place zwei Spieler bis „Playing“ starten, beide Client-Probes deaktiviert lassen. Nach Ablauf der Wartezeiten liefert der Harness weiterhin `ok = true`, ohne Endberichte. Diese Reproduktion wurde hier nicht ausgeführt; das Ergebnis folgt aus dem Kontrollfluss.  
   **Minimaler Fix:** Strukturierte Ergebnisse der beiden erwarteten Spieler verlangen; Timeout, fehlende Berichte, Clientfehler und fehlende eigene beziehungsweise fremde Kick-Beobachtungen müssen `ok = false` ergeben.  
   **Zieltest:** Probe fehlt → rot; KickAnim deaktiviert → rot; funktionierende Darstellung auf beiden Clients → grün.

2. **P2 — Python-Build übernimmt die neue Lighting-Konfiguration nicht.**  
   **Ort:** `ultimatepitch/build.py:32`, gegenüber `ultimatepitch/default.project.json:6` und dem hinzugefügten Lighting-Block in `build.ps1`.  
   **Mechanismus:** Die Python-RBXLX enthält keinen Lighting-Service mit `LightingStyle = Realistic` und `PrioritizeLightingQuality = false`. PowerShell und Rojo setzen diese Werte ausdrücklich. Der dokumentierte Anspruch gleicher Build-Ergebnisse stimmt deshalb nicht; für den Python-Pfad ist dieselbe Lichtkonfiguration nicht gewährleistet.  
   **Minimale Reproduktion:** Beide Builder in einer isolierten Kopie ausführen und die erzeugten XML-Dateien vergleichen: Nur PowerShell serialisiert den Lighting-Block.  
   **Minimaler Fix:** Identischen Lighting-Block im Python-Builder ergänzen.  
   **Zieltest:** XML strukturell vergleichen und die beiden Properties nach dem Öffnen beider Artefakte prüfen.

**NEEDS ROBLOX STUDIO**

- Der Probe misst einen absoluten Hüftwinkel über `0.3` (`ultimatepitch/tests/UP_KickAnimProbe.client.lua:46`). Laufanimationen werden nicht herausgerechnet. Deshalb zusätzlich eine Negativkontrolle mit deaktiviertem QuickKick und laufender Figur durchführen; deren Laufbewegung darf keinen Kick-Erfolg ergeben.
- Ein gezielter 2-Client-Lauf genügt: eigener/fremder Pass, anschließend Pass→Aurora-Überlappung und Respawn während der Pose; Gelenke und Verbindungen müssen danach zurückgesetzt sein. Schreiben in `PreSimulation` entspricht grundsätzlich dem dokumentierten Motor6D-Timing und ist allein kein Animator-Konflikt. [Roblox Motor6D-Dokumentation](https://create.roblox.com/docs/reference/engine/classes/Motor6D)
- Focus-Verlust beziehungsweise Touch-Abbruch beim Laden sowie Reduced Motion während Aurora prüfen. Daraus ist im gelieferten Diff kein neuer bestätigter Gameplay-Bypass ableitbar.

**INFORMATION MISSING**

Die vollständigen Remote-Eingangsprüfungen, Bewegungs-/Stamina-Validierung, Torentscheidung sowie Teile von `releaseAurora`, Gelenksuche und Cleanup fehlen im Diff-Kontext. Ihre Sicherheit kann hier nicht insgesamt bestätigt werden.

Sichtbar bleiben Ballgeschwindigkeit und Kick-Auslösung serverseitig; `KickAnim` transportiert ausschließlich Darstellung. `kickBall` löscht weiterhin den Aurora-Kausalitätstoken. Für HUD, Grafikprofile, Sound und neue FX ist **kein konkreter Client→Gameplay-Autoritätsbypass nachgewiesen**.

Laut bereitgestelltem Projektstand sind Rojo-Live-Sync, SOLO-Tests und Sound-Laden dokumentiert; **von mir wurde keiner dieser grünen Tests erneut ausgeführt oder anhand der Git-Historie verifiziert**. KickAnim mit zwei Clients, Mobile und dynamische Lighting-Kompatibilität bleiben unbestätigt. Sound-Provenienz und Veröffentlichungsrechte bleiben laut Projektstand offen; erfolgreiches Laden belegt diese Rechte nicht.