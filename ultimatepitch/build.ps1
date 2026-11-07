# Baut aus src/ die Place-Datei (.rbxlx) und den Command-Bar-Installer (PowerShell-Gegenstück zu build.py).
#   ServerScriptService.UltimatePitchServer (Script)          <- src/Server.server.lua, Kind-Modul Dome <- src/Dome.lua
#   StarterPlayerScripts.UltimatePitchClient (LocalScript)    <- src/Client.client.lua, Kind-Modul AuroraFX <- src/AuroraFX.lua
# Aufruf: powershell -ExecutionPolicy Bypass -File build.ps1
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$V = "0.5"
$enc = New-Object System.Text.UTF8Encoding($false)

function Src([string]$name) {
    $text = [IO.File]::ReadAllText((Join-Path $here "src/$name"), $enc).Replace("`r`n", "`n")
    if ($text.Contains("]]>") -or $text.Contains("]==]")) { throw "src/$name enthält ]]> oder ]==]" }
    return $text
}
$server = Src "Server.server.lua"
$client = Src "Client.client.lua"
$dome = Src "Dome.lua"
$aurora = Src "AuroraFX.lua"

function Item([string]$cls, [string]$ref, [string]$name, [string]$src, [string]$children) {
    $disabled = if ($cls -eq "ModuleScript") { "" } else { "<bool name=`"Disabled`">false</bool>" }
    return "<Item class=`"$cls`" referent=`"$ref`"><Properties>" +
        "<string name=`"Name`">$name</string>$disabled" +
        "<ProtectedString name=`"Source`"><![CDATA[$src]]></ProtectedString>" +
        "</Properties>$children</Item>"
}

$rbxlx = "<roblox version=`"4`">`n" +
    "<Item class=`"Workspace`" referent=`"RBX0`"><Properties><string name=`"Name`">Workspace</string></Properties></Item>`n" +
    "<Item class=`"Lighting`" referent=`"RBX8`"><Properties><string name=`"Name`">Lighting</string>" +
    "<token name=`"LightingStyle`">0</token><bool name=`"PrioritizeLightingQuality`">false</bool></Properties></Item>`n" +
    "<Item class=`"ServerScriptService`" referent=`"RBX1`"><Properties><string name=`"Name`">ServerScriptService</string></Properties>`n" +
    (Item "Script" "RBX2" "UltimatePitchServer" $server (Item "ModuleScript" "RBX6" "Dome" $dome "")) + "`n" +
    "</Item>`n" +
    "<Item class=`"StarterPlayer`" referent=`"RBX3`"><Properties><string name=`"Name`">StarterPlayer</string></Properties>`n" +
    "<Item class=`"StarterPlayerScripts`" referent=`"RBX4`"><Properties><string name=`"Name`">StarterPlayerScripts</string></Properties>`n" +
    (Item "LocalScript" "RBX5" "UltimatePitchClient" $client (Item "ModuleScript" "RBX7" "AuroraFX" $aurora "")) + "`n" +
    "</Item></Item>`n" +
    "</roblox>`n"
[IO.File]::WriteAllText((Join-Path $here "UltimatePitch_v$V.rbxlx"), $rbxlx, $enc)

$installer = "-- UltimatePitch v$V – Command-Bar-Installer (Alternative zur .rbxlx)`n" +
    "-- Test vorher stoppen! Einfügen, Enter, dann Spielen. Die Welt baut sich beim Start.`n" +
    "if game:GetService(`"RunService`"):IsRunning() then`n" +
    "`terror(`"❌ Erst Test stoppen (rotes Quadrat), dann erneut ausführen!`")`n" +
    "end`n" +
    "local SSS = game:GetService(`"ServerScriptService`")`n" +
    "local SPS = game:GetService(`"StarterPlayer`"):FindFirstChildOfClass(`"StarterPlayerScripts`")`n" +
    "-- Schutz: Der Installer löscht nichts. Vorhandene UltimatePitch-Objekte werden nur nach ausdrücklicher`n" +
    "-- Bestätigung (_G.UP_REPLACE = true) ersetzt und vorher nach ServerStorage verschoben (Rückgängig: Strg+Z).`n" +
    "local old = {}`n" +
    "for _, o in pairs({ SSS:FindFirstChild(`"UltimatePitchServer`"), SPS:FindFirstChild(`"UltimatePitchClient`"),`n" +
    "`tworkspace:FindFirstChild(`"UltimatePitch`"), game:GetService(`"ReplicatedStorage`"):FindFirstChild(`"UltimatePitch`") }) do`n" +
    "`ttable.insert(old, o)`n" +
    "end`n" +
    "if #old > 0 and _G.UP_REPLACE ~= true then`n" +
    "`tlocal names = {}`n" +
    "`tfor _, o in ipairs(old) do table.insert(names, o:GetFullName()) end`n" +
    "`terror(`"⚠ Nichts verändert: vorhandene UltimatePitch-Objekte gefunden (`" .. table.concat(names, `", `") .. `"). `" ..`n" +
    "`t`t`"Zum Ersetzen zuerst  _G.UP_REPLACE = true  ausführen, dann den Installer erneut. Alte Objekte werden nach ServerStorage gesichert.`")`n" +
    "end`n" +
    "_G.UP_REPLACE = nil`n" +
    "game:GetService(`"ChangeHistoryService`"):SetWaypoint(`"Vor UltimatePitch v$V`")`n" +
    "if #old > 0 then`n" +
    "`tlocal backup = Instance.new(`"Folder`")`n" +
    "`tbackup.Name = `"UP_Backup_`" .. os.date(`"%Y%m%d_%H%M%S`")`n" +
    "`tfor _, o in ipairs(old) do o.Parent = backup end`n" +
    "`tbackup.Parent = game:GetService(`"ServerStorage`")`n" +
    "`tprint(`"ℹ Alte UltimatePitch-Objekte gesichert: ServerStorage.`" .. backup.Name)`n" +
    "end`n" +
    "local s = Instance.new(`"Script`") s.Name = `"UltimatePitchServer`" s.Source = [==[$server]==]`n" +
    "local sd = Instance.new(`"ModuleScript`") sd.Name = `"Dome`" sd.Source = [==[$dome]==] sd.Parent = s`n" +
    "local c = Instance.new(`"LocalScript`") c.Name = `"UltimatePitchClient`" c.Source = [==[$client]==]`n" +
    "local ca = Instance.new(`"ModuleScript`") ca.Name = `"AuroraFX`" ca.Source = [==[$aurora]==] ca.Parent = c`n" +
    "s.Parent = SSS`n" +
    "c.Parent = SPS`n" +
    "game:GetService(`"ChangeHistoryService`"):SetWaypoint(`"UltimatePitch v$V`")`n" +
    "print(`"✅ UltimatePitch v$V installiert – Spielen drücken!`")`n"
[IO.File]::WriteAllText((Join-Path $here "UltimatePitch_v${V}_Installer.lua"), $installer, $enc)
"ok"
