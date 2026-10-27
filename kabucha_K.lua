-- ================================================================
--   aimbotpc — Kabucha / ปืนพิษ Edition  (PC + GUI)
--   Executor : Synapse X / KRNL / Fluxus / Delta / AWP / Solara
--   ไม่ต้องใช้ keyboard shortcut — ควบคุมทุกอย่างผ่านหน้าต่าง
-- ================================================================

-- ================================================================
--  KEY SYSTEM  — Hardcode key + วันหมดอายุ
--  เพิ่ม/ลบ key: แก้ตารางนี้แล้วแจก script ใหม่
--  Format:  ["KEY-NAME"] = "YYYY-MM-DD"
-- ================================================================
local KEY_LIST = {
    ["KABUCHA-VIP-001"]  = "2026-11-01",   -- 5 วัน
    ["KABUCHA-VIP-002"]  = "2026-11-26",   -- 30 วัน
    ["KABUCHA-TEST-999"] = "2026-10-28",   -- 1 วัน
}

-- แปลง "YYYY-MM-DD" → unix timestamp
local function parseExpiry(s)
    local y, m, d = s:match("(%d+)-(%d+)-(%d+)")
    if not (y and m and d) then return 0 end
    return os.time({year=tonumber(y), month=tonumber(m), day=tonumber(d), hour=23, min=59, sec=59})
end

-- จำนวนวันที่เหลือ (ติดลบ = หมดอายุแล้ว)
local function daysLeft(expiry)
    return math.floor((expiry - os.time()) / 86400)
end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ================================================================
--  COMPAT LAYER
-- ================================================================
local hasDrawing    = (typeof(Drawing) ~= "nil")
local hasGetRawMeta = (typeof(getrawmetatable) == "function")
local hasSetRO      = (typeof(setreadonly) == "function")
local hasMouse1     = (typeof(mouse1click) == "function")
local hasNCC        = (typeof(newcclosure) == "function")

-- ================================================================
--  BONE MAP
-- ================================================================
local BONE = {
    Head             = "Head",
    UpperTorso       = "UpperTorso",
    HumanoidRootPart = "HumanoidRootPart",
}

-- ================================================================
--  CONFIG
-- ================================================================
local Cfg = {
    Enabled       = true,
    AimKey        = Enum.KeyCode.K,
    TargetBone    = BONE.UpperTorso,
    Smoothness    = 0.18,
    FOVRadius     = 320,

    SilentAim     = true,
    Prediction    = true,
    KabuchaSpeed  = 155,
    GravityComp   = true,

    TeamCheck     = false,
    WallCheck     = false,
    AutoShoot     = false,

    ESPEnabled    = true,
    ESPBoxes      = true,
    ESPLines      = false,
    ESPNames      = true,
    ESPHealth     = true,
    ESPDistance   = true,
    ESPColor      = Color3.fromRGB(0, 210, 255),
    ESPColorEnemy = Color3.fromRGB(255, 55, 55),

    ShowFOV       = true,
    FOVColor      = Color3.fromRGB(0, 210, 255),
    FOVThickness  = 1.5,
}

-- ================================================================
--  GUI PARENT HELPER
-- ================================================================
local guiParent = (function()
    local ok, h = pcall(function() return gethui() end)
    if ok and h then return h end
    return game:GetService("CoreGui")
end)()

-- ลบ GUI เก่าถ้ามี (re-execute safe)
pcall(function()
    local old = guiParent:FindFirstChild("aimbotpc_gui")
    if old then old:Destroy() end
end)
pcall(function()
    local old = guiParent:FindFirstChild("kabucha_key_gui")
    if old then old:Destroy() end
end)

-- ================================================================
--  KEY AUTH GUI  — ต้องใส่ key ถูกถึงจะโหลด script หลัก
-- ================================================================
local TweenService_k = game:GetService("TweenService")

local keyGui = Instance.new("ScreenGui")
keyGui.Name           = "kabucha_key_gui"
keyGui.ResetOnSpawn   = false
keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
keyGui.Parent         = guiParent

-- Backdrop blur overlay
local overlay = Instance.new("Frame")
overlay.Size                = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3    = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel     = 0
overlay.ZIndex              = 10
overlay.Parent              = keyGui

-- Card
local card = Instance.new("Frame")
card.Size                = UDim2.new(0, 340, 0, 230)
card.Position            = UDim2.new(0.5, -170, 0.5, -115)
card.BackgroundColor3    = Color3.fromRGB(12, 12, 18)
card.BorderSizePixel     = 0
card.ZIndex              = 20
card.Parent              = keyGui
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius  = UDim.new(0, 14)
cardCorner.Parent        = card
local cardStroke = Instance.new("UIStroke")
cardStroke.Color         = Color3.fromRGB(0, 170, 255)
cardStroke.Thickness     = 1.5
cardStroke.Parent        = card

-- Glow bar top
local glow = Instance.new("Frame")
glow.Size             = UDim2.new(1, 0, 0, 3)
glow.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
glow.BorderSizePixel  = 0
glow.ZIndex           = 21
glow.Parent           = card
local glowGrad = Instance.new("UIGradient")
glowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 80, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 200, 255)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 80, 255)),
})
glowGrad.Parent = glow

-- Icon label
local icon = Instance.new("TextLabel")
icon.Size                  = UDim2.new(1, 0, 0, 36)
icon.Position              = UDim2.new(0, 0, 0, 12)
icon.BackgroundTransparency = 1
icon.Text                  = "🔑  KABUCHA KEY SYSTEM"
icon.TextColor3            = Color3.fromRGB(0, 200, 255)
icon.TextSize              = 15
icon.Font                  = Enum.Font.GothamBold
icon.ZIndex                = 21
icon.Parent                = card

-- Sub label
local sub = Instance.new("TextLabel")
sub.Size                   = UDim2.new(1, 0, 0, 20)
sub.Position               = UDim2.new(0, 0, 0, 48)
sub.BackgroundTransparency = 1
sub.Text                   = "ใส่ key เพื่อใช้งาน script"
sub.TextColor3             = Color3.fromRGB(110, 120, 145)
sub.TextSize               = 12
sub.Font                   = Enum.Font.Gotham
sub.ZIndex                 = 21
sub.Parent                 = card

-- Input box background
local inputBg = Instance.new("Frame")
inputBg.Size             = UDim2.new(0, 290, 0, 40)
inputBg.Position         = UDim2.new(0.5, -145, 0, 82)
inputBg.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
inputBg.BorderSizePixel  = 0
inputBg.ZIndex           = 21
inputBg.Parent           = card
local ibCorner = Instance.new("UICorner")
ibCorner.CornerRadius = UDim.new(0, 8)
ibCorner.Parent       = inputBg
local ibStroke = Instance.new("UIStroke")
ibStroke.Color     = Color3.fromRGB(45, 50, 70)
ibStroke.Thickness = 1.2
ibStroke.Parent    = inputBg

-- TextBox
local keyBox = Instance.new("TextBox")
keyBox.Size                   = UDim2.new(1, -20, 1, 0)
keyBox.Position               = UDim2.new(0, 10, 0, 0)
keyBox.BackgroundTransparency = 1
keyBox.PlaceholderText        = "KABUCHA-XXXX-XXXX"
keyBox.PlaceholderColor3      = Color3.fromRGB(70, 75, 95)
keyBox.Text                   = ""
keyBox.TextColor3             = Color3.fromRGB(220, 225, 240)
keyBox.TextSize               = 14
keyBox.Font                   = Enum.Font.GothamMedium
keyBox.ClearTextOnFocus       = false
keyBox.ZIndex                 = 22
keyBox.Parent                 = inputBg

-- Submit button
local submitBtn = Instance.new("TextButton")
submitBtn.Size             = UDim2.new(0, 290, 0, 38)
submitBtn.Position         = UDim2.new(0.5, -145, 0, 138)
submitBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 230)
submitBtn.Text             = "UNLOCK"
submitBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
submitBtn.TextSize         = 14
submitBtn.Font             = Enum.Font.GothamBold
submitBtn.BorderSizePixel  = 0
submitBtn.ZIndex           = 21
submitBtn.Parent           = card
local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 8)
sbCorner.Parent       = submitBtn

-- Status label (error / ok)
local statusLbl = Instance.new("TextLabel")
statusLbl.Size                   = UDim2.new(1, 0, 0, 22)
statusLbl.Position               = UDim2.new(0, 0, 0, 188)
statusLbl.BackgroundTransparency = 1
statusLbl.Text                   = ""
statusLbl.TextColor3             = Color3.fromRGB(220, 50, 50)
statusLbl.TextSize               = 12
statusLbl.Font                   = Enum.Font.GothamMedium
statusLbl.ZIndex                 = 21
statusLbl.Parent                 = card

-- Hover effect submit button
submitBtn.MouseEnter:Connect(function()
    TweenService_k:Create(submitBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 180, 255)}):Play()
end)
submitBtn.MouseLeave:Connect(function()
    TweenService_k:Create(submitBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(0, 150, 230)}):Play()
end)

-- Shake animation on wrong key
local function shakeCard()
    local origin = card.Position
    local offsets = {8, -8, 6, -6, 4, -4, 2, -2, 0}
    local function step(i)
        if i > #offsets then return end
        card.Position = UDim2.new(origin.X.Scale, origin.X.Offset + offsets[i], origin.Y.Scale, origin.Y.Offset)
        task.delay(0.04, function() step(i+1) end)
    end
    step(1)
end

-- MainLoad — โหลด script หลักเมื่อ key ถูกต้อง
local function MainLoad()
    keyGui:Destroy()

-- ================================================================
--  GUI SETUP
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "aimbotpc_gui"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent          = guiParent

-- ================================================================
--  COLORS / THEME
-- ================================================================
local COL = {
    BG        = Color3.fromRGB(15, 15, 20),
    TopBar    = Color3.fromRGB(20, 20, 28),
    Section   = Color3.fromRGB(22, 22, 32),
    OnGreen   = Color3.fromRGB(0, 200, 100),
    OnBlue    = Color3.fromRGB(0, 170, 255),
    Off       = Color3.fromRGB(55, 55, 65),
    Text      = Color3.fromRGB(220, 220, 230),
    SubText   = Color3.fromRGB(130, 130, 145),
    Accent    = Color3.fromRGB(0, 170, 255),
    Border    = Color3.fromRGB(40, 40, 55),
    Red       = Color3.fromRGB(220, 50, 50),
}

-- ================================================================
--  UI HELPERS
-- ================================================================
local function Make(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function MakeCorner(radius, parent)
    return Make("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function MakeStroke(color, thickness, parent)
    return Make("UIStroke", {Color=color, Thickness=thickness}, parent)
end

local function Tween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- FOV Slider factory
local function MakeFOVSlider(parent, yPos)
    local MIN, MAX = 50, 600
    local row = Make("Frame", {
        Size = UDim2.new(1, -20, 0, 44),
        Position = UDim2.new(0, 10, 0, yPos),
        BackgroundColor3 = COL.Section,
        BorderSizePixel = 0,
    }, parent)
    MakeCorner(6, row)

    Make("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20),
        Position = UDim2.new(0, 10, 0, 2),
        BackgroundTransparency = 1,
        Text = "FOV Radius",
        TextColor3 = COL.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local valLabel = Make("TextLabel", {
        Size = UDim2.new(0.5, -10, 0, 20),
        Position = UDim2.new(0.5, 0, 0, 2),
        BackgroundTransparency = 1,
        Text = tostring(Cfg.FOVRadius),
        TextColor3 = COL.Accent,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    local track = Make("Frame", {
        Size = UDim2.new(1, -20, 0, 6),
        Position = UDim2.new(0, 10, 0, 30),
        BackgroundColor3 = COL.Off,
        BorderSizePixel = 0,
    }, row)
    MakeCorner(3, track)

    local fill = Make("Frame", {
        Size = UDim2.new((Cfg.FOVRadius - MIN) / (MAX - MIN), 0, 1, 0),
        BackgroundColor3 = COL.Accent,
        BorderSizePixel = 0,
    }, track)
    MakeCorner(3, fill)

    local thumb = Make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new((Cfg.FOVRadius - MIN) / (MAX - MIN), -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, track)
    MakeCorner(7, thumb)

    local dragging = false
    local hitbox = Make("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 6,
    }, track)

    local function updateSlider(absX)
        local tAbs = track.AbsolutePosition.X
        local tW   = track.AbsoluteSize.X
        local ratio = math.clamp((absX - tAbs) / tW, 0, 1)
        local val   = math.floor(MIN + ratio * (MAX - MIN))
        Cfg.FOVRadius = val
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, -7, 0.5, -7)
        valLabel.Text = tostring(val)
    end

    hitbox.MouseButton1Down:Connect(function(x, _)
        dragging = true
        updateSlider(x)
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return row
end

-- Toggle button factory
local function MakeToggle(parent, label, yPos, cfgKey, color)
    color = color or COL.OnGreen
    local row = Make("Frame", {
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, yPos),
        BackgroundColor3 = COL.Section,
        BorderSizePixel = 0,
    }, parent)
    MakeCorner(6, row)

    Make("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = COL.Text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = Make("Frame", {
        Size = UDim2.new(0, 42, 0, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = Cfg[cfgKey] and color or COL.Off,
        BorderSizePixel = 0,
    }, row)
    MakeCorner(10, pill)

    local knob = Make("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = Cfg[cfgKey] and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        BorderSizePixel = 0,
    }, pill)
    MakeCorner(8, knob)

    local btn = Make("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    }, row)

    btn.MouseButton1Click:Connect(function()
        Cfg[cfgKey] = not Cfg[cfgKey]
        local on = Cfg[cfgKey]
        Tween(pill, {BackgroundColor3 = on and color or COL.Off})
        Tween(knob, {Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)})
    end)

    return row
end

-- Bone radio button
local function MakeBoneBtn(parent, label, bone, xOff, color)
    local active = Cfg.TargetBone == bone
    local btn = Make("TextButton", {
        Size = UDim2.new(0, 88, 0, 26),
        Position = UDim2.new(0, xOff, 0, 0),
        BackgroundColor3 = active and color or COL.Off,
        Text = label,
        TextColor3 = COL.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        BorderSizePixel = 0,
    }, parent)
    MakeCorner(6, btn)
    return btn
end

-- ================================================================
--  MAIN WINDOW
-- ================================================================
local Win = Make("Frame", {
    Size = UDim2.new(0, 310, 0, 540),
    Position = UDim2.new(0, 80, 0, 80),
    BackgroundColor3 = COL.BG,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, ScreenGui)
MakeCorner(10, Win)
MakeStroke(COL.Border, 1.2, Win)

-- ── Top Bar ──────────────────────────────────────────────────────
local TopBar = Make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = COL.TopBar,
    BorderSizePixel = 0,
}, Win)
MakeCorner(10, TopBar)
-- ตัด corner ล่าง
Make("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0,0,1,-10),
    BackgroundColor3 = COL.TopBar,
    BorderSizePixel = 0,
}, TopBar)

Make("TextLabel", {
    Size = UDim2.new(1, -80, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "🎯  aimbotpc  —  ปืนพิษ / Kabucha",
    TextColor3 = COL.Text,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

-- Close button
local CloseBtn = Make("TextButton", {
    Size = UDim2.new(0, 26, 0, 26),
    Position = UDim2.new(1, -32, 0.5, -13),
    BackgroundColor3 = COL.Red,
    Text = "✕",
    TextColor3 = Color3.fromRGB(255,255,255),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
}, TopBar)
MakeCorner(6, CloseBtn)

-- Minimize button
local MinBtn = Make("TextButton", {
    Size = UDim2.new(0, 26, 0, 26),
    Position = UDim2.new(1, -62, 0.5, -13),
    BackgroundColor3 = Color3.fromRGB(200,150,0),
    Text = "—",
    TextColor3 = Color3.fromRGB(255,255,255),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
}, TopBar)
MakeCorner(6, MinBtn)

-- ── Content ──────────────────────────────────────────────────────
local Content = Make("Frame", {
    Size = UDim2.new(1, 0, 1, -38),
    Position = UDim2.new(0, 0, 0, 38),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Win)

local function SectionLabel(text, yPos)
    Make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 18),
        Position = UDim2.new(0, 10, 0, yPos),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = COL.Accent,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Content)
end

-- ─── AIMBOT ───
SectionLabel("─── AIMBOT ───────────────────────", 8)
MakeToggle(Content, "Aimbot Enabled",    30, "Enabled",    COL.OnGreen)
MakeToggle(Content, "Silent Aim",        68, "SilentAim",  COL.OnBlue)
MakeToggle(Content, "Prediction",       106, "Prediction", COL.OnBlue)
MakeToggle(Content, "Gravity Comp",     144, "GravityComp",COL.OnBlue)
MakeToggle(Content, "Auto Shoot",       182, "AutoShoot",  COL.OnGreen)
MakeToggle(Content, "Team Check",       220, "TeamCheck",  COL.OnGreen)
MakeToggle(Content, "Wall Check",       258, "WallCheck",  COL.OnGreen)

-- ─── FOV ───
SectionLabel("─── FOV ──────────────────────────", 298)
MakeFOVSlider(Content, 316)

-- ─── BONE SELECTOR ───
SectionLabel("─── TARGET BONE ──────────────────", 372)
local boneRow = Make("Frame", {
    Size = UDim2.new(1, -20, 0, 30),
    Position = UDim2.new(0, 10, 0, 392),
    BackgroundTransparency = 1,
}, Content)

local boneButtons = {}
local boneColors = COL.OnBlue

local function refreshBones()
    for bone, btn in pairs(boneButtons) do
        Tween(btn, {BackgroundColor3 = Cfg.TargetBone == bone and boneColors or COL.Off})
    end
end

local b1 = MakeBoneBtn(boneRow, "Head",       BONE.Head,             0, boneColors)
local b2 = MakeBoneBtn(boneRow, "UpperTorso", BONE.UpperTorso,      96, boneColors)
local b3 = MakeBoneBtn(boneRow, "Root",       BONE.HumanoidRootPart,192, boneColors)

boneButtons[BONE.Head]             = b1
boneButtons[BONE.UpperTorso]       = b2
boneButtons[BONE.HumanoidRootPart] = b3

b1.MouseButton1Click:Connect(function() Cfg.TargetBone = BONE.Head             refreshBones() end)
b2.MouseButton1Click:Connect(function() Cfg.TargetBone = BONE.UpperTorso       refreshBones() end)
b3.MouseButton1Click:Connect(function() Cfg.TargetBone = BONE.HumanoidRootPart refreshBones() end)

-- ─── ESP ───
SectionLabel("─── ESP ──────────────────────────", 434)
MakeToggle(Content, "ESP Enabled", 454, "ESPEnabled", COL.OnGreen)
MakeToggle(Content, "ESP Boxes",   492, "ESPBoxes",   COL.OnGreen)
MakeToggle(Content, "ESP Names",   502, "ESPNames",   COL.OnGreen)

-- ================================================================
--  DRAG LOGIC
-- ================================================================
do
    local dragging, dragStart, startPos

    -- ใช้ TextButton โปร่งใสครอบ TopBar เพื่อรับ input ได้แน่นอน
    local dragBtn = Make("TextButton", {
        Size = UDim2.new(1, -100, 1, 0), -- เว้นช่องปุ่ม X และ —
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 2,
    }, TopBar)

    dragBtn.MouseButton1Down:Connect(function()
        dragging  = true
        dragStart = UserInputService:GetMouseLocation()
        startPos  = Win.Position
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local cur   = UserInputService:GetMouseLocation()
            local delta = cur - dragStart
            Win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ================================================================
--  CLOSE / MINIMIZE
-- ================================================================
local minimized = false
local winVisible = true

-- ซ่อน/แสดง หน้าต่าง (ไม่ Destroy)
local function ToggleWindow()
    winVisible = not winVisible
    Win.Visible = winVisible
end

-- ปุ่ม M → ซ่อน (ไม่ทำลาย) เรียกกลับได้ด้วย Insert
CloseBtn.MouseButton1Click:Connect(function()
    ToggleWindow()
end)

-- Insert key → toggle เปิด/ปิดหน้าต่าง
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.M then
        ToggleWindow()
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Tween(Win, {Size = minimized and UDim2.new(0,310,0,38) or UDim2.new(0,310,0,540)}, 0.2)
end)

-- ================================================================
--  DRAWING WRAPPER
-- ================================================================
local function NewDraw(class, props)
    if not hasDrawing then
        local d = {}
        return setmetatable(d, {__newindex=function()end,__index=function()return false end})
    end
    local ok, d = pcall(Drawing.new, class)
    if not ok then
        local d = {}
        return setmetatable(d, {__newindex=function()end,__index=function()return false end})
    end
    for k, v in pairs(props) do pcall(function() d[k] = v end) end
    return d
end

-- ================================================================
--  FOV CIRCLE  (GUI-based — ทำงานได้ทุก executor)
-- ================================================================
local fovFrame = Make("Frame", {
    Size             = UDim2.new(0, Cfg.FOVRadius*2, 0, Cfg.FOVRadius*2),
    Position         = UDim2.new(0, -Cfg.FOVRadius, 0, -Cfg.FOVRadius),
    BackgroundTransparency = 1,
    BorderSizePixel  = 0,
    ZIndex           = 10,
}, ScreenGui)
MakeCorner(Cfg.FOVRadius, fovFrame)
MakeStroke(Cfg.FOVColor, Cfg.FOVThickness, fovFrame)


-- ================================================================
--  ESP POOL
-- ================================================================
local espCache = {}

local function GetESP(player)
    if not espCache[player] then
        espCache[player] = {
            box = NewDraw("Square",{Visible=false,Thickness=1.5,Color=Cfg.ESPColorEnemy,Filled=false,Transparency=1}),
            name = NewDraw("Text",{Visible=false,Size=13,Color=Color3.fromRGB(255,255,255),Outline=true,Center=true}),
            health = NewDraw("Square",{Visible=false,Thickness=1,Color=Color3.fromRGB(0,255,80),Filled=true,Transparency=1}),
            healthBg = NewDraw("Square",{Visible=false,Thickness=1,Color=Color3.fromRGB(25,25,25),Filled=true,Transparency=0.6}),
            dist = NewDraw("Text",{Visible=false,Size=11,Color=Color3.fromRGB(200,200,200),Outline=true,Center=true}),
            line = NewDraw("Line",{Visible=false,Thickness=1,Color=Cfg.ESPColorEnemy,Transparency=0.7}),
        }
    end
    return espCache[player]
end

local function HideESP(e)
    if not e then return end
    for _, d in pairs(e) do pcall(function() d.Visible = false end) end
end

local function CleanESP(player)
    local e = espCache[player]
    if e then
        for _, d in pairs(e) do pcall(function() d:Remove() end) end
        espCache[player] = nil
    end
end

Players.PlayerRemoving:Connect(CleanESP)

-- ================================================================
--  HELPERS
-- ================================================================
local function IsAlive(p)
    local c = p.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function GetHealth(p)
    local c = p.Character
    if not c then return 0,100 end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return 0,100 end
    return h.Health, h.MaxHealth
end

local function GetBone(p, boneName)
    local c = p.Character
    if not c then return nil end
    return c:FindFirstChild(boneName) or c:FindFirstChild("HumanoidRootPart")
end

local function IsEnemy(p)
    if p == LocalPlayer then return false end
    if Cfg.TeamCheck then
        local ok, same = pcall(function() return p.Team == LocalPlayer.Team end)
        if ok and same then return false end
    end
    return true
end

local function ViewportCenter()
    return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end

local function WorldToScreen(pos)
    local sp, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), sp.Z, vis
end

-- mousePos จะถูกอัปเดตทุก frame จาก main loop
local currentMousePos = Vector2.new(0, 0)

local function ScreenDist(worldPos)
    local sp, _, vis = WorldToScreen(worldPos)
    if not vis then return math.huge end
    return (sp - currentMousePos).Magnitude
end

local function PredictPos(part)
    if not Cfg.Prediction then return part.Position end
    local ok, vel = pcall(function() return part.AssemblyLinearVelocity end)
    if not ok then return part.Position end
    local origin  = Camera.CFrame.Position
    local dist    = (part.Position - origin).Magnitude
    local tFlight = dist / Cfg.KabuchaSpeed
    local predicted = part.Position + vel * tFlight
    if Cfg.GravityComp then
        predicted = predicted + Vector3.new(0, 0.5 * workspace.Gravity * (tFlight^2), 0)
    end
    return predicted
end

local function HasLOS(from, to)
    if not Cfg.WallCheck then return true end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local res = workspace:Raycast(from, (to-from), params)
    if not res then return true end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and res.Instance:IsDescendantOf(p.Character) then return true end
    end
    return false
end

-- ================================================================
--  TARGET SELECTION
-- ================================================================
local function GetTarget()
    local best, bestDist = nil, Cfg.FOVRadius
    for _, p in ipairs(Players:GetPlayers()) do
        if not IsEnemy(p) or not IsAlive(p) then continue end
        local part = GetBone(p, Cfg.TargetBone)
        if not part then continue end
        local predicted = PredictPos(part)
        local d = ScreenDist(predicted)
        if d < bestDist and HasLOS(Camera.CFrame.Position, predicted) then
            bestDist = d
            best = {part=part, player=p, pos=predicted}
        end
    end
    return best
end

-- ================================================================
--  SILENT AIM
-- ================================================================
local silentTarget = nil

-- Silent Aim hook — ติดตั้งไว้ตลอด แต่เช็ค Cfg.SilentAim + Cfg.Enabled แบบ dynamic
if hasGetRawMeta then
    local ok, mt = pcall(getrawmetatable, game)
    if ok and mt then
        local old_index = rawget(mt,"__index") or mt.__index
        if hasSetRO then pcall(setreadonly, mt, false) end
        local fn = function(self, key)
            if Cfg.Enabled and Cfg.SilentAim and silentTarget and (key == "Hit" or key == "UnitRay") then
                local part = silentTarget.part
                if part and part.Parent then
                    if key == "Hit" then return CFrame.new(silentTarget.pos)
                    elseif key == "UnitRay" then
                        local origin = Camera.CFrame.Position
                        local dir = (silentTarget.pos - origin).Unit
                        return Ray.new(origin, dir * 1000)
                    end
                end
            end
            return old_index(self, key)
        end
        mt.__index = hasNCC and newcclosure(fn) or fn
        if hasSetRO then pcall(setreadonly, mt, true) end
    end
end

-- ================================================================
--  ESP RENDER
-- ================================================================
local function RenderESP()
    if not Cfg.ESPEnabled then
        for _, e in pairs(espCache) do HideESP(e) end
        return
    end
    local vp     = Camera.ViewportSize
    local centre = ViewportCenter()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local e = GetESP(p)
        if not IsAlive(p) then HideESP(e) continue end
        local root = GetBone(p, BONE.HumanoidRootPart)
        local head = GetBone(p, BONE.Head)
        if not root or not head then HideESP(e) continue end
        local rootSP, rootZ, rootVis = WorldToScreen(root.Position)
        if not rootVis or rootZ < 0 then HideESP(e) continue end
        local headSP, _, headVis = WorldToScreen(head.Position + Vector3.new(0,0.7,0))
        if not headVis then HideESP(e) continue end
        local dist    = (Camera.CFrame.Position - root.Position).Magnitude
        local boxH    = math.abs(rootSP.Y - headSP.Y) * 2
        local boxW    = boxH * 0.5
        local enemy   = IsEnemy(p)
        local col     = enemy and Cfg.ESPColorEnemy or Cfg.ESPColor
        local hp,hpMax= GetHealth(p)
        local hpRatio = math.clamp(hp/hpMax, 0, 1)
        if Cfg.ESPBoxes then
            pcall(function()
                e.box.Visible=true; e.box.Color=col
                e.box.Size=Vector2.new(boxW,boxH)
                e.box.Position=Vector2.new(rootSP.X-boxW/2, headSP.Y)
            end)
        else pcall(function() e.box.Visible=false end) end
        if Cfg.ESPNames then
            pcall(function()
                e.name.Visible=true; e.name.Text=p.DisplayName
                e.name.Color=col; e.name.Position=Vector2.new(rootSP.X, headSP.Y-15)
            end)
        else pcall(function() e.name.Visible=false end) end
        if Cfg.ESPDistance then
            pcall(function()
                e.dist.Visible=true
                e.dist.Text=("[%.0f m]"):format(dist*0.0833)
                e.dist.Position=Vector2.new(rootSP.X, rootSP.Y+3)
            end)
        else pcall(function() e.dist.Visible=false end) end
        if Cfg.ESPHealth then
            pcall(function()
                local barX=rootSP.X-boxW/2-6; local barTop=headSP.Y; local barFull=boxH
                e.healthBg.Visible=true; e.healthBg.Size=Vector2.new(3,barFull); e.healthBg.Position=Vector2.new(barX,barTop)
                e.health.Visible=true; e.health.Size=Vector2.new(3,barFull*hpRatio)
                e.health.Position=Vector2.new(barX, barTop+barFull*(1-hpRatio))
                e.health.Color=Color3.fromHSV(hpRatio*0.33,1,1)
            end)
        else
            pcall(function() e.health.Visible=false end)
            pcall(function() e.healthBg.Visible=false end)
        end
        if Cfg.ESPLines then
            pcall(function()
                e.line.Visible=true; e.line.Color=col
                e.line.From=Vector2.new(centre.X, vp.Y); e.line.To=rootSP
            end)
        else pcall(function() e.line.Visible=false end) end
    end
end

-- ================================================================
--  MAIN LOOP
-- ================================================================
local shooting = false

local hasMoveRel = (typeof(mousemoverel) == "function")

RunService.RenderStepped:Connect(function()
    -- อัปเดต mouse position ก่อนทุกอย่าง
    currentMousePos = UserInputService:GetMouseLocation()

    -- ── FOV Circle (GUI) ──
    local r = Cfg.FOVRadius
    local activeColor = Cfg.Enabled and Cfg.FOVColor or Color3.fromRGB(200,50,50)
    pcall(function()
        fovFrame.Visible = Cfg.ShowFOV
        fovFrame.Size    = UDim2.new(0, r*2, 0, r*2)
        fovFrame.Position= UDim2.new(0, currentMousePos.X - r, 0, currentMousePos.Y - r)
        -- อัป corner radius ให้เป็นวงกลมเสมอ
        local corner = fovFrame:FindFirstChildOfClass("UICorner")
        if corner then corner.CornerRadius = UDim.new(0, r) end
        local stroke = fovFrame:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Color = activeColor end
    end)

    RenderESP()

    if not Cfg.Enabled then silentTarget = nil return end

    local t = GetTarget()
    silentTarget = t

    if not UserInputService:IsKeyDown(Cfg.AimKey) then shooting=false return end
    if not t then shooting=false return end

    -- Camera aimbot (ใช้เมื่อ SilentAim ปิด)
    if not Cfg.SilentAim then
        local targetSP, _, vis = WorldToScreen(t.pos)
        if vis then
            if hasMoveRel then
                -- mousemoverel = ขยับเมาส์จริง (ดีที่สุด)
                local delta = (targetSP - currentMousePos) * Cfg.Smoothness
                pcall(mousemoverel, delta.X, delta.Y)
            else
                -- fallback: Lerp camera CFrame
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(Camera.CFrame.Position, t.pos),
                    Cfg.Smoothness
                )
            end
        end
    end

    if Cfg.AutoShoot and not shooting then
        shooting = true
        if hasMouse1 then
            pcall(mouse1click)
        else
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendMouseButtonEvent(0,0,0,true,game,1)
                task.wait(0.05)
                vim:SendMouseButtonEvent(0,0,0,false,game,1)
            end)
        end
        task.delay(0.13, function() shooting=false end)
    end
end)

print("[aimbotpc] GUI loaded — ลาก topbar เพื่อย้ายหน้าต่าง")

end -- << ปิด MainLoad()

-- ================================================================
--  KEY SUBMIT HANDLER
-- ================================================================
local attempts = 0
local locked   = false

local function setLock(reason)
    locked           = true
    keyBox.Editable  = false
    submitBtn.Active = false
    statusLbl.Text   = reason
    TweenService_k:Create(submitBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 30, 30)}):Play()
end

local function tryKey()
    if locked then return end
    local input     = keyBox.Text:match("^%s*(.-)%s*$")
    local expiryStr = KEY_LIST[input]

    if expiryStr then
        local expiry = parseExpiry(expiryStr)
        local days   = daysLeft(expiry)
        if days >= 0 then
            -- ✅ ถูกต้อง + ยังไม่หมดอายุ
            local dayText = days == 0 and "หมดอายุวันนี้" or ("เหลืออีก %d วัน"):format(days)
            statusLbl.TextColor3 = Color3.fromRGB(0, 200, 100)
            statusLbl.Text       = ("✔  Key ถูกต้อง — %s"):format(dayText)
            TweenService_k:Create(submitBtn,  TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 200, 100)}):Play()
            TweenService_k:Create(cardStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(0, 200, 100)}):Play()
            task.delay(0.8, MainLoad)
        else
            -- ⏰ key หมดอายุ
            statusLbl.TextColor3 = Color3.fromRGB(230, 140, 0)
            statusLbl.Text       = ("⏰  Key หมดอายุแล้ว (%s)"):format(expiryStr)
            TweenService_k:Create(cardStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(230, 140, 0)}):Play()
            TweenService_k:Create(ibStroke,   TweenInfo.new(0.15), {Color = Color3.fromRGB(230, 140, 0)}):Play()
            shakeCard()
            task.delay(1, function()
                TweenService_k:Create(ibStroke,   TweenInfo.new(0.3), {Color = Color3.fromRGB(45, 50, 70)}):Play()
                TweenService_k:Create(cardStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(0, 170, 255)}):Play()
            end)
        end
    else
        -- ❌ key ผิด
        attempts += 1
        shakeCard()
        statusLbl.TextColor3 = Color3.fromRGB(220, 50, 50)
        statusLbl.Text       = ("✘  Key ผิด  (ครั้งที่ %d/5)"):format(attempts)
        TweenService_k:Create(ibStroke,   TweenInfo.new(0.15), {Color = Color3.fromRGB(220, 50, 50)}):Play()
        TweenService_k:Create(cardStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(220, 50, 50)}):Play()
        task.delay(0.8, function()
            TweenService_k:Create(ibStroke,   TweenInfo.new(0.3), {Color = Color3.fromRGB(45, 50, 70)}):Play()
            TweenService_k:Create(cardStroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(0, 170, 255)}):Play()
        end)
        if attempts >= 5 then
            setLock("🔒  ล็อค — re-execute script เพื่อลองใหม่")
        end
    end
end

submitBtn.MouseButton1Click:Connect(tryKey)
keyBox.FocusLost:Connect(function(enter) if enter then tryKey() end end)

statusLbl.Text = ""
