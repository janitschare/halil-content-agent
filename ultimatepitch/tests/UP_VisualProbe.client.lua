-- UltimatePitch v0.4 Sichtprüfung je Client (nur für Testläufe, nicht Teil des Builds).
-- Misst auf jedem Client selbst, was AURORA BREAK und das GOAL-Cinematic dort anzeigen, und meldet es
-- über ReplicatedStorage.UP_Sec.Report an den Server (der MCP erreicht Client-Datenmodelle nicht immer).
--   vis_kick: Kick-Animation am Schützen (max. Hüftwinkel), FOV vorher/max/danach, FX-Objekte währenddessen/danach
--   vis_goal: Banner + Untertitel + Farbkorrektur 0,3 s nach dem Tor, Rückstände 2,0 s danach
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local folder = RS:WaitForChild("UP_Sec", 600)
if not folder then return end
local report = folder:WaitForChild("Report")
local shared = RS:WaitForChild("UltimatePitch")
local State = shared:WaitForChild("State")
local Effect = shared:WaitForChild("Effect")
local me = Players.LocalPlayer
local AuroraFX = require(me:WaitForChild("PlayerScripts"):WaitForChild("UltimatePitchClient"):WaitForChild("AuroraFX"))

local function fxCount()
	local f = workspace:FindFirstChild("UP_LocalFX")
	return f and #f:GetChildren() or 0
end

local function angle(cf)
	local x, y, z = cf:ToEulerAnglesXYZ()
	return math.max(math.abs(x), math.abs(y), math.abs(z))
end

Effect.OnClientEvent:Connect(function(kind, userId)
	if kind ~= "AuroraWindup" then return end
	local plr = Players:GetPlayerByUserId(userId)
	local char = plr and plr.Character
	if not char then return end
	local hip = AuroraFX.joint(char, "RightUpperLeg", "RightHip")
	local cam = workspace.CurrentCamera
	local fovBase = cam.FieldOfView
	local hipMax, fovMax, fxMax = 0, fovBase, 0
	local conn = RunService.PostSimulation:Connect(function()
		if hip then hipMax = math.max(hipMax, angle(hip.Transform)) end
		fovMax = math.max(fovMax, cam.FieldOfView)
		fxMax = math.max(fxMax, fxCount())
	end)
	task.wait(1.6)
	conn:Disconnect()
	task.wait(0.4)
	report:FireServer("vis_kick", ("schuetze=%s eigen=%s gelenk=%s hipMax=%.2f fov=%.1f/%.1f/%.1f fx_max=%d fx_danach=%d")
		:format(plr.Name, tostring(plr == me), hip and hip.ClassName or "keins", hipMax, fovBase, fovMax, cam.FieldOfView, fxMax, fxCount()))
end)

State:GetAttributeChangedSignal("GoalSeq"):Connect(function()
	task.wait(0.3)
	local gui = me:FindFirstChildOfClass("PlayerGui")
	local banner, sub = nil, ""
	for _, d in ipairs(gui:GetDescendants()) do
		if d.Name == "GoalBanner" then banner = d end
	end
	if banner then
		for _, l in ipairs(banner:GetChildren()) do
			if l:IsA("TextLabel") and l.Text ~= "GOAL!" then sub = l.Text end
		end
	end
	local grade = game:GetService("Lighting"):FindFirstChild("UP_GoalGrade") ~= nil
	local width = banner and banner.AbsoluteSize.X or 0
	task.wait(1.7)
	local left = 0
	for _, d in ipairs(gui:GetDescendants()) do
		if d.Name == "GoalBanner" then left += 1 end
	end
	report:FireServer("vis_goal", ("banner=%s breite=%d untertitel=%q grade=%s | nach2s: banner=%d grade=%s fx=%d fov=%.1f")
		:format(tostring(banner ~= nil), width, sub, tostring(grade), left,
			tostring(game:GetService("Lighting"):FindFirstChild("UP_GoalGrade") ~= nil), fxCount(), workspace.CurrentCamera.FieldOfView))
end)
