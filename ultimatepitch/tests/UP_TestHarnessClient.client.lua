-- UltimatePitch Test-Harness (Client). Wird nur aktiv, wenn der Server-Harness UP_Test anlegt.
-- Nicht Teil von build.py: bei Bedarf nach StarterPlayerScripts kopieren.
local RS = game:GetService("ReplicatedStorage")
-- Ohne Zeitlimit warten (Test-Clients brauchen teils >90 s zum Laden), ohne Infinite-Yield-Warnung
local folder = RS:FindFirstChild("UP_Test")
while not folder do
	local c = RS.ChildAdded:Wait()
	if c.Name == "UP_Test" then folder = c end
end
print("[UP_TEST] Client-Harness aktiv: " .. game:GetService("Players").LocalPlayer.Name)

local STS = game:GetService("StudioTestService")
local me = game:GetService("Players").LocalPlayer
local report = folder:WaitForChild("Report")
local Kick = RS:WaitForChild("UltimatePitch"):WaitForChild("Kick")

folder:GetAttributeChangedSignal("Step"):Connect(function()
	local step = folder:GetAttribute("Step")
	if step == "ball" then
		report:FireServer("ball", workspace.UltimatePitch.Ball.Position)
		local hud = me.PlayerGui:FindFirstChild("UltimatePitchHUD")
		local txt = {}
		if hud then
			for _, d in ipairs(hud:GetDescendants()) do
				if d:IsA("TextLabel") and d.Text ~= "" then table.insert(txt, d.Text) end
			end
		end
		report:FireServer("hud", hud and table.concat(txt, " | ") or "KEIN HUD")
	elseif step and step:sub(1, 4) == "kick" and folder:GetAttribute("Kicker") == me.Name then
		task.wait(0.3)
		Kick:FireServer("Shot", 0.5)
	elseif step == "leave" and folder:GetAttribute("Leaver") == me.Name then
		if STS:CanLeaveTest() then STS:LeaveTest() end
	end
end)
report:FireServer("ready", true)
