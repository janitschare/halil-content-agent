-- UltimatePitch v0.5 · KickAnim-Sonde je Client (nur Test-Place, nicht Teil des Builds).
-- Zählt auf diesem Client alle "KickAnim"-Ereignisse, misst den maximalen Hüftwinkel der Figur in den
-- 0,35 s danach (sichtbare Schussbewegung) und unterscheidet Bots, eigene Figur und andere Spieler.
-- Der vom Harness bestimmte "Passer" spielt bei Ball vor den Füßen selbst einen echten Pass (Kick-Remote).
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local folder = RS:WaitForChild("UP_Sec", 600)
if not folder then return end
local report = folder:WaitForChild("Report")
-- Diagnose-Zwischenstände: start (Skript läuft), req (Module geladen), go (Startsignal empfangen), err (Client-Fehler)
report:FireServer("start", "ok")
game:GetService("ScriptContext").Error:Connect(function(m, t)
	report:FireServer("err", tostring(m):sub(1, 200) .. " | " .. tostring(t):sub(1, 200))
end)
local shared = RS:WaitForChild("UltimatePitch")
local Effect = shared:WaitForChild("Effect")
local Kick = shared:WaitForChild("Kick")
local me = Players.LocalPlayer
local AuroraFX = require(me:WaitForChild("PlayerScripts"):WaitForChild("UltimatePitchClient"):WaitForChild("AuroraFX"))

report:FireServer("req", "ok")
while not folder:GetAttribute("Start") do folder:GetAttributeChangedSignal("Start"):Wait() end
report:FireServer("go", tostring(folder:GetAttribute("Passer")) .. "/" .. me.Name)

local stats = { total = 0, animated = 0, bots = 0, own = 0, other = 0, otherAnimated = 0, errors = 0 }
local function angle(cf)
	local x, y, z = cf:ToEulerAnglesXYZ()
	return math.max(math.abs(x), math.abs(y), math.abs(z))
end

local conn = Effect.OnClientEvent:Connect(function(kind, _, arg)
	if kind ~= "KickAnim" then return end
	if typeof(arg) ~= "Instance" or not arg:IsA("Model") then stats.errors += 1 return end
	stats.total += 1
	local plr = Players:GetPlayerFromCharacter(arg)
	local isOther = plr and plr ~= me
	if not plr then stats.bots += 1 elseif plr == me then stats.own += 1 else stats.other += 1 end
	local hip = AuroraFX.joint(arg, "RightUpperLeg", "RightHip")
	if not hip then return end
	local maxA, t0 = 0, os.clock()
	local c
	c = RunService.PostSimulation:Connect(function()
		maxA = math.max(maxA, angle(hip.Transform))
		if os.clock() - t0 > 0.35 then
			c:Disconnect()
			if maxA > 0.3 then
				stats.animated += 1
				if isOther then stats.otherAnimated += 1 end
			end
		end
	end)
end)

-- Passer: Ball vor den Füßen -> echter Pass über das RemoteEvent (wie ein Spieler mit Taste E)
if folder:GetAttribute("Passer") == me.Name then
	task.spawn(function()
		local ball = workspace:WaitForChild("UltimatePitch"):WaitForChild("Ball")
		local lastPass = 0
		while not folder:GetAttribute("Stop") do
			local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
			if root and os.clock() - lastPass > 0.5 then
				local d = ball.Position - root.Position
				if Vector3.new(d.X, 0, d.Z).Magnitude < 6 then -- Reichweite prüft ohnehin der Server
					Kick:FireServer("Pass")
					lastPass = os.clock()
				end
			end
			task.wait(0.1)
		end
	end)
end

while not folder:GetAttribute("Stop") do folder:GetAttributeChangedSignal("Stop"):Wait() end
task.wait(0.5)
conn:Disconnect()
report:FireServer("kick", string.format("events=%d animiert=%d bots=%d eigen=%d anderer=%d anderer_animiert=%d fehler=%d",
	stats.total, stats.animated, stats.bots, stats.own, stats.other, stats.otherAnimated, stats.errors))
