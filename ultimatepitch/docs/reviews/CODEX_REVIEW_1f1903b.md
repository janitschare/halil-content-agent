**HOLD — Persistenz-Fehlerpfade vor dem Merge korrigieren und gezielt testen.**

Reviewbasis: ausschließlich der bereitgestellte Diff `4349ede… → 1f1903b…`. Der Shellzugriff scheiterte; tatsächlicher HEAD, Working Tree und Git-Historie sind **UNVERIFIED**. Keine Dateien verändert, keine Builds oder Tests ausgeführt.

**CONFIRMED FROM CODE**

1. **P2 — Laden blockiert nach erfolgreichem Schreiben mit verlorener Antwort an der eigenen Sitzungssperre.**  
   **Ort:** `ultimatepitch/src/CareerStore.lua:97`, Sperrsetzung bei `:102`.  
   **Mechanismus:** Schreibt `UpdateAsync` die Sperre und meldet anschließend einen Fehler, wiederholt `load` denselben Vorgang. `freshLock` unterscheidet die eigene Kombination aus `job` und `sid` nicht von einer fremden Sperre. Der Spieler wartet dadurch ungefähr fünf Minuten auf seine eigene Sperre; währenddessen bleiben Käufe gesperrt. Roblox dokumentiert ausdrücklich, dass eine fehlgeschlagene Schreibantwort einen bereits erfolgten Backend-Schreibvorgang nicht ausschließt. [Roblox-Fehlersemantik](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits)  
   **Minimalreproduktion/Test:** Adapter lässt beim ersten Aufruf den Callback schreiben und wirft **danach** einen Fehler; weitere Aufrufe funktionieren. Mit künstlicher Uhr prüfen, dass der zweite Versuch sofort lädt. Die vorhandene Attrappe simuliert ausschließlich Fehler **vor** dem Schreiben und deckt diesen Fall nicht ab.  
   **Minimalfix:** Dieselbe `job`-/`sid`-Kombination innerhalb desselben Ladeversuchs idempotent anerkennen; Sperren anderer Ladeversuche weiterhin respektieren.

2. **P2 — Fehlgeschlagener Abschlussspeichervorgang verwirft den noch verfügbaren Sitzungsstand.**  
   **Ort:** `ultimatepitch/src/Career.lua:348`, Entfernung bei `:349`; entsprechender Ladeabschluss bei `:317`.  
   **Mechanismus:** `finalSave` ignoriert den Rückgabestatus von `saveNow` und entfernt den Datensatz auch nach ausgeschöpften Schreibversuchen. Sobald der Dienst wieder erreichbar ist, existiert kein weiterer Speicherversuch. Ungespeicherter Fortschritt geht verloren; die alte Sperre bleibt bis zum Ablauf bestehen. Beim Verlassen während des Ladens wird das Ergebnis von `persist.save` ebenfalls ignoriert.  
   **Minimalreproduktion/Test:** Laden und Autosave erfolgreich durchführen, weitere Coins verdienen, vier Schreibfehler injizieren und Spieler entfernen. Danach Fehler abschalten: Der gespeicherte Stand bleibt alt, obwohl der Server weiterläuft.  
   **Minimalfix:** Fehlgeschlagene Abschlussstände serverintern für weitere begrenzte Wiederholungen behalten; erst nach bestätigtem Abschluss oder endgültigem Sperrverlust entfernen. Den Ladeabschluss durch denselben Fehlerpfad führen. Beim Shutdown die bestehende Zeitgrenze beachten.

3. **P2 — Speicherstörung wird dem Spieler weiterhin als aktiver Autosave angezeigt.**  
   **Ort:** `ultimatepitch/src/Career.lua:336`; Statusanzeige in `ultimatepitch/src/CareerUI.lua:65`.  
   **Mechanismus:** Nach allen fehlgeschlagenen Autosave-Versuchen werden lediglich `dirty` und ein Server-Warnhinweis gesetzt. `CareerSave` bleibt `"ok"`; die Oberfläche zeigt weiter „AUTOSAVE AN“. Die neu eingeführte Störungsanzeige wird für diesen Schreibfehler nie aktiviert.  
   **Minimalreproduktion/Test:** Erfolgreich laden, vier Schreibfehler injizieren, Autosave auslösen und `CareerSave` sowie HUD prüfen.  
   **Minimalfix:** Schreibstörungen separat vom Lade-/Sperrstatus abbilden und nach erfolgreichem Speichern zurücksetzen. Einfach `"error"` zu setzen reicht nicht: Die aktuelle Speicherfreigabe in `saveNow` würde anschließend weitere Versuche verhindern.

Diese Mechanismen sind aus dem Code ableitbar; die beschriebenen Reproduktionen wurden von mir **nicht ausgeführt**.

**NEEDS ROBLOX STUDIO**

Nach den gezielten Fehlerfalltests genügt zunächst ein kleiner Integrationstest mit einem Spieler und der Speicherattrappe: Laden → Belohnung/Kauf → Autosave → nachgestellter Wiederbeitritt; zusätzlich Verlassen während verzögerten Ladens und Shutdown bei laufendem Save.

Die neue `CareerStore`-Einbindung ist in PowerShell-Build, Python-Build und Rojo strukturell konsistent. Tatsächliches Laden der erzeugten Module und echtes DataStore-Verhalten sind ungetestet. Aus dem Diff ergibt sich kein weiterer konkreter neuer API-Kompatibilitätsfehler.

**INFORMATION MISSING**

Kick/Pass/Shot/Aurora, Torattribution, Stamina, Bewegungsplausibilität, R15-Animationsbereinigung sowie Focus/Touch/Reduced Motion sind im gelieferten Diff nicht enthalten. Dazu ist keine neue Sicherheitsfreigabe möglich. Die sichtbaren Career-Anfragen prüfen serverseitig Typen, Katalog, Guthaben, Besitz, Stufe und Anfrageabstand; die Implementierung von `near` fehlt im Ausschnitt. Die HUD-Änderungen zeigen keinen konkreten Client→Gameplay-Bypass.

Git-Historie und dort dokumentierte grüne Tests waren nicht zugänglich und wurden **nicht erneut ausgeführt**. Auch der neue Selbsttest und die erwähnten früheren Studio-/SOLO-Tests gelten hier nicht als eigener Verifikationsnachweis. Ein vollständiger 10-Client-Test ist zur Klärung dieser Befunde nicht erforderlich.