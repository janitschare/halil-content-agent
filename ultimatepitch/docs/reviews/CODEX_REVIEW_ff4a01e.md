**HOLD — Torprämien können dem falschen Spieler zugeordnet werden; außerdem liegt der Shop-Schließen-Knopf auf schmalen Displays außerhalb des Bildschirms.**

**CONFIRMED FROM CODE**

1. **P2 — Veralteter Ballkontakt vergibt falsche Torprämien.**  
   **Fundstelle:** `ultimatepitch/src/Server.server.lua:1492`  
   `lastTouch` wird bei Kick, Aurora und Ballführung aktualisiert. Der vorhandene `Ball.Touched`-Handler berücksichtigt körperliche Kontakte dagegen ausschließlich für das Aurora-Token. Eine anschließende Berührung durch einen anderen Menschen oder Bot aktualisiert beziehungsweise löscht `lastTouch` nicht. Trotzdem verwendet die neue Torwertung diesen Wert für `goalsBy` und damit für Coins. Die Aussage „nil nach Bot-Kontakt“ ist dadurch nicht durchgehend erfüllt.  
   **Minimalreproduktion:** A spielt einen hohen Ball; Mitspieler B lenkt ihn mit dem Körper ins gegnerische Tor, ohne Kick-Anfrage und ohne Dribbelannahme. A bleibt als Torschütze gespeichert und erhält bei abgeschlossenem Match die Torprämie.  
   **Minimalfix:** Relevante serverseitige Figurenkontakte unabhängig vom Aurora-Token erfassen: Menschen als letzten Kontakt setzen, bei Bots löschen. Kontakte von Arena-Geometrie ignorieren.

2. **P2 — Shop-Dialog lässt sich auf schmalen Touch-Displays nicht über „X“ schließen.**  
   **Fundstelle:** `ultimatepitch/src/CareerUI.lua:115`, Schließen-Knopf ab `:121`  
   Der Shop ist fest 460 Pixel breit und horizontal zentriert. `UISizeConstraint.MaxSize` verkleinert ihn nicht auf die verfügbare Bildschirmbreite. Bei einer GUI-Breite von 375 Pixeln beginnt der 30 Pixel breite Schließen-Knopf rechnerisch bei x=375,5 und liegt vollständig außerhalb des sichtbaren Bereichs.  
   **Minimalreproduktion:** Shop bei 375 Pixeln verfügbarer GUI-Breite öffnen und über „X“ schließen versuchen. Weglaufen bleibt zwar ein Ausweg, ersetzt aber keinen erreichbaren Dialogabschluss.  
   **Minimalfix:** Panelgröße an die verfügbare GUI-Fläche einschließlich Randabstand begrenzen; bei kleinen Höhen den Shopinhalt scrollbar machen.

**NEEDS ROBLOX STUDIO**

Die kleinsten gezielten Tests zum Schließen dieser Befunde:

- Zwei Clients: kontrollierte Körperablenkung durch B ohne Kick-Anfrage; zusätzlich Bot-Kontakt. Torschütze und Coin-Differenz nach Matchende prüfen. Für die Rewards kann ein isolierter Test das Matchende beschleunigen.
- Ein Client im Geräteemulator: Shop bei 375 Pixeln Breite und kleiner Querformat-Höhe öffnen, schließen und sämtliche Artikel bedienen.

Nicht ausgeführt wurden R15-Animationsüberlagerung/-Cleanup, Focus-/Touch-Verhalten, Reduced Motion, NPC-Erzeugung oder Lighting-Kompatibilität. Die neue Karriere-UI erhält keinen Reduced-Motion-Schalter; ihre Coin-Animation bleibt daher unabhängig von dieser Einstellung aktiv. Das ist kein Gameplay-Autoritätsbypass.

**INFORMATION MISSING / EVIDENZSTATUS**

- Prüfgrundlage: ausschließlich der gelieferte Diff `7464f4b…` → `ff4a01e…`. Der Shell-Aufruf scheiterte technisch; tatsächlicher HEAD, Arbeitsbaum und Git-Historie konnten nicht bestätigt werden.
- **Keine Tests wurden von mir erneut ausgeführt.** Die im Projektkontext dokumentierten Rojo-/Studio-SOLO-Erfolge sind keine eigene Verifikation. Weitere grüne Tests aus der Git-Historie konnte ich nicht einsehen oder nachprüfen.
- Kick-/Pass-/Shot-/Aurora-, Stamina- und Bewegungsvalidierung sind nur ausschnittsweise enthalten. Eine vollständige Sicherheitsfreigabe dieser unveränderten Pfade wäre daraus nicht belegbar.
- Im neuen Career-Remote sind Typ-, Katalog-, Besitz-, Guthaben-, Nähe- und Zeitabstandsprüfungen sichtbar. Clientwerte bestimmen weder Preise noch Belohnungen.
- Beide Buildskripte und Rojo binden die neuen Module konsistent ein. Aus diesen Änderungen ergibt sich kein zusätzlicher belegter Buildfehler.
- Keine Projektdateien geändert, keine Builds oder Studio-Sitzungen gestartet, keine Komponenten hinzugefügt.