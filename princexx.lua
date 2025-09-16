-- PrinceX Hub Warp Pro (FINAL V5)
-- Modern UI + Warp List + Speed Buttons + Server Hop + Toggle GUI

if getgenv().PrinceXHubWarpLoaded then return end
getgenv().PrinceXHubWarpLoaded = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- Config
local warps, selectedWarp, traveling, travelThread = {}, nil, false, nil
local speedValue, modes, modeIndex = 1.0, {"Teleport","Fly","Swim","FakeLag"}, 1
local saveFile = "PrinceX_Warps.json"

-- File IO check
local canWrite = (type(writefile) == "function")
local canRead = (type(readfile) == "function") and (type(isfile) == "function") and isfile

-- Auto FPS unlock
pcall(function()
    if setfpscap then setfpscap(240) end
    if set_fps_cap then set_fps_cap(240) end
end)

-- Helpers
local function getHumanoidAndRoot()
    local char = player.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

-- Save / Load
local function saveWarps()
    if not canWrite then return false end
    local list = {}
    for _,cf in ipairs(warps) do
        table.insert(list, {x=cf.X, y=cf.Y, z=cf.Z})
    end
    pcall(function() writefile(saveFile, HttpService:JSONEncode(list)) end)
    return true
end
local function loadWarps()
    if not canRead or not isfile(saveFile) then return false end
    local ok, raw = pcall(function() return readfile(saveFile) end)
    if not ok then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 then return false end
    warps = {}
    for _,e in ipairs(data) do
        if e.x and e.y and e.z then table.insert(warps, CFrame.new(e.x,e.y,e.z)) end
    end
    return true
end

-- Fade teleport
local function fadeScreen(duration, fadeOut)
    duration = duration or 0.15
    local gui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",5)
    if not gui then return end
    local name = "PX_FadeOverlay"
    local overlay = gui:FindFirstChild(name)
    if not overlay then
        overlay = Instance.new("ScreenGui")
        overlay.Name = name
        overlay.ResetOnSpawn = false
        overlay.Parent = gui
        local f = Instance.new("Frame", overlay)
        f.Name = "F"
        f.Size = UDim2.new(1,0,1,0)
        f.BackgroundColor3 = Color3.new(0,0,0)
        f.BackgroundTransparency = 1
    end
    local frame = overlay:FindFirstChild("F")
    if not frame then return end
    local steps = 8
    if fadeOut then
        for i = 1, steps do
            frame.BackgroundTransparency = 1 - (i/steps)
            task.wait(duration/steps)
        end
    else
        for i = 1, steps do
            frame.BackgroundTransparency = (i/steps)
            task.wait(duration/steps)
        end
        frame.BackgroundTransparency = 1
    end
end

-- ===== Movement =====
local function teleportTo(cf)
    fadeScreen(0.12, true)
    local _, root = getHumanoidAndRoot()
    if root then root.CFrame = cf end
    fadeScreen(0.12, false)
    task.wait(math.clamp(1 / math.max(0.001, speedValue), 0.05, 2))
end

-- Noclip
local noclip = false
RunService.Stepped:Connect(function()
    if noclip and player.Character then
        for _,v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- Fly
local function flyTo(cf)
    local _, root = getHumanoidAndRoot()
    if not root then return end
    noclip = true
    local target = cf.Position
    local speed = speedValue * 40
    while traveling and root and (root.Position - target).Magnitude > 3 do
        local dir = (target - root.Position)
        root.CFrame = root.CFrame + dir.Unit * math.clamp(speed * RunService.Heartbeat:Wait(), 0, dir.Magnitude)
    end
    noclip = false
end

-- Swim
local function swimTo(cf)
    local _, root = getHumanoidAndRoot()
    if not root then return end
    noclip = true
    local target = cf.Position
    local speed = speedValue * 25
    while traveling and root and (root.Position - target).Magnitude > 3 do
        local dir = (target - root.Position)
        root.CFrame = root.CFrame + dir.Unit * math.clamp(speed * RunService.Heartbeat:Wait(), 0, dir.Magnitude)
    end
    noclip = false
end

-- Fake lag (freeze + snap)
local function fakeLagTo(cf)
    local _, root = getHumanoidAndRoot()
    if not root then return end

    -- Freeze dulu
    local freezeTime = math.random(1,3) * 0.5 -- antara 0.5 - 1.5 detik
    local oldCFrame = root.CFrame
    traveling = true

    local start = tick()
    while tick() - start < freezeTime do
        if not traveling then return end
        root.CFrame = oldCFrame
        task.wait()
    end

    -- Snap ke tujuan
    root.CFrame = cf
end

-- Main travel
local function goToWarp(idx)
    if not warps[idx] then return end
    if modes[modeIndex] == "Teleport" then
        teleportTo(warps[idx])
    elseif modes[modeIndex] == "Fly" then
        flyTo(warps[idx])
    elseif modes[modeIndex] == "Swim" then
        swimTo(warps[idx])
    else
        fakeLagTo(warps[idx])
    end
end

-- ===== UI =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PX_WarpUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 500, 0, 350)
Main.Position = UDim2.new(0.3, 0, 0.3, 0)
Main.BackgroundColor3 = Color3.fromRGB(25,25,35)
Main.Active = true
Main.Draggable = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,10)

-- Toggle GUI (press G)
local guiVisible = true
UserInputService.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.G then
        guiVisible = not guiVisible
        Main.Visible = guiVisible
    end
end)

-- Header
local Header = Instance.new("TextLabel", Main)
Header.Size = UDim2.new(1,0,0,35)
Header.BackgroundColor3 = Color3.fromRGB(45,45,70)
Header.Text = "PrinceX Warp Hub 🚀"
Header.TextColor3 = Color3.new(1,1,1)
Header.Font = Enum.Font.GothamBold
Header.TextSize = 18
Instance.new("UICorner", Header).CornerRadius = UDim.new(0,10)

-- Minimize button
local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0,35,1,0)
MinBtn.Position = UDim2.new(1,-70,0,0)
MinBtn.Text = "-"
MinBtn.BackgroundColor3 = Color3.fromRGB(70,70,100)
MinBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,8)

-- Close button
local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0,35,1,0)
CloseBtn.Position = UDim2.new(1,-35,0,0)
CloseBtn.Text = "X"
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,60,60)
CloseBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,8)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    getgenv().PrinceXHubWarpLoaded = false
end)

-- Left Content (Buttons)
local LeftContent = Instance.new("Frame", Main)
LeftContent.Size = UDim2.new(0.6,-5,1,-40)
LeftContent.Position = UDim2.new(0,5,0,40)
LeftContent.BackgroundTransparency = 1

local grid = Instance.new("UIGridLayout", LeftContent)
grid.CellSize = UDim2.new(0.5,-6,0,35)
grid.CellPadding = UDim2.new(0,6,0,6)

-- Warp List Panel
local WarpListPanel = Instance.new("Frame", Main)
WarpListPanel.Size = UDim2.new(0.38,0,1,-100)
WarpListPanel.Position = UDim2.new(0.61,0,0,40)
WarpListPanel.BackgroundColor3 = Color3.fromRGB(30,30,45)
Instance.new("UICorner", WarpListPanel).CornerRadius = UDim.new(0,8)

local Scroll = Instance.new("ScrollingFrame", WarpListPanel)
Scroll.Size = UDim2.new(1,0,1,0)
Scroll.ScrollBarThickness = 6
Scroll.BackgroundTransparency = 1
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local listLayout = Instance.new("UIListLayout", Scroll)
listLayout.Padding = UDim.new(0,6)

-- Refresh Warp List
local function refreshWarpList()
    Scroll:ClearAllChildren()
    listLayout = Instance.new("UIListLayout", Scroll)
    listLayout.Padding = UDim.new(0,6)
    for i, cf in ipairs(warps) do
        local item = Instance.new("Frame", Scroll)
        item.Size = UDim2.new(1,-6,0,28)
        item.BackgroundColor3 = Color3.fromRGB(50,70,100)
        Instance.new("UICorner", item).CornerRadius = UDim.new(0,6)

        local btn = Instance.new("TextButton", item)
        btn.Size = UDim2.new(0.8,0,1,0)
        btn.BackgroundTransparency = 1
        btn.Text = "Warp "..i
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(230,230,230)
        btn.MouseButton1Click:Connect(function()
            selectedWarp = i
            goToWarp(i)
        end)

        local del = Instance.new("TextButton", item)
        del.Size = UDim2.new(0.2,0,1,0)
        del.Position = UDim2.new(0.8,0,0,0)
        del.Text = "❌"
        del.Font = Enum.Font.GothamBold
        del.TextSize = 12
        del.BackgroundColor3 = Color3.fromRGB(180,60,60)
        del.TextColor3 = Color3.fromRGB(255,255,255)
        Instance.new("UICorner", del).CornerRadius = UDim.new(0,6)
        del.MouseButton1Click:Connect(function()
            table.remove(warps, i)
            saveWarps()
            refreshWarpList()
        end)
    end
end

-- Buttons
local function makeBtn(txt,cb)
    local b = Instance.new("TextButton", LeftContent)
    b.Text = txt
    b.BackgroundColor3 = Color3.fromRGB(60,60,80)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    b.MouseButton1Click:Connect(cb)
    return b
end

makeBtn("➕ Add Warp", function()
    local _, root = getHumanoidAndRoot()
    if root then
        table.insert(warps, root.CFrame)
        selectedWarp = #warps
        saveWarps()
        refreshWarpList()
    end
end)

makeBtn("▶ Auto Travel", function()
    if traveling then traveling=false return end
    traveling=true
    travelThread = task.spawn(function()
        for i=1,#warps do
            if not traveling then break end
            selectedWarp=i
            goToWarp(i)
        end
        traveling=false
        StarterGui:SetCore("SendNotification",{Title="Warp Finished",Text="Semua warp selesai ✅",Duration=3})
    end)
end)

makeBtn("⏹ Stop", function() traveling=false end)
makeBtn("💾 Save", function() saveWarps() end)
makeBtn("📂 Load", function() loadWarps() refreshWarpList() end)
makeBtn("🗑 Clear", function() warps={} saveWarps() refreshWarpList() end)

makeBtn("🎮 Mode", function()
    modeIndex = (modeIndex % #modes)+1
    StarterGui:SetCore("SendNotification",{Title="Mode",Text="Now: "..modes[modeIndex],Duration=2})
end)

-- Server Hop
makeBtn("🌐 Server Hop", function()
    local placeId = game.PlaceId
    local lowestServer, lowestCount = nil, math.huge
    local cursor = ""
    repeat
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(
                ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s"):format(placeId, cursor)
            ))
        end)
        if success and result and result.data then
            for _,srv in ipairs(result.data) do
                local count = srv.playing
                if count > 0 and count < lowestCount and count < srv.maxPlayers then
                    lowestCount = count
                    lowestServer = srv
                end
            end
            cursor = result.nextPageCursor or ""
        else
            break
        end
    until cursor == "" or not lowestServer
    if lowestServer then
        StarterGui:SetCore("SendNotification",{Title="Server Hop",Text="Pindah ke server "..lowestCount.." player",Duration=3})
        TeleportService:TeleportToPlaceInstance(placeId, lowestServer.id, player)
    else
        StarterGui:SetCore("SendNotification",{Title="Server Hop",Text="Gagal cari server",Duration=3})
    end
end)

-- Speed Panel
local SpeedPanel = Instance.new("Frame", Main)
SpeedPanel.Size = UDim2.new(0.6,-10,0,60)
SpeedPanel.Position = UDim2.new(0,5,1,-65)
SpeedPanel.BackgroundColor3 = Color3.fromRGB(35,35,50)
Instance.new("UICorner", SpeedPanel).CornerRadius = UDim.new(0,8)

local speedLabel = Instance.new("TextLabel", SpeedPanel)
speedLabel.Size = UDim2.new(1,0,0.5,0)
speedLabel.Text = "🚀 Speed: "..tostring(speedValue)
speedLabel.TextColor3 = Color3.new(1,1,1)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.GothamSemibold
speedLabel.TextSize = 14

local minusBtn = Instance.new("TextButton", SpeedPanel)
minusBtn.Size = UDim2.new(0.3,-10,0.4,0)
minusBtn.Position = UDim2.new(0.05,0,0.55,0)
minusBtn.Text = "➖"
minusBtn.Font = Enum.Font.GothamBold
minusBtn.TextSize = 18
minusBtn.TextColor3 = Color3.new(1,1,1)
minusBtn.BackgroundColor3 = Color3.fromRGB(200,80,80)
Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0,8)

local plusBtn = Instance.new("TextButton", SpeedPanel)
plusBtn.Size = UDim2.new(0.3,-10,0.4,0)
plusBtn.Position = UDim2.new(0.65,0,0.55,0)
plusBtn.Text = "➕"
plusBtn.Font = Enum.Font.GothamBold
plusBtn.TextSize = 18
plusBtn.TextColor3 = Color3.new(1,1,1)
plusBtn.BackgroundColor3 = Color3.fromRGB(80,200,120)
Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0,8)

local function updateSpeedLabel()
    speedLabel.Text = "🚀 Speed: "..tostring(speedValue)
end
minusBtn.MouseButton1Click:Connect(function()
    speedValue = math.max(0.5, speedValue - 0.5)
    updateSpeedLabel()
end)
plusBtn.MouseButton1Click:Connect(function()
    speedValue = math.min(10, speedValue + 0.5)
    updateSpeedLabel()
end)

-- Minimize logic
local minimized=false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    LeftContent.Visible = not minimized
    WarpListPanel.Visible = not minimized
    SpeedPanel.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- Load saved warps
loadWarps()
refreshWarpList()

-- Done
StarterGui:SetCore("SendNotification",{Title="Warp Hub",Text="Loaded ✅ (Press G to toggle GUI)",Duration=4})
