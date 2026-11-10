# Solo-Smoke-Test der verbindlichen Place, 2026-11-10 – BESTANDEN

Place: `experiments/v04-studio/UltimatePitch_v04_aurora2.rbxlx` (Code `0a1a1da`, frisch aus der Datei geöffnet, ohne Rojo).

| Prüfung | Ergebnis |
|---|---|
| Matchstart | Phase „Playing“, 9 Bots |
| Ball | Ballannahme vor dem Fuß, `BallOwner` = Spieler |
| Pass (Taste E) | Ball 0,15 s danach 12,4 Studs vom Spieler entfernt |
| AURORA BREAK (Taste R) | `AuroraWindup` + `AuroraKick`, Knall spielt, Einblendung „AURORA BREAK“, Cooldown gesetzt. Erster Versuch ohne Auslösung: Ball war beim Tastendruck nicht mehr am Fuß (2–3 s Testverzögerung) – Testablauf, kein Spielfehler |
| Toranzeige | Tor Rot: HUD „2 – 0“, Server 2:0, GOAL-Banner, Großbildwand „GOAL!“, Torjubel-Sound |
| HUD | Anzeigetafel, Phase, Leisten, AURORA-Kachel, Grafikprofil-Anzeige |
| Stadionbeleuchtung | `LightingStyle` Realistic, ClockTime 20,3, Brightness 1,5, Atmosphäre/Bloom/Farbkorrektur aktiv, 12/12 Feldstrahler an, Schatten im Profil „Hoch“ |
| Konsole | keine Skriptfehler (nur bekannte fremde Meldung zu Asset 203785492) |

## Lighting-Migrationsdialog
Studio meldete beim Öffnen „Migration von Kompatibilitäts- zu Voxel-Beleuchtung“. Keine sichtbaren Auswirkungen:
Lichtwerte entsprechen der Server-Konfiguration, Vergleichsbild aus identischer Kameraposition wie am 07.11.
(Flutlicht, Rasen, Traversen, Ränge) ohne erkennbaren Unterschied. Keine erneute Migration ausgelöst, Datei nicht erneut gespeichert.
