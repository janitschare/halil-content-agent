**MERGE für den vorgelegten Diff: NO MATERIAL ISSUE FOUND im angeforderten Autoritätsumfang. Keine vollständige Sicherheitsfreigabe der ausgelassenen Spiellogik.**

**CONFIRMED FROM CODE**

- Prüfgrundlage: gelieferter Vergleich `523b055… → 087d530…`. Tatsächlicher HEAD, Arbeitsbaum und Übereinstimmung mit diesem Vergleich bleiben **UNVERIFIED**: Beide Shell-Aufrufe scheiterten vor dem Prozessstart.
- `ultimatepitch/src/Server.server.lua:328`: Die Teilnahme wird über das serverseitig gelesene Attribut `UP_InMatchQueue` gefiltert. Der Diff führt keinen Remote zum Setzen dieses Attributs ein. Ein neuer Client→Gameplay-Autoritätsbypass ist daraus nicht belegt.
- `ultimatepitch/src/Server.server.lua:1138`: Automatisches Nachrücken beim Charakterstart verlangt jetzt eine Anmeldung. Auch der neue Attribut-Callback prüft Anmeldung, Spielphase, vorhandenen Charakter und fehlenden Kaderplatz.
- `ultimatepitch/src/Server.server.lua:1167`: Die Abmeldung ersetzt den Kaderplatz serverseitig durch einen Bot, entfernt Teamzugehörigkeit und setzt einen gehaltenen Aurora-Windup dieses Spielers zurück.
- Im sichtbaren Kontext löschen `resetBall()` und `kickBall()` weiterhin `auroraShot`. Der Diff zeigt keine neue Möglichkeit, den Aurora-Kausalitätstoken über eine andere Schuss-/Passaktion hinweg zu behalten. Andere Ballaktionen sind nicht vollständig enthalten.
- Das neue Zonenlicht schreibt lokale Lighting-Eigenschaften anhand der Kamera. Im gezeigten Code besteht kein Datenpfad zu Ballrichtung, Tempo, Toren, Belohnungen oder Cooldowns. Gemäß Review-Scope kein Gameplay-Exploit-Finding.

**NEEDS ROBLOX STUDIO**

Nicht ausgeführt. Die kleinsten gezielten Prüfungen für die geänderte Teilnahme wären:

1. **Ein Client:** Während `Playing` und `Goal` serverseitig abmelden. Prüfen: genau ein Ersatzbot, Spieler in Lobby, Aurora-Windup abgebrochen, anschließend keine Ballaktion als ausgeschiedener Teilnehmer.
2. **Zwei Clients:** Einen Spieler während eines laufenden Matches anmelden und anschließend respawnen lassen. Prüfen: genau ein Kaderplatz pro Spieler, kein doppelter Ersatz und keine verwaiste Botfigur.
3. **Ein Client mit fremdem Spawn:** Nicht angemeldeten Spieler respawnen lassen. Prüfen: kein Stadion-Teleport. Zusätzlich kontrollieren, ob das weiterhin unbedingte `BaseSpeed = 16` in `Server.server.lua:1149` eine vorhandene Stadt-Bewegungslogik beeinflusst; deren Verbraucher fehlen im Diff.

Das sind offene Laufzeitprüfungen, keine nachgewiesenen Fehler. Ein weiterer vollständiger 10-Client-Test ist daraus nicht erforderlich.

**INFORMATION MISSING**

- Die vollständigen Handler für Kick/Pass/Shot/Aurora, Remote-Schemata, Rate Limits, Torattribution, Ausdauer und Bewegungsprüfung fehlen. Ihre unveränderte Sicherheit lässt sich aus diesem Diff nicht bestätigen.
- KickAnim, AuroraFX, Focus-/Touch-Behandlung, Reduced Motion sowie R15-Überlagerung und Cleanup sind nicht ausreichend enthalten. Keine neue Fehlfunktion daraus nachgewiesen.
- `Dome.lua`, `AuroraFX.lua`, `default.project.json`, `build.ps1`, `build.py` und Tests haben im gelieferten vollständigen Diff keine Änderungen. Keine erneute Bewertung ihres unveränderten Inhalts.
- **Keine Tests rerun.** Git-Historie war unzugänglich; dort dokumentierte grüne Tests wurden weder eingesehen noch nachgeprüft. Die mitgelieferten SOLO-/Live-Sync-Angaben bleiben Fremdevidenz; der dokumentierte offene Zwei-Client-KickAnim-Test bleibt offen.

Keine Dateien verändert, kein Studio gestartet und kein Build oder Installer ausgeführt.