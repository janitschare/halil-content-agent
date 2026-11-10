**HOLD — P2: Eine Abmeldung während des Teamaufbaus kann einen dauerhaft unbesetzten Kaderplatz hinterlassen.**

**CONFIRMED FROM CODE**

1. **P2 — `ultimatepitch/src/Server.server.lua:1273`, `:1283`; Folgeproblem `:1238`**

   **Mechanismus:** `leaveMatch()` entfernt den Kaderplatz sofort, ersetzt ihn während `Intermission` aber nicht. `setupTeams()` läuft noch in dieser Phase und kann beim Avatarladen für Bots warten. Wurde der betreffende Spielerplatz bereits durchlaufen, bleibt er anschließend leer. `joinRunningMatch()` berücksichtigt ausschließlich vorhandene Bot-Einträge und kann diesen `nil`-Platz später ebenfalls nicht besetzen.

   **Minimale Reproduktion:** Zwei Menschen anmelden. Während `setupTeams()` beim Erzeugen eines späteren Bots wartet, den bereits durchlaufenen menschlichen Slot durch serverseitiges Ändern von `UP_Arena` abmelden. Der verbleibende Mensch hält das Match aktiv. Erwartetes Fehlerbild: Ein Team startet mit vier statt fünf Figuren; spätere Beitritte füllen den fehlenden Slot nicht.

   **Minimaler Fix:** Den laufenden Kaderaufbau explizit berücksichtigen: währenddessen frei gewordene Plätze zuverlässig nachbesetzen und den vollständigen Kader vor `Playing` sicherstellen. Dabei die vorhandene Prüfung gegen zwischenzeitliche Neubesetzung beibehalten.

Im sichtbaren Diff ist **kein neuer konkreter Client→Gameplay-Autoritätsbypass nachgewiesen**: Pass/Shot/Aurora benötigen nun zusätzlich einen Platz im jeweiligen Arena-Kader; menschliches Dribbling ist entsprechend eingeschränkt. Ausdauer, Bewegungsbudget und Aurora-Cooldown werden gemeinsam gespeichert; die Spielerprüfung wird nur einmal registriert. Die sichtbaren Kick-, Reset- und Annahmepfade löschen weiterhin das Aurora-Schusstoken. Das bestätigt ausschließlich diese sichtbaren Pfade.

**NEEDS ROBLOX STUDIO**

- **Blocker-Test:** Den beschriebenen Abmeldezeitpunkt mit kontrolliert verzögertem Bot-Aufbau auslösen. Danach vollständige Kader und spätere Nachbesetzung prüfen. Zwei Clients genügen.
- **Gezielte Arena-Regression:** Zwei getrennte Arenen mit unterschiedlichem Ursprung; einen Spieler wechseln lassen. Prüfen: ausschließlich ein Kaderplatz, keine Ballkontrolle in der verlassenen Arena, kein Zurückteleportieren durch deren Matchende und keine doppelte Ausdauerbelastung.
- **Client-Integration:** HUD/Ball-Zuordnung zur zweiten Arena sowie R15-KickAnim-Überlagerung und Cleanup gezielt prüfen. Daraus ergibt sich anhand des vorliegenden Diffs noch kein bestätigter Fehler.

Studio, Geräte-, Performance- und API-Laufzeittests wurden von mir **nicht ausgeführt**.

**INFORMATION MISSING**

- Der Shell-Start scheiterte vor Ausführung. Tatsächliches **HEAD**, Arbeitsbaum und Übereinstimmung des angehängten Diffs mit `bb26b919… → 2662b7fc…` sind daher **UNVERIFIED**. Zeilenangaben stammen aus den Diff-Hunks.
- Vollständige Implementierungen von Aurora-Freigabe, Remote-Verarbeitung, Bot-Erzeugung und weiteren unveränderten Funktionen fehlen. Deshalb keine vollständige Freigabe von Schema, Rate-Limits, Torattribution oder Bewegungsvalidierung.
- `Client.client.lua`, `AuroraFX.lua`, `Dome.lua`, `build.ps1`, `build.py` und `default.project.json` sind nicht enthalten. Focus, Touch, Reduced Motion, Animation-Cleanup und Build-/Rojo-Kompatibilität bleiben offen. Rein lokale FX-, Grafik- oder Soundmanipulation wird nicht als Gameplay-Exploit gewertet.
- Die dokumentierten SOLO-/Live-Sync-Prüfungen habe ich **nicht wiederholt**. Konkrete grüne Testeinträge der Git-Historie waren nicht einsehbar; keine daraus abgeleitete Verifikation. Die laut Projektstatus ausstehende KickAnim-Zwei-Client-Regression bleibt ausstehend.

Keine Dateien verändert, keine Builds ausgeführt und keine externen Schreibaktionen vorgenommen.