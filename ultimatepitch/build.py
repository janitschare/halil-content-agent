"""Baut aus src/ die Place-Datei (.rbxlx) und den Command-Bar-Installer.

Server-Script mit Kind-Modul Dome, Client-LocalScript mit Kind-Modul AuroraFX.
build.ps1 ist das PowerShell-Gegenstück und erzeugt dieselben Dateien.
"""
from pathlib import Path

V = "0.4"
here = Path(__file__).parent


def src(name):
    text = (here / "src" / name).read_text(encoding="utf-8").replace("\r\n", "\n")
    assert "]]>" not in text and "]==]" not in text, name
    return text


server = src("Server.server.lua")
client = src("Client.client.lua")
dome = src("Dome.lua")
aurora = src("AuroraFX.lua")


def item(cls, ref, name, source, children=""):
    disabled = "" if cls == "ModuleScript" else '<bool name="Disabled">false</bool>'
    return (f'<Item class="{cls}" referent="{ref}"><Properties>'
            f'<string name="Name">{name}</string>{disabled}'
            f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
            f'</Properties>{children}</Item>')


rbxlx = f'''<roblox version="4">
<Item class="Workspace" referent="RBX0"><Properties><string name="Name">Workspace</string></Properties></Item>
<Item class="ServerScriptService" referent="RBX1"><Properties><string name="Name">ServerScriptService</string></Properties>
{item("Script", "RBX2", "UltimatePitchServer", server, item("ModuleScript", "RBX6", "Dome", dome))}
</Item>
<Item class="StarterPlayer" referent="RBX3"><Properties><string name="Name">StarterPlayer</string></Properties>
<Item class="StarterPlayerScripts" referent="RBX4"><Properties><string name="Name">StarterPlayerScripts</string></Properties>
{item("LocalScript", "RBX5", "UltimatePitchClient", client, item("ModuleScript", "RBX7", "AuroraFX", aurora))}
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
for _, o in pairs({{ SSS:FindFirstChild("UltimatePitchServer"), SPS:FindFirstChild("UltimatePitchClient"),
	workspace:FindFirstChild("UltimatePitch"), game:GetService("ReplicatedStorage"):FindFirstChild("UltimatePitch") }}) do
	if o then o:Destroy() end
end
local s = Instance.new("Script") s.Name = "UltimatePitchServer" s.Source = [==[{server}]==]
local sd = Instance.new("ModuleScript") sd.Name = "Dome" sd.Source = [==[{dome}]==] sd.Parent = s
local c = Instance.new("LocalScript") c.Name = "UltimatePitchClient" c.Source = [==[{client}]==]
local ca = Instance.new("ModuleScript") ca.Name = "AuroraFX" ca.Source = [==[{aurora}]==] ca.Parent = c
s.Parent = SSS
c.Parent = SPS
game:GetService("ChangeHistoryService"):SetWaypoint("UltimatePitch v{V}")
print("✅ UltimatePitch v{V} installiert – Spielen drücken!")
'''
(here / f"UltimatePitch_v{V}_Installer.lua").write_text(installer, encoding="utf-8", newline="\n")
print("ok")
