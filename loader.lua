-- ============================================================
--  JIDA LOADER
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

-- Простой GET/POST
local function httpPost(url, body, headers)
    local fn = (_G.syn and _G.syn.request) or (_G.http and _G.http.request)
        or _G.http_request or (_G.fluxus and _G.fluxus.request) or _G.request
    if fn then
        local ok, res = pcall(fn, {
            Url = url, Method = "POST",
            Headers = headers or { ["Content-Type"] = "application/json" },
            Body = body,
        })
        if ok and type(res) == "table" then return res.StatusCode or 0, res.Body end
    end
    return 0, nil
end

-- Мини-окно ввода ключа
local function promptKey()
    local pg = LPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "JidaLoaderGui"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 380, 0, 200)
    frame.Position = UDim2.new(0.5, -190, 0.5, -100)
    frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    frame.BorderSizePixel = 0; frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40); title.BackgroundTransparency = 1
    title.Text = "Jida Hub — Введите ключ"; title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold; title.TextSize = 18; title.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -40, 0, 40); box.Position = UDim2.new(0, 20, 0, 55)
    box.BackgroundColor3 = Color3.fromRGB(35, 35, 45); box.BorderSizePixel = 0
    box.PlaceholderText = "XXXX-XXXX"; box.Text = ""
    box.TextColor3 = Color3.new(1,1,1); box.Font = Enum.Font.Gotham
    box.TextSize = 14; box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -40, 0, 42); btn.Position = UDim2.new(0, 20, 0, 110)
    btn.BackgroundColor3 = Color3.fromRGB(80, 120, 255); btn.BorderSizePixel = 0
    btn.Text = "Загрузить"; btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 15; btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -40, 0, 20); status.Position = UDim2.new(0, 20, 0, 158)
    status.BackgroundTransparency = 1; status.Text = ""
    status.TextColor3 = Color3.fromRGB(255,100,100)
    status.Font = Enum.Font.Gotham; status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left; status.Parent = frame

    return gui, box, status, btn
end

-- Получить скрипт с сервера
local function fetchScript(key)
    local url = SUPABASE_URL .. "/rest/v1/rpc/get_script"
    local body = HttpService:JSONEncode({ p_key = key, p_hwid = HWID })
    local status, resp = httpPost(url, body, {
        ["Content-Type"] = "application/json",
        ["apikey"]       = SUPABASE_KEY,
        ["Authorization"] = "Bearer " .. SUPABASE_KEY,
    })
    if status == 0 or not resp then return nil, "Сервер недоступен" end
    if status >= 400 then return nil, "Ошибка " .. tostring(status) end

    -- RPC возвращает JSON: строка или null
    local ok, data = pcall(HttpService.JSONDecode, HttpService, resp)
    if not ok then return nil, "Некорректный ответ" end
    if data == nil then return nil, "Ключ не найден или истёк" end
    if type(data) ~= "string" or #data < 20 then return nil, "Пустой скрипт" end
    return data
end

-- Запуск
local gui, box, status, btn = promptKey()
local success = false

local function tryLoad()
    local key = box.Text
    if key == "" then status.Text = "Введите ключ" return end
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
            if not fn then warn("[Jida] Ошибка компиляции: " .. tostring(loadErr)) return end
            local ok, runErr = pcall(fn)
            if not ok then warn("[Jida] Ошибка выполнения: " .. tostring(runErr)) end
        else
            status.Text = err or "Неверный ключ"
            status.TextColor3 = Color3.fromRGB(255,100,100)
            btn.Text = "Загрузить"
        end
    end)
end

btn.MouseButton1Click:Connect(tryLoad)
box.FocusLost:Connect(function(enter) if enter then tryLoad() end end)
repeat task.wait(0.1) until success
