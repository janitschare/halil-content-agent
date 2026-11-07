# UltimatePitch v0.5

5v5-Fußball für Roblox im SPECTRA DOME: Bots mit Torwart, serverseitige Ball-, Tor- und Skill-Logik,
AURORA BREAK, Broadcast-HUD, Stadionsound und drei Grafikprofile (Hoch / Mittel / Niedrig).

**Starten:** `UltimatePitch_v0.5.rbxlx` in Studio öffnen → **Spielen**. Die Welt baut sich beim Start selbst.
Alternative: `UltimatePitch_v0.5_Installer.lua` in die Befehlsleiste (Test vorher stoppen).

**Steuerung:** F / Klick halten = Schuss · E = Pass · Shift = Sprint · R = AURORA BREAK · M = Effekte reduzieren · G = Grafikprofil

## Entwicklung mit Rojo (Live Sync)

`default.project.json` bildet `src/` auf die Place ab (Server + Dome, Client + AuroraFX). Mit Rojo 7.7:

```
rojo serve default.project.json
```

In Studio im Rojo-Plugin **Connect** (Port 34872). Änderungen an `src/` landen sofort in Studio.
Testskripte unter `tests/` sind nicht Teil des Builds.

Release-Dateien neu bauen: `powershell -ExecutionPolicy Bypass -File build.ps1`.

## Sounds

Freie Soundeffekte von „ProSoundEffects“ aus dem Roblox Creator Store (von Roblox lizenzierte Bibliothek,
kein eigener Upload): Ballschuss 9119330229, Pfiff 9118113825, Parade 9119335569, Stadionatmosphäre 9119562234,
Torjubel 9120974125, AURORA-Knall 9120769331.
