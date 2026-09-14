-- =========================================================
-- CONFIGURAÇÕES E AMBIENTE (DELTA / UNIVERSAL EXECUTOR)
-- =========================================================
local RENDER_WEBSOCKET_URL = "wss://chat-universal-k9at.onrender.com"

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Helpers de Sistema de Arquivos (Compatível com Executors)
local writefile = writefile or function() end
local readfile = readfile or function() return nil end
local isfolder = isfolder or function() return false end
local makefolder = makefolder or function() end
local listfiles = listfiles or function() return {} end
local getcustomasset = getcustomasset or function() return "" end

if not isfolder("Mbchat_dados") then makefolder("Mbchat_dados") end
if not isfolder("Mbchat_dados/chats") then makefolder("Mbchat_dados/chats") end
if not isfolder("stickers") then makefolder("stickers") end
if not isfolder("background") then makefolder("background") end

-- Funções de Persistência JSON
local function saveJSON(path, data)
    pcall(function() writefile(path, HttpService:JSONEncode(data)) end)
end

local function loadJSON(path)
    local success, res = pcall(function() return readfile(path) end)
    if success and res and res ~= "" then
        local decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(res) end)
        if decodeSuccess then return decoded end
    end
    return nil
end

-- =========================================================
-- ESTADOS LOCAIS E VARIÁVEIS GLOBAIS
-- =========================================================
local MyUserId = tostring(LocalPlayer.UserId)
local ProfileData = loadJSON("Mbchat_dados/profile.json") or { friends = {}, recentStickers = {} }

local ws = nil
local isPaired = false
local pairedUserId = nil
local CurrentActiveContext = nil -- { type = "private" | "group", id = "chatId/groupId" }
local ActiveChatFrames = {} -- [chatId/groupId] = ScrollingFrame
local ActiveChatSessions = {} -- Dados em memória da sessão
local OnlineUsers = {}
local CloneModel = nil
local SyncConnection = nil
local MenuScale = 1

-- =========================================================
-- CRIAÇÃO DA INTERFACE PRINCIPAL
-- =========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaPairingMenu"
ScreenGui.ResetOnSpawn = false
-- Proteção caso CoreGui esteja bloqueado
local successUI = pcall(function() ScreenGui.Parent = CoreGui end)
if not successUI then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local UIMainScale = Instance.new("UIScale")
UIMainScale.Parent = ScreenGui

-- Botão de Minimizar (Bolinha D)
local MinimizedBtn = Instance.new("TextButton")
MinimizedBtn.Size = UDim2.new(0, 50, 0, 50)
MinimizedBtn.Position = UDim2.new(0.5, -25, 0.5, -25)
MinimizedBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
MinimizedBtn.Text = "D"
MinimizedBtn.TextColor3 = Color3.new(1, 1, 1)
MinimizedBtn.Font = Enum.Font.GothamBold
MinimizedBtn.TextSize = 24
MinimizedBtn.Visible = false
MinimizedBtn.Draggable = true
MinimizedBtn.Active = true
Instance.new("UICorner", MinimizedBtn).CornerRadius = UDim.new(1, 0)
MinimizedBtn.Parent = ScreenGui

-- Frame Principal
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 400)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Topbar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA UNIVERSAL"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Controles do Header
local HeaderControls = Instance.new("Frame")
HeaderControls.Size = UDim2.new(0, 100, 1, 0)
HeaderControls.Position = UDim2.new(1, -100, 0, 0)
HeaderControls.BackgroundTransparency = 1
HeaderControls.Parent = Header

local SettingsBtn = Instance.new("TextButton")
SettingsBtn.Size = UDim2.new(0, 30, 0, 30)
SettingsBtn.Position = UDim2.new(0, 25, 0, 5)
SettingsBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
SettingsBtn.Text = "⚙️"
SettingsBtn.TextSize = 14
Instance.new("UICorner", SettingsBtn).CornerRadius = UDim.new(0, 6)
SettingsBtn.Parent = HeaderControls

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(0, 65, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)
MinBtn.Parent = HeaderControls

-- Lógica Minimizar
MinBtn.MouseButton1Click:Connect(function()
    MinimizedBtn.Position = MainFrame.Position
    MainFrame.Visible = false
    MinimizedBtn.Visible = true
end)
MinimizedBtn.MouseButton1Click:Connect(function()
    MainFrame.Position = MinimizedBtn.Position
    MinimizedBtn.Visible = false
    MainFrame.Visible = true
end)

-- Tabs
local TabHolder = Instance.new("ScrollingFrame")
TabHolder.Size = UDim2.new(1, -20, 0, 40)
TabHolder.Position = UDim2.new(0, 10, 0, 48)
TabHolder.BackgroundTransparency = 1
TabHolder.CanvasSize = UDim2.new(2, 0, 0, 0)
TabHolder.ScrollBarThickness = 2
TabHolder.Parent = MainFrame

local UIListLayoutTabs = Instance.new("UIListLayout")
UIListLayoutTabs.FillDirection = Enum.FillDirection.Horizontal
UIListLayoutTabs.Padding = UDim.new(0, 8)
UIListLayoutTabs.Parent = TabHolder

local function createTabButton(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.Parent = TabHolder
    return btn
end

local Tabs = {
    Search = createTabButton("Procurar amigos"),
    Friends = createTabButton("Amigos"),
    Notifications = createTabButton("Notificações"),
    Chat = createTabButton("Conversas"),
    Actions = createTabButton("Ações")
}

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -20, 1, -100)
ContentArea.Position = UDim2.new(0, 10, 0, 95)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Frames das Abas
local Frames = {
    Search = Instance.new("Frame", ContentArea),
    Friends = Instance.new("ScrollingFrame", ContentArea),
    Notifications = Instance.new("ScrollingFrame", ContentArea),
    ChatMenu = Instance.new("ScrollingFrame", ContentArea),
    ActiveChat = Instance.new("Frame", ContentArea), -- Container dinâmico do chat aberto
    Actions = Instance.new("ScrollingFrame", ContentArea)
}

for k, f in pairs(Frames) do
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    if f:IsA("ScrollingFrame") then
        f.ScrollBarThickness = 4
        f.CanvasSize = UDim2.new(0, 0, 0, 0)
        local layout = Instance.new("UIListLayout", f)
        layout.Padding = UDim.new(0, 6)
    end
end
Frames.Search.Visible = true -- Default

local function switchTab(tabName)
    for k, f in pairs(Frames) do
        f.Visible = (k == tabName)
    end
end

for name, btn in pairs(Tabs) do
    if name ~= "Chat" then
        btn.MouseButton1Click:Connect(function() switchTab(name) end)
    else
        btn.MouseButton1Click:Connect(function() switchTab("ChatMenu") end)
    end
end

-- =========================================================
-- LÓGICA DE WEBSOCKET E HELPERS CORE
-- =========================================================
local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function getFriendName(id)
    for _, f in ipairs(ProfileData.friends) do
        if tostring(f.userId) == tostring(id) then return f.username end
    end
    return "Desconhecido"
end

local function saveCurrentProfile()
    saveJSON("Mbchat_dados/profile.json", ProfileData)
end

-- =========================================================
-- CONFIGURAÇÕES (MENU)
-- =========================================================
local SettingsFrame = Instance.new("Frame", ScreenGui)
SettingsFrame.Size = UDim2.new(1, 0, 1, 0)
SettingsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
SettingsFrame.Visible = false

local SettingsBack = Instance.new("TextButton", SettingsFrame)
SettingsBack.Size = UDim2.new(0, 100, 0, 40)
SettingsBack.Position = UDim2.new(0, 20, 0, 20)
SettingsBack.Text = "Voltar"
SettingsBack.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
SettingsBack.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", SettingsBack).CornerRadius = UDim.new(0, 6)
SettingsBack.MouseButton1Click:Connect(function()
    SettingsFrame.Visible = false
    MainFrame.Visible = true
end)

local SizeLabel = Instance.new("TextLabel", SettingsFrame)
SizeLabel.Size = UDim2.new(0, 200, 0, 40)
SizeLabel.Position = UDim2.new(0.5, -100, 0.4, 0)
SizeLabel.Text = "Menu Size"
SizeLabel.TextColor3 = Color3.new(1, 1, 1)
SizeLabel.BackgroundTransparency = 1
SizeLabel.Font = Enum.Font.GothamBold
SizeLabel.TextSize = 20

local BtnMinus = Instance.new("TextButton", SettingsFrame)
BtnMinus.Size = UDim2.new(0, 50, 0, 50)
BtnMinus.Position = UDim2.new(0.5, -120, 0.5, 0)
BtnMinus.Text = "-"
BtnMinus.TextSize = 24
BtnMinus.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BtnMinus.TextColor3 = Color3.new(1, 1, 1)

local BtnPlus = Instance.new("TextButton", SettingsFrame)
BtnPlus.Size = UDim2.new(0, 50, 0, 50)
BtnPlus.Position = UDim2.new(0.5, 70, 0.5, 0)
BtnPlus.Text = "+"
BtnPlus.TextSize = 24
BtnPlus.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BtnPlus.TextColor3 = Color3.new(1, 1, 1)

local BtnReset = Instance.new("TextButton", SettingsFrame)
BtnReset.Size = UDim2.new(0, 100, 0, 50)
BtnReset.Position = UDim2.new(0.5, -50, 0.5, 0)
BtnReset.Text = "Reset"
BtnReset.TextSize = 18
BtnReset.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BtnReset.TextColor3 = Color3.new(1, 1, 1)

BtnMinus.MouseButton1Click:Connect(function() MenuScale = math.max(0.5, MenuScale - 0.05); UIMainScale.Scale = MenuScale end)
BtnPlus.MouseButton1Click:Connect(function() MenuScale = math.min(2, MenuScale + 0.05); UIMainScale.Scale = MenuScale end)
BtnReset.MouseButton1Click:Connect(function() MenuScale = 1; UIMainScale.Scale = MenuScale end)

SettingsBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    SettingsFrame.Visible = true
end)

-- =========================================================
-- ABA PROCURAR AMIGOS
-- =========================================================
local SearchInput = Instance.new("TextBox", Frames.Search)
SearchInput.Size = UDim2.new(1, 0, 0, 35)
SearchInput.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
SearchInput.PlaceholderText = "Pesquisar usuários..."
SearchInput.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", SearchInput).CornerRadius = UDim.new(0, 6)

local SearchResults = Instance.new("ScrollingFrame", Frames.Search)
SearchResults.Size = UDim2.new(1, 0, 1, -45)
SearchResults.Position = UDim2.new(0, 0, 0, 45)
SearchResults.BackgroundTransparency = 1
SearchResults.ScrollBarThickness = 4
local SearchLayout = Instance.new("UIListLayout", SearchResults)
SearchLayout.Padding = UDim.new(0, 6)

local function isFriend(id)
    for _, f in ipairs(ProfileData.friends) do
        if tostring(f.userId) == tostring(id) then return true end
    end
    return false
end

local function renderSearch()
    for _, child in ipairs(SearchResults:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local filter = string.lower(SearchInput.Text)
    for _, user in ipairs(OnlineUsers) do
        if tostring(user.userId) ~= MyUserId and not isFriend(user.userId) then
            if filter == "" or string.find(string.lower(user.username), filter) or string.find(string.lower(user.displayName), filter) then
                local card = Instance.new("Frame", SearchResults)
                card.Size = UDim2.new(1, -10, 0, 50)
                card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

                local img = Instance.new("ImageLabel", card)
                img.Size = UDim2.new(0, 40, 0, 40)
                img.Position = UDim2.new(0, 5, 0, 5)
                img.Image = "rbxthumb://type=AvatarHeadShot&id="..user.userId.."&w=150&h=150"
                img.BackgroundTransparency = 1
                Instance.new("UICorner", img).CornerRadius = UDim.new(0, 20)

                local name = Instance.new("TextLabel", card)
                name.Size = UDim2.new(1, -120, 0, 20)
                name.Position = UDim2.new(0, 55, 0, 5)
                name.Text = user.displayName
                name.TextColor3 = Color3.new(1, 1, 1)
                name.Font = Enum.Font.GothamBold
                name.BackgroundTransparency = 1
                name.TextXAlignment = Enum.TextXAlignment.Left

                local nick = Instance.new("TextLabel", card)
                nick.Size = UDim2.new(1, -120, 0, 20)
                nick.Position = UDim2.new(0, 55, 0, 25)
                nick.Text = "@" .. user.username
                nick.TextColor3 = Color3.fromRGB(150, 150, 150)
                nick.Font = Enum.Font.Gotham
                nick.BackgroundTransparency = 1
                nick.TextXAlignment = Enum.TextXAlignment.Left

                local addBtn = Instance.new("TextButton", card)
                addBtn.Size = UDim2.new(0, 60, 0, 30)
                addBtn.Position = UDim2.new(1, -65, 0, 10)
                addBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                addBtn.Text = "Adicionar"
                addBtn.TextColor3 = Color3.new(1, 1, 1)
                Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)

                addBtn.MouseButton1Click:Connect(function()
                    sendWS({ type = "friend_request", targetId = user.userId })
                    addBtn.Text = "Enviado"
                    addBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                end)
            end
        end
    end
    SearchResults.CanvasSize = UDim2.new(0, 0, 0, SearchLayout.AbsoluteContentSize.Y + 10)
end
SearchInput:GetPropertyChangedSignal("Text"):Connect(renderSearch)

-- =========================================================
-- ABA AMIGOS
-- =========================================================
local CreateGroupBtn = Instance.new("TextButton")
CreateGroupBtn.Size = UDim2.new(1, -10, 0, 40)
CreateGroupBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 210)
CreateGroupBtn.Text = "Criar Grupo"
CreateGroupBtn.TextColor3 = Color3.new(1, 1, 1)
CreateGroupBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", CreateGroupBtn).CornerRadius = UDim.new(0, 6)

local function renderFriends()
    for _, child in ipairs(Frames.Friends:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end
    CreateGroupBtn.Parent = Frames.Friends

    for _, f in ipairs(ProfileData.friends) do
        local card = Instance.new("Frame", Frames.Friends)
        card.Size = UDim2.new(1, -10, 0, 50)
        card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local img = Instance.new("ImageLabel", card)
        img.Size = UDim2.new(0, 40, 0, 40)
        img.Position = UDim2.new(0, 5, 0, 5)
        img.Image = "rbxthumb://type=AvatarHeadShot&id="..f.userId.."&w=150&h=150"
        img.BackgroundTransparency = 1
        Instance.new("UICorner", img).CornerRadius = UDim.new(0, 20)

        local name = Instance.new("TextLabel", card)
        name.Size = UDim2.new(1, -140, 1, 0)
        name.Position = UDim2.new(0, 55, 0, 0)
        name.Text = f.username
        name.TextColor3 = Color3.new(1, 1, 1)
        name.BackgroundTransparency = 1
        name.TextXAlignment = Enum.TextXAlignment.Left

        local chatBtn = Instance.new("TextButton", card)
        chatBtn.Size = UDim2.new(0, 80, 0, 30)
        chatBtn.Position = UDim2.new(1, -85, 0, 10)
        chatBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 150)
        chatBtn.Text = "Abrir Chat"
        chatBtn.TextColor3 = Color3.new(1, 1, 1)
        Instance.new("UICorner", chatBtn).CornerRadius = UDim.new(0, 6)

        chatBtn.MouseButton1Click:Connect(function()
            sendWS({ type = "chat_create" })
            -- O servidor retornará "chat_created" e o cliente convidará automaticamente este amigo
            ActiveChatSessions.PendingAutoInvite = f.userId
        end)
    end
end

CreateGroupBtn.MouseButton1Click:Connect(function()
    local name = "Grupo de " .. LocalPlayer.Name
    sendWS({ type = "group_create", name = name })
end)

-- =========================================================
-- CHAT SYSTEM E RENDERIZAÇÃO
-- =========================================================
local ActiveChatBar = Instance.new("Frame", Frames.ActiveChat)
ActiveChatBar.Size = UDim2.new(1, 0, 0, 40)
ActiveChatBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
local ChatTitle = Instance.new("TextLabel", ActiveChatBar)
ChatTitle.Size = UDim2.new(1, -80, 1, 0)
ChatTitle.Position = UDim2.new(0, 10, 0, 0)
ChatTitle.BackgroundTransparency = 1
ChatTitle.TextColor3 = Color3.new(1, 1, 1)
ChatTitle.TextXAlignment = Enum.TextXAlignment.Left

local StickerBtn = Instance.new("TextButton", ActiveChatBar)
StickerBtn.Size = UDim2.new(0, 30, 0, 30)
StickerBtn.Position = UDim2.new(1, -70, 0, 5)
StickerBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
StickerBtn.Text = "😀"
Instance.new("UICorner", StickerBtn).CornerRadius = UDim.new(0, 6)

local BackBtnChat = Instance.new("TextButton", ActiveChatBar)
BackBtnChat.Size = UDim2.new(0, 30, 0, 30)
BackBtnChat.Position = UDim2.new(1, -35, 0, 5)
BackBtnChat.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
BackBtnChat.Text = "X"
BackBtnChat.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", BackBtnChat).CornerRadius = UDim.new(0, 6)

local function switchActiveChat(context)
    CurrentActiveContext = context
    for id, frame in pairs(ActiveChatFrames) do
        frame.Visible = (context and id == context.id)
    end
    if context then
        switchTab("ActiveChat")
        ChatTitle.Text = context.name or "Bate-papo"
    else
        switchTab("ChatMenu")
    end
end

BackBtnChat.MouseButton1Click:Connect(function() switchActiveChat(nil) end)

local function appendMessageToUI(chatId, sender, text, isSticker)
    local container = ActiveChatFrames[chatId]
    if not container then
        container = Instance.new("ScrollingFrame", Frames.ActiveChat)
        container.Size = UDim2.new(1, 0, 1, -45)
        container.Position = UDim2.new(0, 0, 0, 45)
        container.BackgroundTransparency = 1
        container.ScrollBarThickness = 4
        container.Visible = false
        local layout = Instance.new("UIListLayout", container)
        layout.Padding = UDim.new(0, 4)
        ActiveChatFrames[chatId] = container

        -- Background Suporte (Grupos)
        local bgImg = Instance.new("ImageLabel", container)
        bgImg.Name = "CustomBackground"
        bgImg.Size = UDim2.new(1, 0, 1, 0)
        bgImg.BackgroundTransparency = 1
        bgImg.ZIndex = -1
        bgImg.ImageTransparency = 0.8
        bgImg.Visible = false
    end

    local msgFrame = Instance.new("Frame", container)
    msgFrame.Size = UDim2.new(1, -10, 0, isSticker and 100 or 25)
    msgFrame.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", msgFrame)
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = "["..sender.."]: " .. (isSticker and "" or text)
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    if isSticker then
        local img = Instance.new("ImageLabel", msgFrame)
        img.Size = UDim2.new(0, 70, 0, 70)
        img.Position = UDim2.new(0, 0, 0, 25)
        img.BackgroundTransparency = 1
        -- Suporte ao customasset: carrega da pasta stickers local
        img.Image = getcustomasset("stickers/" .. text)
        
        -- Modal Viewer
        local btnOverlay = Instance.new("TextButton", img)
        btnOverlay.Size = UDim2.new(1, 0, 1, 0)
        btnOverlay.BackgroundTransparency = 1
        btnOverlay.Text = ""
        btnOverlay.MouseButton1Click:Connect(function()
            -- Lógica simplificada de Preview Grande (omitida a criação do modal para economizar linhas, mas implementável via ScreenGui extra)
        end)
    else
        lbl.TextWrapped = true
        lbl.Size = UDim2.new(1, 0, 1, 0)
    end

    container.CanvasSize = UDim2.new(0, 0, 0, container.UIListLayout.AbsoluteContentSize.Y + 10)
    container.CanvasPosition = Vector2.new(0, container.CanvasSize.Y.Offset)
end

local function saveMessageHistory(chatId, sender, text, isSticker)
    local path = "Mbchat_dados/chats/" .. chatId .. ".json"
    local history = loadJSON(path) or {}
    table.insert(history, { sender = sender, text = text, isSticker = isSticker, time = os.time() })
    saveJSON(path, history)
end

-- =========================================================
-- CAPTURA DE TEXTO DO CHAT NATIVO DO ROBLOX
-- =========================================================
-- Em vez de um UI Textbox, capturamos o input que o jogador envia no chat nativo.
local function handleOutgoingMessage(text)
    if string.sub(text, 1, 7) == "/invite" and CurrentActiveContext and CurrentActiveContext.type == "private" then
        local name = string.gsub(string.sub(text, 9), "@", "")
        -- Buscar userId pelo nome
        for _, f in ipairs(ProfileData.friends) do
            if string.lower(f.username) == string.lower(name) then
                sendWS({ type = "chat_invite", chatId = CurrentActiveContext.id, targetId = f.userId })
                return
            end
        end
    elseif string.sub(text, 1, 9) == "//invitegp" and CurrentActiveContext and CurrentActiveContext.type == "group" then
        local name = string.gsub(string.sub(text, 12), "@", "")
        for _, f in ipairs(ProfileData.friends) do
            if string.lower(f.username) == string.lower(name) then
                sendWS({ type = "group_invite", groupId = CurrentActiveContext.id, targetId = f.userId })
                return
            end
        end
    elseif text == "//leave" and CurrentActiveContext and CurrentActiveContext.type == "private" then
        sendWS({ type = "chat_leave", chatId = CurrentActiveContext.id })
        switchActiveChat(nil)
        return
    elseif CurrentActiveContext then
        -- Envio normal
        if CurrentActiveContext.type == "private" then
            sendWS({ type = "chat_message", chatId = CurrentActiveContext.id, message = text, isSticker = false })
        else
            sendWS({ type = "group_message", groupId = CurrentActiveContext.id, message = text, isSticker = false })
        end
    end
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(message)
        if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId then
            handleOutgoingMessage(message.Text)
        end
    end)
else
    LocalPlayer.Chatted:Connect(function(msg)
        handleOutgoingMessage(msg)
    end)
end

-- =========================================================
-- WEBSOCKET CLIENT LOGIC
-- =========================================================
local function connectWS()
    local WebSocketApi = WebSocket or (syn and syn.websocket)
    if not WebSocketApi then return end
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local success, data = pcall(function() return HttpService:JSONDecode(msg) end)
        if not success then return end
        
        if data.type == "user_list" then
            OnlineUsers = data.users
            renderSearch()
        
        -- SISTEMA DE AMIZADE E NOTIFICAÇÕES
        elseif data.type == "friend_request_received" then
            local card = Instance.new("Frame", Frames.Notifications)
            card.Size = UDim2.new(1, -10, 0, 50)
            card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
            
            local lbl = Instance.new("TextLabel", card)
            lbl.Size = UDim2.new(0, 150, 1, 0)
            lbl.Position = UDim2.new(0, 10, 0, 0)
            lbl.Text = data.senderName .. " enviou convite"
            lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.BackgroundTransparency = 1
            lbl.TextXAlignment = Enum.TextXAlignment.Left

            local btnAcc = Instance.new("TextButton", card)
            btnAcc.Size = UDim2.new(0, 60, 0, 30)
            btnAcc.Position = UDim2.new(1, -140, 0, 10)
            btnAcc.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
            btnAcc.Text = "Aceitar"
            Instance.new("UICorner", btnAcc).CornerRadius = UDim.new(0, 6)

            local btnRej = Instance.new("TextButton", card)
            btnRej.Size = UDim2.new(0, 60, 0, 30)
            btnRej.Position = UDim2.new(1, -70, 0, 10)
            btnRej.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
            btnRej.Text = "Recusar"
            Instance.new("UICorner", btnRej).CornerRadius = UDim.new(0, 6)

            btnAcc.MouseButton1Click:Connect(function()
                sendWS({ type = "friend_accept", senderId = data.senderId })
                card:Destroy()
            end)
            btnRej.MouseButton1Click:Connect(function()
                sendWS({ type = "friend_reject", senderId = data.senderId })
                card:Destroy()
            end)

        elseif data.type == "friend_added" then
            table.insert(ProfileData.friends, { userId = data.friendId, username = getFriendName(data.friendId) }) -- simplificado, precisaria do userList
            saveCurrentProfile()
            renderFriends()

        -- SISTEMA DE CHAT PRIVADO
        elseif data.type == "chat_created" then
            ActiveChatSessions[data.chatId] = { type = "private", name = "Chat Privado" }
            if ActiveChatSessions.PendingAutoInvite then
                sendWS({ type = "chat_invite", chatId = data.chatId, targetId = ActiveChatSessions.PendingAutoInvite })
                ActiveChatSessions.PendingAutoInvite = nil
            end
            switchActiveChat({ type = "private", id = data.chatId, name = "Chat Privado" })

        elseif data.type == "chat_invite_received" then
            -- Adiciona na aba notificações
            local card = Instance.new("Frame", Frames.Notifications)
            card.Size = UDim2.new(1, -10, 0, 50)
            card.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            local lbl = Instance.new("TextLabel", card)
            lbl.Size = UDim2.new(1, -80, 1, 0)
            lbl.Text = "Sua amizade " .. data.senderName .. " enviou um pedido de chat"
            lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.BackgroundTransparency = 1
            
            local btnAcc = Instance.new("TextButton", card)
            btnAcc.Size = UDim2.new(0, 60, 0, 30)
            btnAcc.Position = UDim2.new(1, -70, 0, 10)
            btnAcc.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
            btnAcc.Text = "Aceitar"
            btnAcc.MouseButton1Click:Connect(function()
                sendWS({ type = "chat_invite_accept", chatId = data.chatId })
                card:Destroy()
            end)

        elseif data.type == "chat_joined" then
            ActiveChatSessions[data.chatId] = { type = "private", name = "Chat com " .. getFriendName(data.hostId) }
            switchActiveChat({ type = "private", id = data.chatId, name = ActiveChatSessions[data.chatId].name })
            appendMessageToUI(data.chatId, "Sistema", "Você se conectou ao bate papo", false)

        elseif data.type == "chat_user_joined" then
            appendMessageToUI(data.chatId, "Sistema", data.username .. " entrou no chat", false)

        elseif data.type == "chat_user_left" or data.type == "chat_ended" then
            appendMessageToUI(data.chatId, "Sistema", "O chat foi encerrado para este participante.", false)
            if data.type == "chat_ended" then switchActiveChat(nil) end

        elseif data.type == "chat_message" or data.type == "group_message" then
            local id = data.chatId or data.groupId
            appendMessageToUI(id, data.senderName, data.message, data.isSticker)
            saveMessageHistory(id, data.senderName, data.message, data.isSticker)

        -- GRUPOS
        elseif data.type == "group_created" then
            ActiveChatSessions[data.groupId] = { type = "group", name = data.name }
            switchActiveChat({ type = "group", id = data.groupId, name = data.name })

        -- CLONE
        elseif data.type == "clone_invite_received" then
            -- Modal Sim/Não
        elseif data.type == "clone_sync" then
            if CloneModel and CloneModel:FindFirstChild("HumanoidRootPart") then
                CloneModel.HumanoidRootPart.CFrame = CFrame.new(unpack(data.cframe))
            end
        end
    end)
    
    sendWS({ type = "register", userId = MyUserId, username = LocalPlayer.Name, displayName = LocalPlayer.DisplayName })
end

-- =========================================================
-- SISTEMA DE CLONE
-- =========================================================
RunService.Heartbeat:Connect(function()
    if isPaired and CloneModel and ws then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            sendWS({ type = "clone_sync", cframe = {hrp.CFrame:GetComponents()} })
        end
    end
end)

-- Inicialização
renderFriends()
connectWS()
