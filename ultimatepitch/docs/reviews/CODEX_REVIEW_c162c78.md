**HOLD – Kamera-Abbruch beim Respawn korrigieren oder mit einem gezielten Studio-Test nachweisen, dass keine Kamerasteuerung zurückbleibt.**

Grundlage: ausschließlich der beigefügte Diff `f2ab1b7… → c162c78…`. Der lokale Git-Zugriff scheiterte; tatsächlicher HEAD, Arbeitsbaum und Git-Testhistorie konnten nicht unabhängig bestätigt werden. Keine Dateien verändert, keine Builds oder Studio-Tests ausgeführt.

**CONFIRMED FROM CODE**

**1. P2 – Respawn invalidiert den Intro-Token, beendet aber laufende Kamera-Tweens nicht.**  
`ultimatepitch/src/Matchday.lua:264–267`, zusammen mit der Tween-Erzeugung in `cameraFlight()`.

- **Mechanismus:** `CharacterAdded` erhöht `introToken` und setzt `CameraType = Custom`. Der Token verhindert anschließend weitere `tw:Play()`-Aufrufe und die alte Wiederherstellung. Ein bereits gestarteter Tween bleibt jedoch aktiv und schreibt weiterhin auf `Camera.CFrame`. Die behauptete sofortige Kamerafreigabe ist damit unvollständig: Die Standardkamera erhält die Kontrolle, während der Intro-Tween dieselbe Kamera weiter verändert.
- **Minimale Reproduktion:** Matchstart auslösen und während eines laufenden Flugsegments respawnen. Prüfen, ob der alte Tween nach `CharacterAdded` weiterhin läuft und Kamerabewegung beziehungsweise Zittern verursacht.
- **Minimaler Fix:** Kamera-Tweens speichern und beim Abbruch zuerst `Cancel()` aufrufen; anschließend Kamera freigeben. Dieselbe Abbruchfunktion für reguläres Ende und Respawn verwenden.
- **Evidenz:** Fehlendes Tween-Cancel ist aus dem Code bestätigt; die sichtbare Auswirkung muss in Studio geprüft werden.

Der Diff ergänzt **keine Remote-Aufrufe und keine serverseitige Spiellogik**. Pyro-Parts sind lokal, verankert sowie ohne Kollision, Touch und Query. LED-Farben und Publikumsbewegungen sind lokale Darstellung. Daraus ergibt sich kein belegter neuer Client→Gameplay-Autoritätsbypass.

Die zusätzliche `Matchday`-Modulhierarchie ist in `build.ps1`, `build.py` und `default.project.json` konsistent eingebunden. Im geänderten Integrationscode ist kein konkreter Build- oder Roblox-API-Fehler erkennbar.

**NEEDS ROBLOX STUDIO**

Der kleinste Test zum Schließen des Befunds ist **ein SOLO-Matchstart mit Respawn mitten im Kameraflug**. Nach der Korrektur muss der aktive Tween beendet sein und die Kamera dem neuen Charakter zuverlässig folgen.

Zusätzlich ist gezielt zu prüfen, ob während der 3,2 Sekunden Kameraflug bereits spielbare Aktionen möglich sind: Der Flug beginnt erst bei `Phase == "Playing"`. Der Diff zeigt keine Eingabesperre. Ob dadurch tatsächlich ein Nachteil beim Anstoß entsteht, hängt vom unveränderten Servercode ab.

Reduced Motion unterdrückt den Flug beim Start; laufende LED- und Publikumsanimationen übernehmen den Wert dagegen nur beim Effektbeginn. Ein Umschalten während des Effekts beendet diese Animationen nicht unmittelbar. Daraus leite ich ohne weitere Anforderungen keinen zusätzlichen materiellen Befund ab.

**INFORMATION MISSING**

- `Server.server.lua` ist nicht enthalten. Kick/Pass/Shot/Aurora-Autorität, Remote-Schemas, Rate Limits, Torzuordnung, Stamina, Bewegungsplausibilität und Aurora-Kausalität können deshalb hier nicht neu bestätigt werden.
- KickAnim, AuroraFX, Sound und bestehende Focus-/Touch-Behandlung sind unverändert beziehungsweise nicht vollständig sichtbar; keine erneute Freigabe dieser Bereiche.
- **Keine Tests wurden von mir erneut ausgeführt.** Welche grünen Tests die Git-Historie dokumentiert, konnte ich nicht verifizieren. Die bereitgestellten Projekthinweise nennen SOLO-/Live-Sync-Evidenz, ausdrücklich aber keinen ausgeführten neuen KickAnim-Zwei-Client-Test. Ein vollständiger Zehn-Client-Test ist für diesen Diff nicht erforderlich.