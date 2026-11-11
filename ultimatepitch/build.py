"""Baut aus src/ die Place-Datei (.rbxlx) und den Command-Bar-Installer.

Server-Script mit Kind-Modulen Dome, City, Career, CareerStore und CityLook, Client-LocalScript mit Kind-Modulen AuroraFX, Matchday, CareerUI und CityFX.
build.ps1 ist das PowerShell-Gegenstück und erzeugt dieselben Dateien.
"""
from pathlib import Path

V = "0.5"
here = Path(__file__).parent


def src(name):
    text = (here / "src" / name).read_text(encoding="utf-8").replace("\r\n", "\n")
    assert "]]>" not in text and "]==]" not in text, name
    return text


server = src("Server.server.lua")
client = src("Client.client.lua")
dome = src("Dome.lua")
city = src("City.lua")
aurora = src("AuroraFX.lua")
matchday = src("Matchday.lua")
career = src("Career.lua")
career_store = src("CareerStore.lua")
city_look = src("CityLook.lua")
city_fx = src("CityFX.lua")
career_ui = src("CareerUI.lua")


def item(cls, ref, name, source, children=""):
    disabled = "" if cls == "ModuleScript" else '<bool name="Disabled">false</bool>'
    return (f'<Item class="{cls}" referent="{ref}"><Properties>'
            f'<string name="Name">{name}</string>{disabled}'
            f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
            f'</Properties>{children}</Item>')


rbxlx = f'''<roblox version="4">
<Item class="Workspace" referent="RBX0"><Properties><string name="Name">Workspace</string></Properties></Item>
<Item class="Lighting" referent="RBX8"><Properties><string name="Name">Lighting</string><token name="LightingStyle">0</token><bool name="PrioritizeLightingQuality">false</bool></Properties></Item>
<Item class="ServerScriptService" referent="RBX1"><Properties><string name="Name">ServerScriptService</string></Properties>
{item("Script", "RBX2", "UltimatePitchServer", server, item("ModuleScript", "RBX6", "Dome", dome) + item("ModuleScript", "RBX10", "City", city) + item("ModuleScript", "RBX11", "Career", career) + item("ModuleScript", "RBX13", "CareerStore", career_store) + item("ModuleScript", "RBX14", "CityLook", city_look))}
</Item>
<Item class="StarterPlayer" referent="RBX3"><Properties><string name="Name">StarterPlayer</string></Properties>
<Item class="StarterPlayerScripts" referent="RBX4"><Properties><string name="Name">StarterPlayerScripts</string></Properties>
{item("LocalScript", "RBX5", "UltimatePitchClient", client, item("ModuleScript", "RBX7", "AuroraFX", aurora) + item("ModuleScript", "RBX9", "Matchday", matchday) + item("ModuleScript", "RBX12", "CareerUI", career_ui) + item("ModuleScript", "RBX15", "CityFX", city_fx))}
</Item></Item>
</roblox>
'''
(here / f"UltimatePitch_v{V}.rbxlx").write_text(rbxlx, encoding="utf-8", newline="\n")

installer = f'''-- UltimatePitch v{V} – Command-Bar-Installer (Alternative zur .rbxlx)
-- Test vorher stoppen! Einfügen, Enter, dann Spielen. Die Welt baut sich beim Start.
if game:GetService("RunService"):IsRunning() then
	error("❌ Erst Test stoppen (rotes Quadrat), dann erneut ausführen!")
end
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
-- Schutz: Der Installer löscht nichts. Vorhandene UltimatePitch-Objekte werden nur nach ausdrücklicher
-- Bestätigung (_G.UP_REPLACE = true) ersetzt und vorher nach ServerStorage verschoben (Rückgängig: Strg+Z).
local old = {{}}
for _, o in pairs({{ SSS:FindFirstChild("UltimatePitchServer"), SPS:FindFirstChild("UltimatePitchClient"),
	workspace:FindFirstChild("UltimatePitch"), game:GetService("ReplicatedStorage"):FindFirstChild("UltimatePitch") }}) do
	table.insert(old, o)
end
if #old > 0 and _G.UP_REPLACE ~= true then
	local names = {{}}
	for _, o in ipairs(old) do table.insert(names, o:GetFullName()) end
	error("⚠ Nichts verändert: vorhandene UltimatePitch-Objekte gefunden (" .. table.concat(names, ", ") .. "). " ..
		"Zum Ersetzen zuerst  _G.UP_REPLACE = true  ausführen, dann den Installer erneut. Alte Objekte werden nach ServerStorage gesichert.")
end
_G.UP_REPLACE = nil
game:GetService("ChangeHistoryService"):SetWaypoint("Vor UltimatePitch v{V}")
if #old > 0 then
	local backup = Instance.new("Folder")
	backup.Name = "UP_Backup_" .. os.date("%Y%m%d_%H%M%S")
	for _, o in ipairs(old) do o.Parent = backup end
	backup.Parent = game:GetService("ServerStorage")
	print("ℹ Alte UltimatePitch-Objekte gesichert: ServerStorage." .. backup.Name)
end
local s = Instance.new("Script") s.Name = "UltimatePitchServer" s.Source = [==[{server}]==]
local sd = Instance.new("ModuleScript") sd.Name = "Dome" sd.Source = [==[{dome}]==] sd.Parent = s
local sc = Instance.new("ModuleScript") sc.Name = "City" sc.Source = [==[{city}]==] sc.Parent = s
local sk = Instance.new("ModuleScript") sk.Name = "Career" sk.Source = [==[{career}]==] sk.Parent = s
local sp = Instance.new("ModuleScript") sp.Name = "CareerStore" sp.Source = [==[{career_store}]==] sp.Parent = s
local sl = Instance.new("ModuleScript") sl.Name = "CityLook" sl.Source = [==[{city_look}]==] sl.Parent = s
local c = Instance.new("LocalScript") c.Name = "UltimatePitchClient" c.Source = [==[{client}]==]
local ca = Instance.new("ModuleScript") ca.Name = "AuroraFX" ca.Source = [==[{aurora}]==] ca.Parent = c
local cm = Instance.new("ModuleScript") cm.Name = "Matchday" cm.Source = [==[{matchday}]==] cm.Parent = c
local ck = Instance.new("ModuleScript") ck.Name = "CareerUI" ck.Source = [==[{career_ui}]==] ck.Parent = c
local cf = Instance.new("ModuleScript") cf.Name = "CityFX" cf.Source = [==[{city_fx}]==] cf.Parent = c
s.Parent = SSS
c.Parent = SPS
game:GetService("ChangeHistoryService"):SetWaypoint("UltimatePitch v{V}")
print("✅ UltimatePitch v{V} installiert – Spielen drücken!")
'''
(here / f"UltimatePitch_v{V}_Installer.lua").write_text(installer, encoding="utf-8", newline="\n")
print("ok")
