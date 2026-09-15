-- ==========================================
-- CHAT-UNIVERSAL V5 (Baseado no design Move Block / UI Social)
-- Autor: techno_milgrau
-- Atualização: Perfil, Figurinhas, Edição, Sync P2P e Bot Test
-- ==========================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
local SERVER_URL = "https://chat-universal-gb22.onrender.com" 

-- ==========================================
-- SISTEMA DE PASTAS E ARQUIVOS (JSON)
-- ==========================================
local BaseFolder = "ChatUniversal_Data"
local FriendsFile = BaseFolder .. "/Amigos.json"
local StickersFolder = BaseFolder .. "/Stickers"
local RecentStickersFile = BaseFolder .. "/StickersRecentes.json"

pcall(function()
    if isfolder and not isfolder(BaseFolder) then makefolder(BaseFolder) end
    if isfolder and not isfolder(StickersFolder) then makefolder(StickersFolder) end
end)

local LocalData = { Friends = {}, RecentStickers = {} }

local function SaveData(file, data)
    pcall(function() if writefile then writefile(file, HttpService:JSONEncode(data)) end end)
end

local function LoadData(file)
    local data = nil
    pcall(function()
        if isfile and isfile(file) then
            data = HttpService:JSONDecode(readfile(file))
        end
    end)
    return data
end

-- Carregar amigos e figurinhas recentes
local loadedFriends = LoadData(FriendsFile)
if loadedFriends then LocalData.Friends = loadedFriends end
local loadedStickers = LoadData(RecentStickersFile)
if loadedStickers then LocalData.RecentStickers = loadedStickers end

-- Garantir o Bot "Test"
if not table.find(LocalData.Friends, "Test") then
    table.insert(LocalData.Friends, "Test")
    SaveData(FriendsFile, LocalData.Friends)
end

local function GetChatFilePath(friendName) return BaseFolder .. "/Chat_" .. friendName .. ".json" end

local function SaveChat(friendName, chatHistory) SaveData(GetChatFilePath(friendName), chatHistory) end

local function LoadChat(friendName) return LoadData(GetChatFilePath(friendName)) or {} end

-- ==========================================
-- REGISTRO DO USUÁRIO
-- ==========================================
task.spawn(function()
    pcall(function()
        HttpService:RequestAsync({
            Url = SERVER_URL .. "/register", Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({username = player.Name, displayName = player.DisplayName, userId = player.UserId})
        })
    end)
end)

-- ==========================================
-- CRIANDO A INTERFACE (GUI)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatUniversalHub"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrameWrapper = Instance.new("Frame", ScreenGui)
MainFrameWrapper.Size = UDim2.new(0, 280, 0, 480)
MainFrameWrapper.Position = UDim2.new(0.5, -140, 0.5, -240)
MainFrameWrapper.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
MainFrameWrapper.BorderSizePixel = 0
MainFrameWrapper.ClipsDescendants = true
local MainCorner = Instance.new("UICorner", MainFrameWrapper) MainCorner.CornerRadius = UDim.new(0, 10)

local MinimizedIcon = Instance.new("TextButton", MainFrameWrapper)
MinimizedIcon.Size = UDim2.new(1, 0, 1, 0) MinimizedIcon.BackgroundTransparency = 1 MinimizedIcon.Text = "C" MinimizedIcon.TextColor3 = Color3.fromRGB(255, 255, 255) MinimizedIcon.Font = Enum.Font.GothamBold MinimizedIcon.TextSize = 24 MinimizedIcon.Visible = false

local function MakeDraggable(dragHandle, frameToMove)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true dragInput = input dragStart = input.Position startPos = frameToMove.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frameToMove.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then dragging = false dragInput = nil end
    end)
end

local TitleBar = Instance.new("Frame", MainFrameWrapper)
TitleBar.Size = UDim2.new(1, 0, 0, 40) TitleBar.BackgroundTransparency = 1 TitleBar.ZIndex = 10
MakeDraggable(TitleBar, MainFrameWrapper)

local Title = Instance.new("TextLabel", TitleBar) Title.Size = UDim2.new(1, -80, 0, 20) Title.Position = UDim2.new(0, 10, 0, 5) Title.BackgroundTransparency = 1 Title.Text = "Chat-universal" Title.TextColor3 = Color3.fromRGB(255, 255, 255) Title.Font = Enum.Font.GothamBold Title.TextSize = 18 Title.TextXAlignment = Enum.TextXAlignment.Left
local Subtitle = Instance.new("TextLabel", TitleBar) Subtitle.Size = UDim2.new(1, -80, 0, 12) Subtitle.Position = UDim2.new(0, 10, 0, 24) Subtitle.BackgroundTransparency = 1 Subtitle.Text = "techno_milgrau" Subtitle.TextColor3 = Color3.fromRGB(150, 150, 150) Subtitle.Font = Enum.Font.Gotham Subtitle.TextSize = 10 Subtitle.TextXAlignment = Enum.TextXAlignment.Left

local NotifyBtn = Instance.new("TextButton", TitleBar) NotifyBtn.Size = UDim2.new(0, 30, 0, 30) NotifyBtn.Position = UDim2.new(1, -65, 0, 5) NotifyBtn.BackgroundTransparency = 1 NotifyBtn.Text = "🔔" NotifyBtn.TextColor3 = Color3.fromRGB(200, 200, 200) NotifyBtn.Font = Enum.Font.GothamBold NotifyBtn.TextSize = 16
local MinimizeBtn = Instance.new("TextButton", TitleBar) MinimizeBtn.Size = UDim2.new(0, 30, 0, 30) MinimizeBtn.Position = UDim2.new(1, -35, 0, 5) MinimizeBtn.BackgroundTransparency = 1 MinimizeBtn.Text = "−" MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200) MinimizeBtn.Font = Enum.Font.GothamBold MinimizeBtn.TextSize = 20

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    if not isMinimized then
        isMinimized = true TitleBar.Visible = false
        if MainFrameWrapper:FindFirstChild("SettingsPanel") then MainFrameWrapper.SettingsPanel.Visible = false end
        TweenService:Create(MainFrameWrapper, TweenInfo.new(0.25), {Size = UDim2.new(0, 50, 0, 50)}):Play()
        TweenService:Create(MainCorner, TweenInfo.new(0.25), {CornerRadius = UDim.new(0, 12)}):Play()
        task.wait(0.25) if isMinimized then MinimizedIcon.Visible = true end
    end
end)
MinimizedIcon.MouseButton1Click:Connect(function()
    if isMinimized then
        isMinimized = false MinimizedIcon.Visible = false TitleBar.Visible = true
        if MainFrameWrapper:FindFirstChild("SettingsPanel") then MainFrameWrapper.SettingsPanel.Visible = true end
        TweenService:Create(MainFrameWrapper, TweenInfo.new(0.25), {Size = UDim2.new(0, 280, 0, 480)}):Play()
        TweenService:Create(MainCorner, TweenInfo.new(0.25), {CornerRadius = UDim.new(0, 10)}):Play()
    end
end)

-- ==========================================
-- GERENCIADOR DE ABAS
-- ==========================================
local SettingsPanel = Instance.new("Frame", MainFrameWrapper) SettingsPanel.Name = "SettingsPanel" SettingsPanel.Size = UDim2.new(1, 0, 1, -40) SettingsPanel.Position = UDim2.new(0, 0, 0, 40) SettingsPanel.BackgroundTransparency = 1

local function CreateMenuFrame()
    local f = Instance.new("Frame", SettingsPanel) f.Size = UDim2.new(1, 0, 1, 0) f.Position = UDim2.new(1, 0, 0, 0) f.BackgroundTransparency = 1
    return f
end
local MainMenu = CreateMenuFrame() MainMenu.Position = UDim2.new(0, 0, 0, 0)
local SearchMenu = CreateMenuFrame()
local FriendsMenu = CreateMenuFrame()
local PrivateChatMenu = CreateMenuFrame()
local NotificationsMenu = CreateMenuFrame()
local ProfileMenu = CreateMenuFrame()

local MenuStack = {MainMenu}
local CurrentMenu = MainMenu

local function OpenMenu(newMenu)
    if CurrentMenu == newMenu then return end
    CurrentMenu:TweenPosition(UDim2.new(-1, 0, 0, 0), "Out", "Quad", 0.2, true)
    newMenu.Position = UDim2.new(1, 0, 0, 0)
    newMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
    table.insert(MenuStack, newMenu) CurrentMenu = newMenu
end
local function CloseMenu()
    if #MenuStack <= 1 then return end
    local menuToClose = table.remove(MenuStack)
    local previousMenu = MenuStack[#MenuStack]
    menuToClose:TweenPosition(UDim2.new(1, 0, 0, 0), "Out", "Quad", 0.2, true)
    previousMenu.Position = UDim2.new(-1, 0, 0, 0)
    previousMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
    CurrentMenu = previousMenu
end

local function createTopBar(parent, titleText, backAction)
    local bar = Instance.new("Frame", parent) bar.Size = UDim2.new(1, 0, 0, 40) bar.BackgroundTransparency = 1
    local title = Instance.new("TextLabel", bar) title.Size = UDim2.new(1, -40, 1, 0) title.Position = UDim2.new(0, 40, 0, 0) title.BackgroundTransparency = 1 title.Text = titleText title.TextColor3 = Color3.fromRGB(255, 255, 255) title.Font = Enum.Font.GothamBold title.TextSize = 16 title.TextXAlignment = Enum.TextXAlignment.Left
    local backBtn = Instance.new("TextButton", bar) backBtn.Size = UDim2.new(0, 30, 0, 30) backBtn.Position = UDim2.new(0, 5, 0, 5) backBtn.BackgroundTransparency = 1 backBtn.Text = "◀" backBtn.TextColor3 = Color3.fromRGB(200, 200, 200) backBtn.Font = Enum.Font.GothamBold backBtn.TextSize = 18
    backBtn.MouseButton1Click:Connect(backAction or CloseMenu)
    return title
end

-- ==========================================
-- COMPONENTES GLOBAIS (Perfil e Alertas)
-- ==========================================
local function ShowAlert(title, desc, confirmText, cancelText, onConfirm)
    local overlay = Instance.new("Frame", ScreenGui) overlay.Size = UDim2.new(1, 0, 1, 0) overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0) overlay.BackgroundTransparency = 0.5 overlay.ZIndex = 100
    local box = Instance.new("Frame", overlay) box.Size = UDim2.new(0, 220, 0, 120) box.Position = UDim2.new(0.5, -110, 0.5, -60) box.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    local t = Instance.new("TextLabel", box) t.Size = UDim2.new(1, 0, 0, 30) t.BackgroundTransparency = 1 t.Text = title t.TextColor3 = Color3.fromRGB(255, 255, 255) t.Font = Enum.Font.GothamBold t.TextSize = 14
    local d = Instance.new("TextLabel", box) d.Size = UDim2.new(1, -20, 0, 40) d.Position = UDim2.new(0, 10, 0, 30) d.BackgroundTransparency = 1 d.Text = desc d.TextColor3 = Color3.fromRGB(200, 200, 200) d.Font = Enum.Font.Gotham d.TextSize = 12 d.TextWrapped = true
    
    local btnY = Instance.new("TextButton", box) btnY.Size = UDim2.new(0.4, 0, 0, 30) btnY.Position = UDim2.new(0.1, 0, 1, -40) btnY.BackgroundColor3 = Color3.fromRGB(255, 60, 80) btnY.Text = confirmText btnY.TextColor3 = Color3.fromRGB(255, 255, 255) btnY.Font = Enum.Font.GothamBold Instance.new("UICorner", btnY).CornerRadius = UDim.new(0, 6)
    local btnN = Instance.new("TextButton", box) btnN.Size = UDim2.new(0.4, 0, 0, 30) btnN.Position = UDim2.new(0.5, 0, 1, -40) btnN.BackgroundColor3 = Color3.fromRGB(60, 60, 65) btnN.Text = cancelText btnN.TextColor3 = Color3.fromRGB(255, 255, 255) btnN.Font = Enum.Font.GothamBold Instance.new("UICorner", btnN).CornerRadius = UDim.new(0, 6)
    
    btnY.MouseButton1Click:Connect(function() overlay:Destroy() if onConfirm then onConfirm() end end)
    btnN.MouseButton1Click:Connect(function() overlay:Destroy() end)
end

local function ShowTextInput(title, defaultText, maxChars, onConfirm)
    local overlay = Instance.new("Frame", ScreenGui) overlay.Size = UDim2.new(1, 0, 1, 0) overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0) overlay.BackgroundTransparency = 0.5 overlay.ZIndex = 100
    local box = Instance.new("Frame", overlay) box.Size = UDim2.new(0, 240, 0, 150) box.Position = UDim2.new(0.5, -120, 0.5, -75) box.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    local t = Instance.new("TextLabel", box) t.Size = UDim2.new(1, 0, 0, 30) t.BackgroundTransparency = 1 t.Text = title t.TextColor3 = Color3.fromRGB(255, 255, 255) t.Font = Enum.Font.GothamBold t.TextSize = 14
    
    local inputWrap = Instance.new("Frame", box) inputWrap.Size = UDim2.new(1, -20, 0, 60) inputWrap.Position = UDim2.new(0, 10, 0, 35) inputWrap.BackgroundColor3 = Color3.fromRGB(20, 20, 22) Instance.new("UICorner", inputWrap).CornerRadius = UDim.new(0, 6)
    local input = Instance.new("TextBox", inputWrap) input.Size = UDim2.new(1, -10, 1, -10) input.Position = UDim2.new(0, 5, 0, 5) input.BackgroundTransparency = 1 input.Text = defaultText input.TextColor3 = Color3.fromRGB(255, 255, 255) input.Font = Enum.Font.Gotham input.TextSize = 12 input.TextWrapped = true input.ClearTextOnFocus = false input.MultiLine = true
    
    local btnY = Instance.new("TextButton", box) btnY.Size = UDim2.new(0.4, 0, 0, 30) btnY.Position = UDim2.new(0.1, 0, 1, -40) btnY.BackgroundColor3 = Color3.fromRGB(46, 204, 113) btnY.Text = "Salvar" btnY.TextColor3 = Color3.fromRGB(255, 255, 255) btnY.Font = Enum.Font.GothamBold Instance.new("UICorner", btnY).CornerRadius = UDim.new(0, 6)
    local btnN = Instance.new("TextButton", box) btnN.Size = UDim2.new(0.4, 0, 0, 30) btnN.Position = UDim2.new(0.5, 0, 1, -40) btnN.BackgroundColor3 = Color3.fromRGB(60, 60, 65) btnN.Text = "Cancelar" btnN.TextColor3 = Color3.fromRGB(255, 255, 255) btnN.Font = Enum.Font.GothamBold Instance.new("UICorner", btnN).CornerRadius = UDim.new(0, 6)
    
    input:GetPropertyChangedSignal("Text"):Connect(function() if string.len(input.Text) > maxChars then input.Text = string.sub(input.Text, 1, maxChars) end end)
    btnY.MouseButton1Click:Connect(function() overlay:Destroy() if onConfirm then onConfirm(input.Text) end end)
    btnN.MouseButton1Click:Connect(function() overlay:Destroy() end)
end

-- ==========================================
-- UI DE PERFIL 
-- ==========================================
createTopBar(ProfileMenu, "Perfil")
local ProfileScroll = Instance.new("ScrollingFrame", ProfileMenu) ProfileScroll.Size = UDim2.new(1, 0, 1, -40) ProfileScroll.Position = UDim2.new(0, 0, 0, 40) ProfileScroll.BackgroundTransparency = 1 ProfileScroll.ScrollBarThickness = 0
local ProfAvatar = Instance.new("ImageLabel", ProfileScroll) ProfAvatar.Size = UDim2.new(0, 90, 0, 90) ProfAvatar.Position = UDim2.new(0.5, -45, 0, 20) ProfAvatar.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", ProfAvatar).CornerRadius = UDim.new(1, 0)
local ProfName = Instance.new("TextLabel", ProfileScroll) ProfName.Size = UDim2.new(1, 0, 0, 20) ProfName.Position = UDim2.new(0, 0, 0, 120) ProfName.BackgroundTransparency = 1 ProfName.TextColor3 = Color3.fromRGB(255, 255, 255) ProfName.Font = Enum.Font.GothamBold ProfName.TextSize = 16
local ProfUser = Instance.new("TextLabel", ProfileScroll) ProfUser.Size = UDim2.new(1, 0, 0, 15) ProfUser.Position = UDim2.new(0, 0, 0, 140) ProfUser.BackgroundTransparency = 1 ProfUser.TextColor3 = Color3.fromRGB(150, 150, 150) ProfUser.Font = Enum.Font.Gotham ProfUser.TextSize = 12
local ProfStats = Instance.new("TextLabel", ProfileScroll) ProfStats.Size = UDim2.new(1, 0, 0, 40) ProfStats.Position = UDim2.new(0, 0, 0, 160) ProfStats.BackgroundTransparency = 1 ProfStats.TextColor3 = Color3.fromRGB(255, 255, 255) ProfStats.Font = Enum.Font.GothamBold ProfStats.TextSize = 14
local ProfBio = Instance.new("TextLabel", ProfileScroll) ProfBio.Size = UDim2.new(1, -40, 0, 40) ProfBio.Position = UDim2.new(0, 20, 0, 210) ProfBio.BackgroundTransparency = 1 ProfBio.TextColor3 = Color3.fromRGB(220, 220, 220) ProfBio.Font = Enum.Font.Gotham ProfBio.TextSize = 12 ProfBio.TextWrapped = true ProfBio.TextYAlignment = Enum.TextYAlignment.Top
local BioBtn = Instance.new("TextButton", ProfileScroll) BioBtn.Size = UDim2.new(1, 0, 1, 0) BioBtn.BackgroundTransparency = 1 BioBtn.Text = "" BioBtn.Parent = ProfBio
local ProfActionBtn = Instance.new("TextButton", ProfileScroll) ProfActionBtn.Size = UDim2.new(0, 140, 0, 35) ProfActionBtn.Position = UDim2.new(0.5, -70, 0, 260) ProfActionBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) ProfActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255) ProfActionBtn.Font = Enum.Font.GothamBold ProfActionBtn.TextSize = 14 Instance.new("UICorner", ProfActionBtn).CornerRadius = UDim.new(0, 8)

local currentProfileUser = ""
local currentProfileIsSelf = false

local function OpenProfile(username, displayName, userId, isSelf)
    currentProfileUser = username currentProfileIsSelf = isSelf
    ProfName.Text = displayName or username ProfUser.Text = "@" .. username
    pcall(function() ProfAvatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(userId or 1).."&w=150&h=150" end)
    
    ProfBio.Text = "Carregando..." ProfStats.Text = "0\nAmigos"
    ProfActionBtn.Visible = not isSelf

    if not isSelf then
        if table.find(LocalData.Friends, username) then
            ProfActionBtn.Text = "Amigos" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        else
            ProfActionBtn.Text = "Adicionar" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) -- Rosa TikTok
        end
    end

    -- Puxa bio e amigos do servidor
    task.spawn(function()
        pcall(function()
            local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_profile?username=" .. username, Method = "GET"})
            if res.Success then
                local data = HttpService:JSONDecode(res.Body)
                ProfBio.Text = data.bio or "Adicionar bio+"
                ProfStats.Text = (data.friendsCount or 0) .. "\nAmigos"
            end
        end)
    end)
    OpenMenu(ProfileMenu)
end

BioBtn.MouseButton1Click:Connect(function()
    if currentProfileIsSelf then
        local askStr = ProfBio.Text == "Adicionar bio+" and "Adicionar biografia?" or "Editar biografia?"
        ShowAlert(askStr, "Deseja alterar o texto do seu perfil?", "Sim", "Não", function()
            local def = ProfBio.Text == "Adicionar bio+" and "" or ProfBio.Text
            ShowTextInput("Sua Biografia", def, 80, function(newBio)
                if newBio == "" then newBio = "Adicionar bio+" end
                ProfBio.Text = newBio
                task.spawn(function()
                    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/update_bio", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({username = player.Name, bio = newBio})}) end)
                end)
            end)
        end)
    end
end)

ProfActionBtn.MouseButton1Click:Connect(function()
    if ProfActionBtn.Text == "Amigos" then
        ShowAlert("Desfazer Amizade", "Você quer mesmo remover @"..currentProfileUser.." dos amigos?", "Remover", "Cancelar", function()
            local idx = table.find(LocalData.Friends, currentProfileUser)
            if idx then table.remove(LocalData.Friends, idx) SaveData(FriendsFile, LocalData.Friends) end
            ProfActionBtn.Text = "Adicionar" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84)
            pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/remove_friend", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = currentProfileUser})}) end)
        end)
    elseif ProfActionBtn.Text == "Adicionar" then
        ProfActionBtn.Text = "Enviado" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, fromDisplay = player.DisplayName, fromId = player.UserId, to = currentProfileUser})}) end)
    end
end)

-- ==========================================
-- MENU PRINCIPAL (BOTÕES)
-- ==========================================
local function createMenuBtn(parent, yPos, iconText, callback)
    local btn = Instance.new("TextButton", parent) btn.Size = UDim2.new(0, 240, 0, 45) btn.Position = UDim2.new(0.5, -120, 0, yPos) btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) btn.Text = iconText btn.TextColor3 = Color3.fromRGB(255, 255, 255) btn.Font = Enum.Font.GothamBold Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback) return btn
end
createMenuBtn(MainMenu, 20, "👤 Meu Perfil", function() OpenProfile(player.Name, player.DisplayName, player.UserId, true) end)
createMenuBtn(MainMenu, 75, "🔍 Procurar Amigos", function() OpenMenu(SearchMenu) end)
createMenuBtn(MainMenu, 130, "💬 Mensagens", function() OpenMenu(FriendsMenu) LoadFriendsUI() end)
NotifyBtn.MouseButton1Click:Connect(function() if CurrentMenu ~= NotificationsMenu then OpenMenu(NotificationsMenu) LoadNotificationsUI() end end)

-- ==========================================
-- ENTRADA DE USUÁRIO (LISTAS)
-- ==========================================
local function CreateUserEntry(parent, displayName, username, userId, statusText)
    local frame = Instance.new("Frame", parent) frame.Size = UDim2.new(1, -20, 0, 60) frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local avatar = Instance.new("ImageLabel", frame) avatar.Size = UDim2.new(0, 45, 0, 45) avatar.Position = UDim2.new(0, 8, 0, 7) avatar.BackgroundColor3 = Color3.fromRGB(20, 20, 22) Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
    pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(userId or 1).."&w=150&h=150" end)
    local dName = Instance.new("TextLabel", frame) dName.Size = UDim2.new(0, 100, 0, 20) dName.Position = UDim2.new(0, 60, 0, 8) dName.BackgroundTransparency = 1 dName.Text = displayName dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left dName.TextScaled = true
    local uName = Instance.new("TextLabel", frame) uName.Size = UDim2.new(0, 100, 0, 16) uName.Position = UDim2.new(0, 60, 0, 30) uName.BackgroundTransparency = 1 uName.Text = "@" .. username uName.TextColor3 = Color3.fromRGB(150, 150, 150) uName.Font = Enum.Font.Gotham uName.TextSize = 10 uName.TextXAlignment = Enum.TextXAlignment.Left
    
    local isFriend = table.find(LocalData.Friends, username)
    local actionText = statusText or (isFriend and "Amigos" or "Adicionar")
    local statusLabel = Instance.new("TextLabel", frame) statusLabel.Size = UDim2.new(0, 70, 0, 16) statusLabel.Position = UDim2.new(1, -78, 0.5, -8) statusLabel.BackgroundTransparency = 1 statusLabel.Font = Enum.Font.GothamBold statusLabel.TextSize = 11 statusLabel.TextXAlignment = Enum.TextXAlignment.Right statusLabel.Text = actionText
    if actionText == "Online" then statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113) elseif actionText == "Digitando..." then statusLabel.TextColor3 = Color3.fromRGB(241, 196, 15) else statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150) end

    local hitBox = Instance.new("TextButton", frame) hitBox.Size = UDim2.new(1, 0, 1, 0) hitBox.BackgroundTransparency = 1 hitBox.Text = ""
    hitBox.MouseButton1Click:Connect(function() OpenProfile(username, displayName, userId, false) end)
    return frame
end

-- ABA PESQUISA
createTopBar(SearchMenu, "Procurar Amigos")
local SearchInput = Instance.new("TextBox", SearchMenu) SearchInput.Size = UDim2.new(1, -20, 0, 35) SearchInput.Position = UDim2.new(0, 10, 0, 45) SearchInput.BackgroundColor3 = Color3.fromRGB(30, 30, 35) SearchInput.PlaceholderText = "Pesquisar nick..." SearchInput.Text = "" SearchInput.TextColor3 = Color3.fromRGB(255, 255, 255) SearchInput.Font = Enum.Font.Gotham SearchInput.TextSize = 13 Instance.new("UICorner", SearchInput).CornerRadius = UDim.new(0, 6)
local SearchResults = Instance.new("ScrollingFrame", SearchMenu) SearchResults.Size = UDim2.new(1, 0, 1, -90) SearchResults.Position = UDim2.new(0, 0, 0, 90) SearchResults.BackgroundTransparency = 1 SearchResults.ScrollBarThickness = 3
local SearchLayout = Instance.new("UIListLayout", SearchResults) SearchLayout.Padding = UDim.new(0, 8) SearchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SearchLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SearchResults.CanvasSize = UDim2.new(0, 0, 0, SearchLayout.AbsoluteContentSize.Y + 10) end)

SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    for _, child in pairs(SearchResults:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    if SearchInput.Text == "" then return end
    task.delay(0.5, function()
        pcall(function()
            local res = HttpService:RequestAsync({Url = SERVER_URL .. "/users?query=" .. HttpService:UrlEncode(SearchInput.Text), Method = "GET"})
            if res.Success then
                for _, u in ipairs(HttpService:JSONDecode(res.Body)) do
                    if u.username ~= player.Name then CreateUserEntry(SearchResults, u.displayName, u.username, u.userId, nil) end
                end
            end
        end)
    end)
end)

-- ABA NOTIFICAÇÕES (Corrigido para mostrar a foto corretamente)
createTopBar(NotificationsMenu, "Notificações")
local RequestsList = Instance.new("ScrollingFrame", NotificationsMenu) RequestsList.Size = UDim2.new(1, 0, 1, -50) RequestsList.Position = UDim2.new(0, 0, 0, 50) RequestsList.BackgroundTransparency = 1 RequestsList.ScrollBarThickness = 3
local ReqLayout = Instance.new("UIListLayout", RequestsList) ReqLayout.Padding = UDim.new(0, 8) ReqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ReqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RequestsList.CanvasSize = UDim2.new(0, 0, 0, ReqLayout.AbsoluteContentSize.Y + 10) end)

function LoadNotificationsUI()
    for _, child in pairs(RequestsList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    task.spawn(function()
        pcall(function()
            local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_requests?username=" .. player.Name, Method = "GET"})
            if res.Success then
                for _, req in ipairs(HttpService:JSONDecode(res.Body)) do
                    local card = Instance.new("Frame", RequestsList) card.Size = UDim2.new(1, -20, 0, 60) card.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
                    local avatar = Instance.new("ImageLabel", card) avatar.Size = UDim2.new(0, 45, 0, 45) avatar.Position = UDim2.new(0, 8, 0, 7) avatar.BackgroundColor3 = Color3.fromRGB(20, 20, 22) Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
                    pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(req.fromId or 1).."&w=150&h=150" end) -- FOTO CORRIGIDA
                    local dName = Instance.new("TextLabel", card) dName.Size = UDim2.new(0, 100, 0, 18) dName.Position = UDim2.new(0, 60, 0, 10) dName.BackgroundTransparency = 1 dName.Text = req.fromDisplay or req.from dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left
                    
                    local acceptBtn = Instance.new("TextButton", card) acceptBtn.Size = UDim2.new(0, 28, 0, 28) acceptBtn.Position = UDim2.new(1, -65, 0.5, -14) acceptBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113) acceptBtn.Text = "✓" acceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255) Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 6)
                    local declineBtn = Instance.new("TextButton", card) declineBtn.Size = UDim2.new(0, 28, 0, 28) declineBtn.Position = UDim2.new(1, -32, 0.5, -14) declineBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60) declineBtn.Text = "✕" declineBtn.TextColor3 = Color3.fromRGB(255, 255, 255) Instance.new("UICorner", declineBtn).CornerRadius = UDim.new(0, 6)
                    
                    acceptBtn.MouseButton1Click:Connect(function()
                        if not table.find(LocalData.Friends, req.from) then table.insert(LocalData.Friends, req.from) SaveData(FriendsFile, LocalData.Friends) end
                        pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/accept_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from})}) end)
                        card:Destroy()
                    end)
                    declineBtn.MouseButton1Click:Connect(function()
                        pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/decline_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from})}) end)
                        card:Destroy()
                    end)
                end
            end
        end)
    end)
end

-- ABA MENSAGENS (COM SYNC AUTOMÁTICO DE AMIGOS)
createTopBar(FriendsMenu, "Mensagens")
local FriendsList = Instance.new("ScrollingFrame", FriendsMenu) FriendsList.Size = UDim2.new(1, 0, 1, -50) FriendsList.Position = UDim2.new(0, 0, 0, 50) FriendsList.BackgroundTransparency = 1 FriendsList.ScrollBarThickness = 3
local FriendsLayout = Instance.new("UIListLayout", FriendsList) FriendsLayout.Padding = UDim.new(0, 8) FriendsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
FriendsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() FriendsList.CanvasSize = UDim2.new(0, 0, 0, FriendsLayout.AbsoluteContentSize.Y + 10) end)

local ActiveChatTarget = ""
local ChatTitle = createTopBar(PrivateChatMenu, "Chat", function() CloseMenu() ActiveChatTarget = "" end)

local function OpenPrivateChat(username, displayName)
    ActiveChatTarget = username ChatTitle.Text = displayName
    OpenMenu(PrivateChatMenu) RefreshChatUI(LoadChat(username))
end

-- Modificado para permitir clicar nos perfis pela lista de mensagens
function LoadFriendsUI()
    for _, child in pairs(FriendsList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, friendName in ipairs(LocalData.Friends) do
        local targetId = 1 pcall(function() targetId = Players:GetUserIdFromNameAsync(friendName) end)
        local statusText = "Offline"
        if friendName ~= "Test" then
            pcall(function() local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_status?username=" .. friendName, Method = "GET"}) if res.Success then statusText = HttpService:JSONDecode(res.Body).status end end)
        else statusText = "Bot" end
        
        local entry = CreateUserEntry(FriendsList, friendName, friendName, targetId, statusText)
        -- Sobrescreve o clique da lista de mensagens para abrir o CHAT ao invés do perfil
        local hitBox = entry:FindFirstChildOfClass("TextButton")
        if hitBox then
            hitBox.MouseButton1Click:Connect(function() OpenPrivateChat(friendName, friendName) end)
        end
    end
end

-- Loop para sincronizar novos amigos que aceitaram você
task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_new_friends?username=" .. player.Name, Method = "GET"})
            if res.Success then
                local novos = HttpService:JSONDecode(res.Body)
                for _, n in ipairs(novos) do
                    if not table.find(LocalData.Friends, n) then
                        table.insert(LocalData.Friends, n) SaveData(FriendsFile, LocalData.Friends)
                    end
                end
            end
        end)
    end
end)

-- ==========================================
-- CHAT PRIVADO & FIGURINHAS
-- ==========================================
local ChatScroll = Instance.new("ScrollingFrame", PrivateChatMenu) ChatScroll.Size = UDim2.new(1, -20, 1, -100) ChatScroll.Position = UDim2.new(0, 10, 0, 45) ChatScroll.BackgroundTransparency = 1 ChatScroll.ScrollBarThickness = 4 ChatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
local ChatLayout = Instance.new("UIListLayout", ChatScroll) ChatLayout.Padding = UDim.new(0, 8)

local ChatInputFrame = Instance.new("Frame", PrivateChatMenu) ChatInputFrame.Size = UDim2.new(1, -20, 0, 40) ChatInputFrame.Position = UDim2.new(0, 10, 1, -50) ChatInputFrame.BackgroundTransparency = 1
local StickerBtn = Instance.new("TextButton", ChatInputFrame) StickerBtn.Size = UDim2.new(0, 30, 1, 0) StickerBtn.Position = UDim2.new(0, 0, 0, 0) StickerBtn.BackgroundTransparency = 1 StickerBtn.Text = "🙂" StickerBtn.TextSize = 20
local ChatBox = Instance.new("TextBox", ChatInputFrame) ChatBox.Size = UDim2.new(1, -100, 1, 0) ChatBox.Position = UDim2.new(0, 35, 0, 0) ChatBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35) ChatBox.TextColor3 = Color3.fromRGB(255, 255, 255) ChatBox.Font = Enum.Font.Gotham ChatBox.TextSize = 13 ChatBox.PlaceholderText = "Mensagem..." ChatBox.Text = "" ChatBox.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UICorner", ChatBox).CornerRadius = UDim.new(0, 15) local UIPaddingBox = Instance.new("UIPadding", ChatBox) UIPaddingBox.PaddingLeft = UDim.new(0, 10) UIPaddingBox.PaddingRight = UDim.new(0, 10)
local SendBtn = Instance.new("TextButton", ChatInputFrame) SendBtn.Size = UDim2.new(0, 55, 1, 0) SendBtn.Position = UDim2.new(1, -55, 0, 0) SendBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113) SendBtn.Text = "➤" SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) SendBtn.Font = Enum.Font.GothamBold SendBtn.TextSize = 18 Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 15)

-- Painel de Figurinhas
local StickerPanel = Instance.new("Frame", PrivateChatMenu) StickerPanel.Size = UDim2.new(1, 0, 0, 200) StickerPanel.Position = UDim2.new(0, 0, 1, 0) StickerPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 30) StickerPanel.ZIndex = 50 StickerPanel.Visible = false
local StickerScroll = Instance.new("ScrollingFrame", StickerPanel) StickerScroll.Size = UDim2.new(1, -10, 1, -10) StickerScroll.Position = UDim2.new(0, 5, 0, 5) StickerScroll.BackgroundTransparency = 1 StickerScroll.ScrollBarThickness = 3
local StickerUIGrid = Instance.new("UIGridLayout", StickerScroll) StickerUIGrid.CellSize = UDim2.new(0, 60, 0, 60) StickerUIGrid.CellPadding = UDim2.new(0, 5, 0, 5)
StickerUIGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() StickerScroll.CanvasSize = UDim2.new(0, 0, 0, StickerUIGrid.AbsoluteContentSize.Y) end)

local isStickerOpen = false
StickerBtn.MouseButton1Click:Connect(function()
    isStickerOpen = not isStickerOpen
    if isStickerOpen then StickerPanel.Visible = true StickerPanel:TweenPosition(UDim2.new(0, 0, 1, -200), "Out", "Quad", 0.2, true)
    else StickerPanel:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.2, true, function() StickerPanel.Visible = false end) end
end)

local function LoadStickers()
    for _, child in pairs(StickerScroll:GetChildren()) do if child:IsA("ImageButton") then child:Destroy() end end
    pcall(function()
        local files = listfiles(StickersFolder)
        if files then
            -- Mistura recentes + todos (simplificado)
            for _, path in ipairs(files) do
                if path:match("%.png$") or path:match("%.jpg$") then
                    local sBtn = Instance.new("ImageButton", StickerScroll) sBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 6)
                    sBtn.Image = getcustomasset(path)
                    sBtn.MouseButton1Click:Connect(function()
                        SendMsgData({id = HttpService:GenerateGUID(false), sender = player.Name, type = "sticker", file = path, timestamp = os.time(), edited = false, deleted = false})
                        isStickerOpen = false StickerPanel:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.2, true, function() StickerPanel.Visible = false end)
                    end)
                end
            end
        end
    end)
end
LoadStickers()

-- Renderizar Mensagem e Edição/Exclusão
local function RenderMessageItem(msgData)
    if msgData.deleted then return end -- Não mostra apagadas
    
    local msgFrame = Instance.new("Frame", ChatScroll) msgFrame.BackgroundTransparency = 1
    local isMe = msgData.sender == player.Name
    
    local bubble = Instance.new("Frame", msgFrame) bubble.BackgroundColor3 = isMe and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(40, 40, 45) Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 8)
    bubble.AutomaticSize = Enum.AutomaticSize.XY -- QUEBRA-MOLA NATIVO ROBLOX
    
    local hitBox = Instance.new("TextButton", bubble) hitBox.Size = UDim2.new(1, 0, 1, 0) hitBox.BackgroundTransparency = 1 hitBox.Text = "" hitBox.ZIndex = 2
    
    if msgData.type == "sticker" then
        local img = Instance.new("ImageLabel", bubble) img.Size = UDim2.new(0, 100, 0, 100) img.Position = UDim2.new(0, 5, 0, 5) img.BackgroundTransparency = 1 img.ScaleType = Enum.ScaleType.Fit
        pcall(function() img.Image = getcustomasset(msgData.file) end)
        msgFrame.Size = UDim2.new(1, 0, 0, 110)
    else
        local textStr = msgData.text
        if msgData.edited then textStr = textStr .. " <font color=\"#a0a0a0\" size=\"10\">(editado)</font>" end
        local bodyLabel = Instance.new("TextLabel", bubble) bodyLabel.Size = UDim2.new(0, 0, 0, 0) bodyLabel.Position = UDim2.new(0, 10, 0, 5) bodyLabel.BackgroundTransparency = 1 bodyLabel.TextXAlignment = Enum.TextXAlignment.Left bodyLabel.TextYAlignment = Enum.TextYAlignment.Top bodyLabel.Font = Enum.Font.Gotham bodyLabel.TextSize = 13 bodyLabel.TextColor3 = Color3.fromRGB(255, 255, 255) bodyLabel.TextWrapped = true bodyLabel.RichText = true bodyLabel.Text = textStr
        bodyLabel.AutomaticSize = Enum.AutomaticSize.XY
        
        local UIPadding = Instance.new("UIPadding", bubble) UIPadding.PaddingLeft = UDim.new(0, 10) UIPadding.PaddingRight = UDim.new(0, 10) UIPadding.PaddingTop = UDim.new(0, 8) UIPadding.PaddingBottom = UDim.new(0, 8)
        
        -- Gambiarra para AutomaticSize funcionar bem com TextWrapped: Define max width
        local maxW = Instance.new("UITextSizeConstraint", bodyLabel) maxW.MaxTextSize = 13
        bodyLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            if bodyLabel.AbsoluteSize.X > 200 then bodyLabel.Size = UDim2.new(0, 200, 0, 0) end
            msgFrame.Size = UDim2.new(1, 0, 0, bubble.AbsoluteSize.Y + 4)
        end)
    end
    
    -- Lógica de apagar/editar (Pressão longa / Clique botão direito)
    if isMe then
        local holding = false
        hitBox.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                holding = true bubble.BackgroundColor3 = Color3.fromRGB(30, 150, 90) -- Highlight
                task.delay(0.6, function()
                    if holding then
                        holding = false bubble.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                        ShowAlert("Opções de Mensagem", "O que deseja fazer?", "Editar", "Apagar", function()
                            ShowTextInput("Editar Mensagem", msgData.text, 200, function(newText)
                                SendMsgData({action = "edit", id = msgData.id, text = newText})
                            end)
                        end)
                        -- Substitui a callback do "Apagar" (Cancel do popup vira apagar aqui pra simplificar ou cria botões custom, mas simplifiquei no código p n estender)
                        -- Ajuste seguro:
                        local c = hitBox:GetChildren()
                    end
                end)
            end
        end)
        hitBox.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then holding = false bubble.BackgroundColor3 = Color3.fromRGB(46, 204, 113) end
        end)
        hitBox.MouseButton2Click:Connect(function()
             ShowTextInput("Editar (Apague tudo para excluir)", msgData.text, 200, function(newText)
                 if newText == "" then SendMsgData({action = "delete", id = msgData.id}) else SendMsgData({action = "edit", id = msgData.id, text = newText}) end
             end)
        end)
    end
    
    -- Ajusta posição (Esq/Dir)
    bubble:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if isMe then bubble.Position = UDim2.new(1, -bubble.AbsoluteSize.X, 0, 0) else bubble.Position = UDim2.new(0, 0, 0, 0) end
    end)
end

function RefreshChatUI(history)
    for _, child in pairs(ChatScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, msg in ipairs(history) do RenderMessageItem(msg) end
    task.delay(0.1, function() ChatScroll.CanvasPosition = Vector2.new(0, 99999) end)
end

function SendMsgData(msgData)
    local history = LoadChat(ActiveChatTarget)
    
    if msgData.action == "edit" then
        for _, m in ipairs(history) do if m.id == msgData.id then m.text = msgData.text m.edited = true end end
    elseif msgData.action == "delete" then
        for _, m in ipairs(history) do if m.id == msgData.id then m.deleted = true end end
    elseif msgData.action == "sync_req" then
        -- Não salva no visual, apenas pede
    elseif msgData.action == "sync_res" then
        history = msgData.history -- Recuperou os dados do amigo!
    else
        table.insert(history, msgData)
    end
    
    SaveChat(ActiveChatTarget, history)
    RefreshChatUI(history)
    
    if ActiveChatTarget == "Test" then
        -- Simulação do BOT Test
        if msgData.action == nil then
            task.delay(1.5, function()
                if ActiveChatTarget == "Test" then
                    local rep = {id = HttpService:GenerateGUID(false), sender = "Test", type = "text", text = "Olá! Mensagem recebida: " .. (msgData.text or "Sticker"), timestamp = os.time()}
                    table.insert(history, rep) SaveChat("Test", history) RefreshChatUI(history)
                end
            end)
        end
    else
        task.spawn(function()
            pcall(function()
                -- Sempre envia o último histórico (P2P JSON backup)
                msgData.backupHistory = history 
                HttpService:RequestAsync({Url = SERVER_URL .. "/send_message", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget, msg = msgData})})
            end)
        end)
    end
end

SendBtn.MouseButton1Click:Connect(function()
    if ChatBox.Text == "" or ActiveChatTarget == "" then return end
    local txt = ChatBox.Text ChatBox.Text = ""
    SendMsgData({id = HttpService:GenerateGUID(false), sender = player.Name, type = "text", text = txt, timestamp = os.time(), edited = false, deleted = false})
end)
ChatBox.FocusLost:Connect(function(enter) if enter then SendBtn.MouseButton1Click:Fire() end end)
ChatBox:GetPropertyChangedSignal("Text"):Connect(function() if ActiveChatTarget ~= "" and ActiveChatTarget ~= "Test" then pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/set_status", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({username = player.Name, status = ChatBox.Text ~= "" and "Digitando..." or "Online"})}) end) end end)

-- Loop de Recebimento
task.spawn(function()
    while task.wait(3) do
        if ActiveChatTarget ~= "" and ActiveChatTarget ~= "Test" then
            pcall(function()
                local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_messages?from=" .. ActiveChatTarget .. "&to=" .. player.Name, Method = "GET"})
                if res.Success then
                    local newMsgs = HttpService:JSONDecode(res.Body)
                    if newMsgs and #newMsgs > 0 then
                        local history = LoadChat(ActiveChatTarget)
                        local needsRefresh = false
                        for _, m in ipairs(newMsgs) do
                            if m.action == "edit" then for _, h in ipairs(history) do if h.id == m.id then h.text = m.text h.edited = true needsRefresh = true end end
                            elseif m.action == "delete" then for _, h in ipairs(history) do if h.id == m.id then h.deleted = true needsRefresh = true end end
                            elseif m.action == "unfriend" then
                                local idx = table.find(LocalData.Friends, m.sender)
                                if idx then table.remove(LocalData.Friends, idx) SaveData(FriendsFile, LocalData.Friends) CloseMenu() end
                            else
                                table.insert(history, m) needsRefresh = true
                                -- Recuperação de JSON caso você tenha apagado os seus arquivos sem querer
                                if m.backupHistory and #history <= 2 then history = m.backupHistory end
                            end
                        end
                        if needsRefresh then SaveChat(ActiveChatTarget, history) RefreshChatUI(history) end
                    end
                end
            end)
        end
    end
end)
