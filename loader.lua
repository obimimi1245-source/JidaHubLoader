-- ============================================================
--  JIDA LOADER v3 (HttpGet + robust JSON unescape)
-- ============================================================
local SUPABASE_URL = "https://vgnuursmimytngrxrcus.supabase.co"
local SUPABASE_KEY = "sb_publishable_hCWbfjIp7CTDMUsQMwzHkQ_Ip91FFKN"

local HttpService = game:GetService("HttpService")
local UIS         = game:GetService("UserInputService")
local Players     = game:GetService("Players")
local LPlayer     = Players.LocalPlayer

-- HWID
local function getHWID()
    local fns = {
        function() return _G.gethwid and _G.gethwid() end,
        function() return _G.syn and _G.syn.get_hwid and _G.syn.get_hwid() end,
        function() return _G.KRNL_IO and _G.KRNL_IO.gethwid and _G.KRNL_IO.gethwid() end,
        function() return game:GetService("RbxAnalyticsService"):GetClientId() end,
    }
    for _, fn in ipairs(fns) do
        local ok, hwid = pcall(fn)
        if ok and hwid and type(hwid) == "string" and #hwid > 0 then return hwid end
    end
    return "fallback_" .. tostring(LPlayer.UserId)
end
local HWID = getHWID()

local function urlEncode(s)
    s = tostring(s)
    s = s:gsub("([^%w%-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return s
end

-- Ручная расшифровка JSON-строки (когда JSONDecode не справляется)
local function manualUnescape(s)
    if type(s) ~= "string" then return s end
    -- убираем внешние кавычки
    if s:sub(1,1) == '"' and s:sub(-1) == '"' then
        s = s:sub(2, -2)
    end
    -- \n, \r, \t, \", \\ и unicode \uXXXX
    s = s:gsub("\\u(%x%x%x%x)", function(hex)
        local code = tonumber(hex, 16)
        if code and code < 128 then return string.char(code) end
        -- для не-ASCII возвращаем как есть (кириллица в комментариях)
        return ""
    end)
    s = s:gsub('\\"', '"')
    s = s:gsub("\\'", "'")
    s = s:gsub("\\n", "\n")
    s = s:gsub("\\r", "\r")
    s = s:gsub("\\t", "\t")
    s = s:gsub("\\\\", "\\")
    return s
end

-- Проверяем, что это настоящий Lua-код
local function looksLikeLua(s)
    if type(s) ~= "string" or #s < 20 then return false end
    -- первые непустые символы не должны быть " или {
    local head = s:sub(1, 40)
    if head:match('^%s*["{]') then return false end
    return true
end

-- Мини-окно
local function promptKey()
    local pg = LPlayer:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("JidaLoaderGui")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "JidaLoaderGui"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 380, 0, 210)
    frame.Position = UDim2.new(0.5, -190, 0.5, -105)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    frame.BorderSizePixel = 0; frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80,120,255); stroke.Thickness = 1.5
    stroke.Transparency = 0.3; stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 44); title.BackgroundTransparency = 1
    title.Text = "Jida Hub — Введите ключ"; title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold; title.TextSize = 18; title.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -40, 0, 42); box.Position = UDim2.new(0, 20, 0, 55)
    box.BackgroundColor3 = Color3.fromRGB(35, 35, 45); box.BorderSizePixel = 0
    box.PlaceholderText = "XXXX-XXXX"; box.Text = ""
    box.TextColor3 = Color3.new(1,1,1); box.PlaceholderColor3 = Color3.fromRGB(100,100,110)
    box.Font = Enum.Font.Gotham; box.TextSize = 15
    box.ClearTextOnFocus = false; box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -40, 0, 20); status.Position = UDim2.new(0, 20, 0, 105)
    status.BackgroundTransparency = 1; status.Text = ""
    status.TextColor3 = Color3.fromRGB(255,100,100)
    status.Font = Enum.Font.Gotham; status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left; status.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -40, 0, 42); btn.Position = UDim2.new(0, 20, 0, 130)
    btn.BackgroundColor3 = Color3.fromRGB(80, 120, 255); btn.BorderSizePixel = 0
    btn.Text = "Загрузить"; btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 15; btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    do
        local dragging, dragStart, startPos
        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; dragStart = input.Position; startPos = frame.Position
            end
        end)
        title.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    return gui, box, status, btn
end

-- Получить скрипт через GET RPC
local function fetchScript(key)
    local url = SUPABASE_URL
        .. "/rest/v1/rpc/get_script"
        .. "?apikey=" .. urlEncode(SUPABASE_KEY)
        .. "&p_key=" .. urlEncode(key)
        .. "&p_hwid=" .. urlEncode(HWID)

    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or not body then
        return nil, "HTTP error"
    end
    if #body < 5 then return nil, "Пустой ответ" end

    -- 1) пробуем JSONDecode
    local decoded = nil
    local okD, res = pcall(HttpService.JSONDecode, HttpService, body)
    if okD then decoded = res end

    -- 2) если не сработал — ручной unescape
    if type(decoded) ~= "string" then
        decoded = manualUnescape(body)
    end

    -- 3) если всё ещё выглядит как JSON — попробуем ещё раз
    if not looksLikeLua(decoded) then
        local second = manualUnescape(decoded)
        if looksLikeLua(second) then decoded = second end
    end

    if type(decoded) ~= "string" or #decoded < 20 then
        return nil, "Не удалось получить скрипт (тип: " .. type(decoded) .. ")"
    end

    if decoded == "null" then
        return nil, "Ключ не найден или истёк"
    end

    if not looksLikeLua(decoded) then
        return nil, "Скрипт не похож на Lua (первые: " .. decoded:sub(1,30) .. ")"
    end

    return decoded
end

-- Запуск
local gui, box, status, btn = promptKey()
local success = false

local function tryLoad()
    local key = box.Text
    if key == "" then
        status.Text = "Введите ключ"; status.TextColor3 = Color3.fromRGB(255,180,60)
        return
    end
    status.Text = "Проверка..."; status.TextColor3 = Color3.fromRGB(200,200,200)
    btn.Text = "..."

    task.spawn(function()
        local code, err = fetchScript(key)
        if code then
            status.Text = "Загрузка..."
            status.TextColor3 = Color3.fromRGB(80,220,120)
            task.wait(0.3)
            gui:Destroy()
            success = true
            local fn, loadErr = loadstring(code)
            if not fn then
                warn("[Jida] Ошибка компиляции: " .. tostring(loadErr))
                -- для отладки: покажем первые 200 символов кода
                warn("[Jida] Первые 200 символов:", code:sub(1, 200))
                return
            end
            local ok2, runErr = pcall(fn)
            if not ok2 then
                warn("[Jida] Ошибка выполнения: " .. tostring(runErr))
            end
        else
            status.Text = (err or "Неверный ключ"):sub(1, 60)
            status.TextColor3 = Color3.fromRGB(255,100,100)
            btn.Text = "Загрузить"
        end
    end)
end

btn.MouseButton1Click:Connect(tryLoad)
box.FocusLost:Connect(function(enter) if enter then tryLoad() end end)
repeat task.wait(0.1) until success
