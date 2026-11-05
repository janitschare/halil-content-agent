"""Baut aus src/ die Place-Datei (.rbxlx) und den Command-Bar-Installer."""
from pathlib import Path

V = "0.4"
here = Path(__file__).parent
server = (here / "src/Server.server.lua").read_text()
client = (here / "src/Client.client.lua").read_text()
for src in (server, client):
    assert "]]>" not in src and "]==]" not in src


def script(cls, ref, name, src):
    return (f'<Item class="{cls}" referent="{ref}"><Properties>'
            f'<string name="Name">{name}</string><bool name="Disabled">false</bool>'
            f'<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>'
            f'</Properties></Item>')


rbxlx = f'''<roblox version="4">
<Item class="Workspace" referent="RBX0"><Properties><string name="Name">Workspace</string></Properties></Item>
<Item class="ServerScriptService" referent="RBX1"><Properties><string name="Name">ServerScriptService</string></Properties>
{script("Script", "RBX2", "UltimatePitchServer", server)}
</Item>
<Item class="StarterPlayer" referent="RBX3"><Properties><string name="Name">StarterPlayer</string></Properties>
<Item class="StarterPlayerScripts" referent="RBX4"><Properties><string name="Name">StarterPlayerScripts</string></Properties>
{script("LocalScript", "RBX5", "UltimatePitchClient", client)}
</Item></Item>
</roblox>
'''
(here / f"UltimatePitch_v{V}.rbxlx").write_text(rbxlx)

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
local s = Instance.new("Script") s.Name = "UltimatePitchServer" s.Source = [==[{server}]==] s.Parent = SSS
local c = Instance.new("LocalScript") c.Name = "UltimatePitchClient" c.Source = [==[{client}]==] c.Parent = SPS
game:GetService("ChangeHistoryService"):SetWaypoint("UltimatePitch v{V}")
print("✅ UltimatePitch v{V} installiert – Spielen drücken!")
'''
(here / f"UltimatePitch_v{V}_Installer.lua").write_text(installer)
print("ok")
