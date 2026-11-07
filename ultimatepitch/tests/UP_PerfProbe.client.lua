-- UltimatePitch v0.4 · Performance-Sonde für den Roblox Player (nur Test-Place, nicht Teil des Builds).
-- Misst 5 s nach Anpfiff 60 s lang Framezeit, Render-CPU/GPU, Dreiecke und Draw Calls im echten Spiel und
-- zeigt das Ergebnis oben links an (für Screenshot/Protokoll). Taste P startet eine weitere 60-s-Messung.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local State = RS:WaitForChild("UltimatePitch"):WaitForChild("State")
local gui = Instance.new("ScreenGui")
gui.Name = "UP_PerfProbe"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Position = UDim2.fromOffset(8, 60)
label.Size = UDim2.fromOffset(560, 150)
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.BackgroundTransparency = 0.35
label.TextColor3 = Color3.fromRGB(120, 255, 170)
label.Font = Enum.Font.Code
label.TextSize = 15
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Text = "PerfProbe: wartet auf Anpfiff …"
label.Parent = gui

local function q(t, p)
	local c = table.clone(t)
	table.sort(c)
	return c[math.max(1, math.ceil(#c * p))]
end
local function avg(t)
	local s = 0
	for _, v in ipairs(t) do s += v end
	return s / math.max(1, #t)
end

local running = false
local function measure(seconds)
	if running then return end
	running = true
	local focusLost = 0
	local fc = UIS.WindowFocusReleased:Connect(function() focusLost += 1 end)
	local dt, cpu, gpu, tri, dc = {}, {}, {}, {}, {}
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function(d)
		dt[#dt + 1] = d * 1000
		cpu[#cpu + 1] = Stats.RenderCPUFrameTime * 1000
		gpu[#gpu + 1] = Stats.RenderGPUFrameTime * 1000
		tri[#tri + 1] = Stats.SceneTriangleCount
		dc[#dc + 1] = Stats.SceneDrawcallCount
		label.Text = string.format("PerfProbe: misst … %d/%d s", math.floor(os.clock() - t0), seconds)
	end)
	task.wait(seconds)
	conn:Disconnect()
	fc:Disconnect()
	local cam = workspace.CurrentCamera
	label.Text = string.format(
		"PerfProbe Roblox Player · %d s · %d Frames · Fokusverlust %d\nFPS Ø %.1f | Framezeit Ø %.1f  P50 %.1f  P95 %.1f  P99 %.1f  Max %.1f ms\nRender-CPU Ø %.1f  P95 %.1f ms | Render-GPU Ø %.1f  P95 %.1f ms\nDreiecke Ø %.0fk | Draw Calls Ø %.0f | Speicher %.0f MB\nViewport %dx%d | Qualität %s",
		seconds, #dt, focusLost, #dt / seconds, avg(dt), q(dt, 0.5), q(dt, 0.95), q(dt, 0.99), q(dt, 1),
		avg(cpu), q(cpu, 0.95), avg(gpu), q(gpu, 0.95), avg(tri) / 1000, avg(dc), Stats:GetTotalMemoryUsageMb(),
		math.floor(cam.ViewportSize.X), math.floor(cam.ViewportSize.Y), tostring(UserSettings().GameSettings.SavedQualityLevel))
	running = false
end

task.spawn(function()
	while State:GetAttribute("Phase") ~= "Playing" do State:GetAttributeChangedSignal("Phase"):Wait() end
	task.wait(5)
	measure(60)
end)
UIS.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then task.spawn(measure, 60) end
end)
