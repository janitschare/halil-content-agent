**HOLD — Sitzungssperren erlauben Fortschrittsverlust und das Überschreiben neuerer Spielstände.**

Prüfbasis: gelieferter Diff `4349ede… → 76e072f…`. Tatsächlicher HEAD und Arbeitsbaum sind **UNKNOWN**: Der Shell-Aufruf scheiterte vor der Ausführung. Keine Dateien verändert, keine Studio-, Build- oder DataStore-Aktionen ausgeführt.

**CONFIRMED FROM CODE**

1. **P1 — Veralteter Server darf nach fremder Freigabe wieder schreiben.**  
   **Ort:** `ultimatepitch/src/CareerStore.lua:72`, Schreibprüfung bei `:120`.  
   **Mechanismus:** Eine fehlende Sperre gilt als „nicht fremd“. `save()` verlangt damit keinen positiven Besitznachweis. Sobald ein neuer Server seine Sperre freigibt, darf ein alter Server dessen neueren Stand überschreiben.  
   **Minimalreproduktion:** Gemeinsame Speicherattrappe: A lädt; B übernimmt nach Ablauf der Sperre und speichert 200 Coins mit `release=true`; danach speichert A seinen alten Stand von 100 Coins ebenfalls mit `release=true`. A erhält `"ok"` und überschreibt 200 mit 100. Dafür muss A zuvor keinen `"lost"`-Status erhalten haben.  
   **Minimalfix:** Schreiben ausschließlich bei vorhandener, exakt passender Sitzungssperre erlauben; fehlende Sperre bedeutet `"lost"`. Eine eindeutige Kennung je Spieler-Ladevorgang verhindert zusätzlich Kollisionen zwischen Wiederbeitritten im selben `JobId`.  
   **Zieltest:** Genau diese A/B/Freigabe/A-Sequenz muss den letzten Schreibversuch ablehnen.

2. **P1 — Frische Sitzungssperre wird nach etwa 15 Sekunden bedingungslos gestohlen.**  
   **Ort:** `ultimatepitch/src/CareerStore.lua:82`, Umgehung der Sperrprüfung bei `:90`.  
   **Mechanismus:** Nach fünf Wartezyklen à drei Sekunden ignoriert `steal` auch eine weiterhin frische Sperre, obwohl `LOCK_TIMEOUT=300` gilt. Bei einem Serverwechsel kann B dadurch den letzten gespeicherten Stand laden, während A noch ungespeicherte Belohnungen abschließend schreibt. As anschließender Schreibversuch wird abgewiesen; Belohnungen verschwinden. Der Selbsttest behandelt diese Übernahme ausdrücklich als Erfolg.  
   **Minimalreproduktion:** A lädt und verdient zusätzliche Coins ausschließlich im Arbeitsspeicher; Abschlusszugriff verzögern. B lädt denselben Schlüssel. Nach fünf Wartezyklen übernimmt B ohne Freigabe oder Zeitablauf und erhält den älteren Stand.  
   **Minimalfix:** Frische fremde Sperren niemals allein aufgrund einer Versuchszahl übernehmen; stattdessen begrenzt warten und den Ladevorgang abbrechen. Sperren auch bei unverändertem Profil regelmäßig erneuern — `Career.lua:345` speichert derzeit nur bei `dirty`. Das entspricht dem [Roblox-Sitzungssperrmodell](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing).  
   **Zieltest:** Frische, erneuerte Sperre bleibt geschützt; freigegebene beziehungsweise tatsächlich abgelaufene Sperre wird übernommen.

3. **P2 — Veröffentlichte Studio-Tests verwenden standardmäßig den echten Karriere-Datenspeicher.**  
   **Ort:** `ultimatepitch/src/Career.lua:423`.  
   **Mechanismus:** Ohne `UP_CareerMemoryStore=true` genügt eine gesetzte `PlaceId`, um auch in Studio `UP_Career_v1` zu öffnen. Bei aktiviertem Studio-API-Zugriff verändern Laden, Autosave und Abschluss denselben Datenbestand wie laufende Spielserver. Roblox bestätigt diese [gemeinsame Datenbasis ausdrücklich](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access).  
   **Minimalreproduktion:** In einer separaten veröffentlichten Test-Experience Studio-API-Zugriff aktivieren, Memory-Attribut weglassen, mit eigenem Benutzer starten, Coins verdienen und beenden: Der persistente Schlüssel dieses Benutzers wird verändert.  
   **Minimalfix:** Studio standardmäßig ausschließlich Speicherattrappe oder `"off"` verwenden lassen. Echte Integrationstests benötigen eine ausdrücklich konfigurierte, isolierte Testdatenbasis.  
   **Zieltest:** Studio ohne Testattribut führt keinen echten DataStore-Zugriff aus; Memory-Modus bleibt funktionsfähig.

**NEEDS ROBLOX STUDIO**

Nach den Korrekturen reichen gezielte Tests mit zwei simulierten Store-Sitzungen sowie ein kleiner Studio-Test für Laden, verzögertes Verlassen, Wiederbeitritt und Shutdown. Echte DataStore-Kompatibilität nur in einer isolierten Test-Experience prüfen. Ein neuer vollständiger Zehn-Client-Test ist hierfür nicht erforderlich.

Die sichtbare Rojo- und Build-Erweiterung platziert `CareerStore` konsistent neben `Career`; daraus ergibt sich kein zusätzlicher materieller Befund. Installer und erzeugte Artefakte wurden nicht ausgeführt beziehungsweise importiert.

**INFORMATION MISSING**

Kick/Pass/Shot/Aurora, Torzuordnung, Stamina, Bewegungsvalidierung sowie R15-Überlagerungen, Cleanup, Focus/Touch/Reduced Motion, Grafik und Sound sind im gelieferten Diff nicht als Implementierung enthalten. Ihre Korrektheit bleibt **UNKNOWN**. Im sichtbaren Career-Handler bleiben Typprüfung, Anfragedrosselung und serverseitige Kaufentscheidungen erhalten; die UI-Erweiterung zeigt keinen konkreten Gameplay-Autoritätsbypass.

Git-Historie und dokumentierte grüne Testergebnisse waren nicht zugänglich. **Etwaige dort dokumentierte grüne Tests wurden von mir nicht erneut ausgeführt.** Auch `CareerStore_selftest.lua` wurde nicht ausgeführt; sein Vorliegen ist kein Laufzeitnachweis.