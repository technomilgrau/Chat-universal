-- ==========================================
-- CHAT UNIVERSAL - SCRIPT LUA (COMPLETO)
-- ==========================================

local WS_URL = "wss://chat-universal-online.onrender.com" -- ALTERE AQUI PARA SUA URL DO RENDER
local GITHUB_REPO = "technomilgrau/Chat-universal"
local GITHUB_API_URL = "https://api.github.com/repos/" .. GITHUB_REPO .. "/contents/Stickers"

-- Serviços
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Funcionalidades de Executor (Delta)
local requestFunc = (syn and syn.request) or request or http_request or (http and http.request)
local function getAsset(path) return getcustomasset(path) end

-- ==========================================
-- SISTEMA DE ARQUIVOS E JSON
-- ==========================================
local folderName = "Chat-universal"
local stickersFolder = folderName .. "/Stickers"

if not isfolder(folderName) then makefolder(folderName) end
if not isfolder(stickersFolder) then makefolder(stickersFolder) end

local dataFilePath = folderName .. "/chat_data_" .. tostring(LocalPlayer.UserId) .. ".json"

local localData = {
    friends = {},
    chats = {},
    recentStickers = {},
    pendingRequests = {}
}

local function saveJSON()
    local success, encoded = pcall(function() return HttpService:JSONEncode(localData) end)
    if success then
        writefile(dataFilePath, encoded)
        print("[ChatUniversal] JSON atualizado.")
    else
        warn("[ChatUniversal] Erro ao codificar JSON.")
    end
end

local function loadJSON()
    if isfile(dataFilePath) then
        local success, content = pcall(function() return readfile(dataFilePath) end)
        if success and content and content ~= "" then
            local decodedSuccess, decoded = pcall(function() return HttpService:JSONDecode(content) end)
            if decodedSuccess and type(decoded) == "table" then
                -- Merge defaults
                localData.friends = decoded.friends or {}
                localData.chats = decoded.chats or {}
                localData.recentStickers = decoded.recentStickers or {}
                localData.pendingRequests = decoded.pendingRequests or {}
                print("[ChatUniversal] Dados locais carregados com sucesso.")
                return
            end
        end
    end
    -- Se não existir ou corrompido, cria primeira execução
    print("[ChatUniversal] Criando novo arquivo de dados.")
    saveJSON()
end

loadJSON()

-- ==========================================
-- VARIÁVEIS DE ESTADO DO SISTEMA
-- ==========================================
local activeConnections = {} -- WebSocket
local currentActiveChat = nil -- UserId do amigo atual
local presenceCache = {} -- UserId -> "online" / "offline" / "digitando..."
local uiElements = {}
local fetchedStickers = {} -- Cache em memória dos nomes/urls das figurinhas
local processedMessageIds = {} -- Evitar duplicação imediata

-- ==========================================
-- UI BUILDER (DARK THEME MODERNO)
-- ==========================================
local Colors = {
    Background = Color3.fromRGB(18, 18, 18),
    Panel = Color3.fromRGB(28, 28, 28),
    LightGray = Color3.fromRGB(45, 45, 45),
    Blue = Color3.fromRGB(0, 122, 255),
    Text = Color3.fromRGB(240, 240, 240),
    SubText = Color3.fromRGB(160, 160, 160),
    Online = Color3.fromRGB(40, 200, 80)
}

-- Limpa UI anterior se existir
if CoreGui:FindFirstChild("ChatUniversalUI") then
    CoreGui.ChatUniversalUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatUniversalUI"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 380, 0, 600)
MainFrame.Position = UDim2.new(0.5, -190, 0.5, -300)
MainFrame.BackgroundColor3 = Colors.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 15)
UICorner.Parent = MainFrame

-- Títulos
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 15)
Title.BackgroundTransparency = 1
Title.Text = "Chat Universal"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22
Title.TextColor3 = Colors.Text
Title.Parent = MainFrame

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1, 0, 0, 20)
SubTitle.Position = UDim2.new(0, 0, 0, 45)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "techno_milgrau"
SubTitle.Font = Enum.Font.Gotham
Title.TextSize = 12
SubTitle.TextColor3 = Colors.SubText
SubTitle.Parent = MainFrame

-- Notificações (Sino)
local NotificationBtn = Instance.new("TextButton")
NotificationBtn.Size = UDim2.new(0, 40, 0, 40)
NotificationBtn.Position = UDim2.new(1, -50, 0, 15)
NotificationBtn.BackgroundTransparency = 1
NotificationBtn.Text = "🔔"
NotificationBtn.TextSize = 20
NotificationBtn.Parent = MainFrame

local NotificationBadge = Instance.new("Frame")
NotificationBadge.Size = UDim2.new(0, 15, 0, 15)
NotificationBadge.Position = UDim2.new(1, -15, 0, 0)
NotificationBadge.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
Instance.new("UICorner", NotificationBadge).CornerRadius = UDim.new(1, 0)
NotificationBadge.Parent = NotificationBtn
NotificationBadge.Visible = false

-- Tabs de Navegação
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 0, 50)
TabContainer.Position = UDim2.new(0, 0, 1, -50)
TabContainer.BackgroundColor3 = Colors.Panel
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Parent = TabContainer

local function createTabBtn(name, text, widthScale)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(widthScale, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.TextColor3 = Colors.SubText
    btn.Parent = TabContainer
    return btn
end

local TabInicioBtn = createTabBtn("Inicio", "🏠 Início", 0.5)
local TabMensagensBtn = createTabBtn("Mensagens", "💬 Mensagens", 0.5)

-- Containers de Conteúdo
local ContentInicio = Instance.new("ScrollingFrame")
ContentInicio.Size = UDim2.new(1, 0, 1, -120)
ContentInicio.Position = UDim2.new(0, 0, 0, 70)
ContentInicio.BackgroundTransparency = 1
ContentInicio.ScrollBarThickness = 2
ContentInicio.Parent = MainFrame
Instance.new("UIListLayout", ContentInicio).Padding = UDim.new(0, 10)

local ContentMensagens = Instance.new("ScrollingFrame")
ContentMensagens.Size = UDim2.new(1, 0, 1, -120)
ContentMensagens.Position = UDim2.new(0, 0, 0, 70)
ContentMensagens.BackgroundTransparency = 1
ContentMensagens.ScrollBarThickness = 2
ContentMensagens.Visible = false
ContentMensagens.Parent = MainFrame
Instance.new("UIListLayout", ContentMensagens).Padding = UDim.new(0, 10)

local ContentNotificacoes = Instance.new("ScrollingFrame")
ContentNotificacoes.Size = UDim2.new(1, 0, 1, -120)
ContentNotificacoes.Position = UDim2.new(0, 0, 0, 70)
ContentNotificacoes.BackgroundTransparency = 1
ContentNotificacoes.ScrollBarThickness = 2
ContentNotificacoes.Visible = false
ContentNotificacoes.Parent = MainFrame
Instance.new("UIListLayout", ContentNotificacoes).Padding = UDim.new(0, 10)

-- Barra de Pesquisa (Aba Início)
local SearchBar = Instance.new("TextBox")
SearchBar.Size = UDim2.new(0.9, 0, 0, 40)
SearchBar.Position = UDim2.new(0.05, 0, 0, 0)
SearchBar.BackgroundColor3 = Colors.LightGray
SearchBar.TextColor3 = Colors.Text
SearchBar.PlaceholderText = "procurar amigos"
SearchBar.Font = Enum.Font.Gotham
SearchBar.TextSize = 14
SearchBar.Parent = ContentInicio
Instance.new("UICorner", SearchBar).CornerRadius = UDim.new(0, 8)

local SearchResultsFrame = Instance.new("Frame")
SearchResultsFrame.Size = UDim2.new(1, 0, 0, 0)
SearchResultsFrame.BackgroundTransparency = 1
SearchResultsFrame.AutomaticSize = Enum.AutomaticSize.Y
SearchResultsFrame.Parent = ContentInicio
local SearchResultsLayout = Instance.new("UIListLayout")
SearchResultsLayout.Padding = UDim.new(0, 10)
SearchResultsLayout.Parent = SearchResultsFrame

-- ==========================================
-- CHAT PRIVADO & STICKERS UI (Imagens 2 e 3)
-- ==========================================
local ChatFrame = Instance.new("Frame")
ChatFrame.Size = UDim2.new(1, 0, 1, 0)
ChatFrame.Position = UDim2.new(1, 0, 0, 0) -- Fora da tela
ChatFrame.BackgroundColor3 = Colors.Background
ChatFrame.ZIndex = 10
ChatFrame.Parent = MainFrame

local ChatHeader = Instance.new("Frame")
ChatHeader.Size = UDim2.new(1, 0, 0, 70)
ChatHeader.BackgroundColor3 = Colors.Panel
ChatHeader.ZIndex = 11
ChatHeader.Parent = ChatFrame

local ChatBackBtn = Instance.new("TextButton")
ChatBackBtn.Size = UDim2.new(0, 40, 0, 40)
ChatBackBtn.Position = UDim2.new(0, 10, 0, 15)
ChatBackBtn.BackgroundTransparency = 1
ChatBackBtn.Text = "<"
ChatBackBtn.TextColor3 = Colors.Text
ChatBackBtn.TextSize = 24
ChatBackBtn.ZIndex = 12
ChatBackBtn.Parent = ChatHeader

local ChatHeaderAvatar = Instance.new("ImageLabel")
ChatHeaderAvatar.Size = UDim2.new(0, 40, 0, 40)
ChatHeaderAvatar.Position = UDim2.new(0, 50, 0, 15)
ChatHeaderAvatar.BackgroundColor3 = Colors.LightGray
Instance.new("UICorner", ChatHeaderAvatar).CornerRadius = UDim.new(1, 0)
ChatHeaderAvatar.ZIndex = 12
ChatHeaderAvatar.Parent = ChatHeader

local ChatHeaderName = Instance.new("TextLabel")
ChatHeaderName.Size = UDim2.new(0, 200, 0, 20)
ChatHeaderName.Position = UDim2.new(0, 100, 0, 15)
ChatHeaderName.BackgroundTransparency = 1
ChatHeaderName.Text = "Nome"
ChatHeaderName.Font = Enum.Font.GothamBold
ChatHeaderName.TextColor3 = Colors.Text
ChatHeaderName.TextSize = 16
ChatHeaderName.TextXAlignment = Enum.TextXAlignment.Left
ChatHeaderName.ZIndex = 12
ChatHeaderName.Parent = ChatHeader

local ChatHeaderStatus = Instance.new("TextLabel")
ChatHeaderStatus.Size = UDim2.new(0, 200, 0, 15)
ChatHeaderStatus.Position = UDim2.new(0, 100, 0, 38)
ChatHeaderStatus.BackgroundTransparency = 1
ChatHeaderStatus.Text = "offline"
ChatHeaderStatus.Font = Enum.Font.Gotham
ChatHeaderStatus.TextColor3 = Colors.SubText
ChatHeaderStatus.TextSize = 12
ChatHeaderStatus.TextXAlignment = Enum.TextXAlignment.Left
ChatHeaderStatus.ZIndex = 12
ChatHeaderStatus.Parent = ChatHeader

local MessagesScroll = Instance.new("ScrollingFrame")
MessagesScroll.Size = UDim2.new(1, 0, 1, -130)
MessagesScroll.Position = UDim2.new(0, 0, 0, 70)
MessagesScroll.BackgroundTransparency = 1
MessagesScroll.ScrollBarThickness = 2
MessagesScroll.ZIndex = 11
MessagesScroll.Parent = ChatFrame
local MsgListLayout = Instance.new("UIListLayout")
MsgListLayout.Padding = UDim.new(0, 10)
MsgListLayout.SortOrder = Enum.SortOrder.LayoutOrder
MsgListLayout.Parent = MessagesScroll

local InputArea = Instance.new("Frame")
InputArea.Size = UDim2.new(1, 0, 0, 60)
InputArea.Position = UDim2.new(0, 0, 1, -60)
InputArea.BackgroundColor3 = Colors.Panel
InputArea.ZIndex = 12
InputArea.Parent = ChatFrame

local ChatInput = Instance.new("TextBox")
ChatInput.Size = UDim2.new(0.65, 0, 0, 40)
ChatInput.Position = UDim2.new(0, 50, 0, 10)
ChatInput.BackgroundColor3 = Colors.LightGray
ChatInput.TextColor3 = Colors.Text
ChatInput.PlaceholderText = "Mensagem..."
ChatInput.Font = Enum.Font.Gotham
ChatInput.TextSize = 14
ChatInput.ClearTextOnFocus = false
ChatInput.ZIndex = 13
Instance.new("UICorner", ChatInput).CornerRadius = UDim.new(0, 20)
ChatInput.Parent = InputArea

local StickerBtn = Instance.new("TextButton")
StickerBtn.Size = UDim2.new(0, 30, 0, 30)
StickerBtn.Position = UDim2.new(0, 10, 0, 15)
StickerBtn.BackgroundTransparency = 1
StickerBtn.Text = "😀"
StickerBtn.TextSize = 20
StickerBtn.ZIndex = 13
StickerBtn.Parent = InputArea

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0, 60, 0, 40)
SendBtn.Position = UDim2.new(1, -70, 0, 10)
SendBtn.BackgroundColor3 = Colors.Blue
SendBtn.Text = "Enviar"
SendBtn.Font = Enum.Font.GothamBold
SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SendBtn.TextSize = 14
SendBtn.ZIndex = 13
Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 20)
SendBtn.Parent = InputArea

-- Painel de Figurinhas
local StickerPanel = Instance.new("Frame")
StickerPanel.Size = UDim2.new(1, 0, 0, 250)
StickerPanel.Position = UDim2.new(0, 0, 1, 0)
StickerPanel.BackgroundColor3 = Colors.Panel
StickerPanel.ZIndex = 15
StickerPanel.Parent = ChatFrame

local StickerScroll = Instance.new("ScrollingFrame")
StickerScroll.Size = UDim2.new(1, 0, 1, -10)
StickerScroll.Position = UDim2.new(0, 0, 0, 10)
StickerScroll.BackgroundTransparency = 1
StickerScroll.ScrollBarThickness = 2
StickerScroll.ZIndex = 16
StickerScroll.Parent = StickerPanel

local StickerGrid = Instance.new("UIGridLayout")
StickerGrid.CellSize = UDim2.new(0, 70, 0, 70)
StickerGrid.CellPadding = UDim2.new(0, 10, 0, 10)
StickerGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
StickerGrid.Parent = StickerScroll

-- ==========================================
-- FUNÇÕES DE UTILIDADE E UI LOGIC
-- ==========================================
local function getAvatarUrl(userId)
    return string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%s&width=150&height=150&format=png", tostring(userId))
end

local function switchTab(tab)
    ContentInicio.Visible = (tab == "Inicio")
    ContentMensagens.Visible = (tab == "Mensagens")
    ContentNotificacoes.Visible = (tab == "Notificacoes")
    
    TabInicioBtn.TextColor3 = (tab == "Inicio") and Colors.Blue or Colors.SubText
    TabMensagensBtn.TextColor3 = (tab == "Mensagens") and Colors.Blue or Colors.SubText
end

TabInicioBtn.MouseButton1Click:Connect(function() switchTab("Inicio") end)
TabMensagensBtn.MouseButton1Click:Connect(function() switchTab("Mensagens") end)

NotificationBtn.MouseButton1Click:Connect(function() 
    switchTab("Notificacoes") 
    NotificationBadge.Visible = false
end)

local function createFriendUI(friendData, parentLayout, isRequest)
    local frame = Instance.new("TextButton")
    frame.Size = UDim2.new(0.9, 0, 0, 60)
    frame.BackgroundColor3 = Colors.LightGray
    frame.AutoButtonColor = false
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    frame.Parent = parentLayout

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 40, 0, 40)
    avatar.Position = UDim2.new(0, 10, 0, 10)
    avatar.BackgroundColor3 = Colors.Panel
    avatar.Image = getAvatarUrl(friendData.userId)
    Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
    avatar.Parent = frame

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(0, 150, 0, 20)
    name.Position = UDim2.new(0, 60, 0, 20)
    name.BackgroundTransparency = 1
    name.Text = friendData.username
    name.Font = Enum.Font.GothamSemibold
    name.TextColor3 = Colors.Text
    name.TextSize = 14
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Parent = frame

    if isRequest then
        local accBtn = Instance.new("TextButton")
        accBtn.Size = UDim2.new(0, 60, 0, 30)
        accBtn.Position = UDim2.new(1, -70, 0, 15)
        accBtn.BackgroundColor3 = Colors.Blue
        accBtn.Text = "Aceitar"
        accBtn.Font = Enum.Font.GothamBold
        accBtn.TextColor3 = Color3.fromRGB(255,255,255)
        Instance.new("UICorner", accBtn).CornerRadius = UDim.new(0, 6)
        accBtn.Parent = frame

        accBtn.MouseButton1Click:Connect(function()
            sendWebSocketMsg({
                type = "accept_friend_request",
                userId = LocalPlayer.UserId,
                targetId = friendData.userId,
                username = LocalPlayer.Name
            })
            -- Atualiza local
            table.insert(localData.friends, friendData)
            for i, v in ipairs(localData.pendingRequests) do
                if tostring(v.userId) == tostring(friendData.userId) then
                    table.remove(localData.pendingRequests, i)
                    break
                end
            end
            saveJSON()
            frame:Destroy()
            renderFriendsList()
        end)
    else
        -- É um amigo, clique abre chat
        frame.MouseButton1Click:Connect(function()
            openChat(friendData.userId, friendData.username)
        end)
    end
    return frame
end

function renderFriendsList()
    for _, child in ipairs(ContentMensagens:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, friend in ipairs(localData.friends) do
        createFriendUI(friend, ContentMensagens, false)
    end
end

function renderNotifications()
    for _, child in ipairs(ContentNotificacoes:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, req in ipairs(localData.pendingRequests) do
        createFriendUI(req, ContentNotificacoes, true)
    end
    if #localData.pendingRequests > 0 then
        NotificationBadge.Visible = true
    end
end

-- ==========================================
-- LÓGICA DE STICKERS E GITHUB
-- ==========================================
local function loadStickersFromGithub()
    spawn(function()
        local success, res = pcall(function()
            return requestFunc({
                Url = GITHUB_API_URL,
                Method = "GET"
            })
        end)
        
        if success and res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            for _, file in ipairs(data) do
                if string.match(file.name, "%.png$") or string.match(file.name, "%.jpg$") then
                    local localPath = stickersFolder .. "/" .. file.name
                    if not isfile(localPath) then
                        -- Download
                        local dlSuccess, dlRes = pcall(function()
                            return requestFunc({ Url = file.download_url, Method = "GET" })
                        end)
                        if dlSuccess and dlRes.StatusCode == 200 then
                            writefile(localPath, dlRes.Body)
                        end
                    end
                    table.insert(fetchedStickers, {name = file.name, path = localPath})
                end
            end
            populateStickerPanel()
        else
            warn("[ChatUniversal] Falha ao carregar figurinhas do Github.")
        end
    end)
end

function populateStickerPanel()
    for _, child in ipairs(StickerScroll:GetChildren()) do
        if child:IsA("ImageButton") then child:Destroy() end
    end
    for _, sticker in ipairs(fetchedStickers) do
        local btn = Instance.new("ImageButton")
        btn.BackgroundColor3 = Colors.Background
        btn.Image = getAsset(sticker.path)
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        btn.Parent = StickerScroll

        btn.MouseButton1Click:Connect(function()
            sendStickerMessage(sticker.name)
        end)
    end
end

local stickerPanelOpen = false
StickerBtn.MouseButton1Click:Connect(function()
    stickerPanelOpen = not stickerPanelOpen
    if stickerPanelOpen then
        StickerPanel:TweenPosition(UDim2.new(0, 0, 1, -310), "Out", "Quad", 0.3, true)
        MessagesScroll.Size = UDim2.new(1, 0, 1, -380)
    else
        StickerPanel:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.3, true)
        MessagesScroll.Size = UDim2.new(1, 0, 1, -130)
    end
end)

-- ==========================================
-- LÓGICA DO CHAT E MENSAGENS
-- ==========================================
local function scrollChatToBottom()
    -- Delay pequeno para UI atualizar layout
    spawn(function()
        wait(0.05)
        MessagesScroll.CanvasPosition = Vector2.new(0, MessagesScroll.AbsoluteCanvasSize.Y)
    end)
end

local function renderMessageBubble(msgData)
    local isMe = (tostring(msgData.sender) == tostring(LocalPlayer.UserId))
    
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    row.BackgroundTransparency = 1
    row.Parent = MessagesScroll

    local bubble = Instance.new("Frame")
    bubble.BackgroundColor3 = isMe and Colors.Blue or Colors.LightGray
    bubble.AutomaticSize = Enum.AutomaticSize.XY
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 12)
    Instance.new("UIPadding", bubble).PaddingTop = UDim.new(0,10)
    Instance.new("UIPadding", bubble).PaddingBottom = UDim.new(0,10)
    Instance.new("UIPadding", bubble).PaddingLeft = UDim.new(0,15)
    Instance.new("UIPadding", bubble).PaddingRight = UDim.new(0,15)
    
    -- Âncora para direita se for eu
    if isMe then
        bubble.AnchorPoint = Vector2.new(1, 0)
        bubble.Position = UDim2.new(1, -10, 0, 0)
    else
        bubble.AnchorPoint = Vector2.new(0, 0)
        bubble.Position = UDim2.new(0, 10, 0, 0)
    end
    bubble.Parent = row

    if msgData.type == "text" then
        local txt = Instance.new("TextLabel")
        txt.BackgroundTransparency = 1
        txt.Text = msgData.content
        txt.Font = Enum.Font.Gotham
        txt.TextSize = 14
        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        txt.TextWrapped = true
        txt.Size = UDim2.new(0, 200, 0, 0)
        txt.AutomaticSize = Enum.AutomaticSize.Y
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.Parent = bubble
    elseif msgData.type == "sticker" then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(0, 100, 0, 100)
        img.Image = getAsset(stickersFolder .. "/" .. msgData.content)
        img.Parent = bubble
    end
    scrollChatToBottom()
end

function openChat(targetId, targetName)
    currentActiveChat = tostring(targetId)
    ChatHeaderName.Text = targetName
    ChatHeaderAvatar.Image = getAvatarUrl(targetId)
    
    -- Atualizar status com base no cache
    updatePresenceUI(currentActiveChat, presenceCache[currentActiveChat] or "offline")

    -- Limpar chat atual
    for _, child in ipairs(MessagesScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Carregar histórico local
    local chatHistory = localData.chats[currentActiveChat] or {}
    for _, msg in ipairs(chatHistory) do
        renderMessageBubble(msg)
        processedMessageIds[msg.id] = true
    end

    ChatFrame:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.3, true)
end

ChatBackBtn.MouseButton1Click:Connect(function()
    currentActiveChat = nil
    ChatFrame:TweenPosition(UDim2.new(1, 0, 0, 0), "Out", "Quad", 0.3, true)
end)

local function addMessageToLocalAndRender(targetId, msgData)
    if processedMessageIds[msgData.id] then return end
    processedMessageIds[msgData.id] = true

    local chatId = tostring(targetId)
    if not localData.chats[chatId] then localData.chats[chatId] = {} end
    table.insert(localData.chats[chatId], msgData)
    saveJSON()

    if currentActiveChat == chatId then
        renderMessageBubble(msgData)
    end
end

-- ==========================================
-- WEBSOCKET COMMUNICATION
-- ==========================================
local wsConnection = nil
local isReconnecting = false

function sendWebSocketMsg(data)
    if wsConnection then
        local success, encoded = pcall(function() return HttpService:JSONEncode(data) end)
        if success then
            wsConnection:Send(encoded)
        end
    end
end

function updatePresenceUI(userId, status)
    presenceCache[tostring(userId)] = status
    if currentActiveChat == tostring(userId) then
        ChatHeaderStatus.Text = status
        ChatHeaderStatus.TextColor3 = (status == "online" or status == "digitando...") and Colors.Online or Colors.SubText
    end
end

function connectWebSocket()
    if isReconnecting then return end
    isReconnecting = true
    
    spawn(function()
        while true do
            print("[ChatUniversal] Conectando ao WebSocket...")
            local success, socket = pcall(function()
                return WebSocket.connect(WS_URL)
            end)
            
            if success and socket then
                wsConnection = socket
                print("[ChatUniversal] WebSocket conectado!")
                
                -- Register
                local friendIds = {}
                for _, f in ipairs(localData.friends) do table.insert(friendIds, f.userId) end
                
                sendWebSocketMsg({
                    type = "register",
                    userId = LocalPlayer.UserId,
                    username = LocalPlayer.Name,
                    avatar = getAvatarUrl(LocalPlayer.UserId),
                    friends = friendIds
                })

                socket.OnMessage:Connect(function(message)
                    local data = HttpService:JSONDecode(message)
                    handleIncomingEvent(data)
                end)

                socket.OnClose:Connect(function()
                    print("[ChatUniversal] Conexão WebSocket perdida.")
                    wsConnection = nil
                    -- Marcar todos amigos como offline no UI temp
                    for _, f in ipairs(localData.friends) do
                        updatePresenceUI(f.userId, "offline")
                    end
                end)

                isReconnecting = false
                break
            end
            wait(5)
        end
    end)
end

function handleIncomingEvent(data)
    if data.type == "search_results" then
        for _, child in ipairs(SearchResultsFrame:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        for _, user in ipairs(data.results) do
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0.9, 0, 0, 50)
            frame.BackgroundColor3 = Colors.Panel
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
            frame.Parent = SearchResultsFrame

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0, 150, 1, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = user.username
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextColor3 = Colors.Text
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = frame

            local addBtn = Instance.new("TextButton")
            addBtn.Size = UDim2.new(0, 80, 0, 30)
            addBtn.Position = UDim2.new(1, -90, 0, 10)
            addBtn.BackgroundColor3 = Colors.Blue
            addBtn.Text = "Adicionar"
            addBtn.TextColor3 = Color3.fromRGB(255,255,255)
            addBtn.Font = Enum.Font.GothamBold
            Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)
            addBtn.Parent = frame

            addBtn.MouseButton1Click:Connect(function()
                sendWebSocketMsg({
                    type = "send_friend_request",
                    userId = LocalPlayer.UserId,
                    targetId = user.userId,
                    username = LocalPlayer.Name
                })
                addBtn.Text = "Enviado"
            end)
        end

    elseif data.type == "send_friend_request" then
        -- Recebeu pedido
        table.insert(localData.pendingRequests, {userId = data.userId, username = data.username})
        saveJSON()
        renderNotifications()

    elseif data.type == "accept_friend_request" then
        -- Pedido foi aceito
        table.insert(localData.friends, {userId = data.userId, username = data.username})
        saveJSON()
        renderFriendsList()
        print("[ChatUniversal] Amizade aceita por " .. data.username)

    elseif data.type == "private_message" then
        -- Recebeu mensagem
        local msg = data.message
        print("[ChatUniversal] Mensagem recebida de " .. msg.sender)
        addMessageToLocalAndRender(msg.sender, msg)

    elseif data.type == "presence_update" then
        updatePresenceUI(data.userId, data.status)
        
    elseif data.type == "typing_status" then
        if data.isTyping then
            updatePresenceUI(data.userId, "digitando...")
        else
            -- Volta para online ao parar de digitar
            updatePresenceUI(data.userId, "online")
        end
    end
end

-- ==========================================
-- ENVIO DE MENSAGENS E TYPING
-- ==========================================
local typingDebounce = false
ChatInput:GetPropertyChangedSignal("Text"):Connect(function()
    if not currentActiveChat then return end
    local text = ChatInput.Text
    if text ~= "" and not typingDebounce then
        typingDebounce = true
        sendWebSocketMsg({ type = "typing_status", userId = LocalPlayer.UserId, targetId = currentActiveChat, isTyping = true })
    elseif text == "" and typingDebounce then
        typingDebounce = false
        sendWebSocketMsg({ type = "typing_status", userId = LocalPlayer.UserId, targetId = currentActiveChat, isTyping = false })
    end
end)

local function sendCurrentTextMessage()
    local text = ChatInput.Text
    if text == "" or not currentActiveChat then return end
    ChatInput.Text = ""
    
    -- Reseta typing
    typingDebounce = false
    sendWebSocketMsg({ type = "typing_status", userId = LocalPlayer.UserId, targetId = currentActiveChat, isTyping = false })

    local msgData = {
        id = HttpService:GenerateGUID(false),
        sender = LocalPlayer.UserId,
        type = "text",
        content = text,
        timestamp = os.time()
    }

    addMessageToLocalAndRender(currentActiveChat, msgData)

    sendWebSocketMsg({
        type = "private_message",
        userId = LocalPlayer.UserId,
        targetId = currentActiveChat,
        message = msgData
    })
end

SendBtn.MouseButton1Click:Connect(sendCurrentTextMessage)

function sendStickerMessage(stickerName)
    if not currentActiveChat then return end
    
    local msgData = {
        id = HttpService:GenerateGUID(false),
        sender = LocalPlayer.UserId,
        type = "sticker",
        content = stickerName,
        timestamp = os.time()
    }

    addMessageToLocalAndRender(currentActiveChat, msgData)

    sendWebSocketMsg({
        type = "private_message",
        userId = LocalPlayer.UserId,
        targetId = currentActiveChat,
        message = msgData
    })
    
    -- Adicionar ao recentes
    table.insert(localData.recentStickers, 1, stickerName)
    if #localData.recentStickers > 5 then table.remove(localData.recentStickers, 6) end
    saveJSON()
end

-- ==========================================
-- PESQUISA
-- ==========================================
local searchDebounce = tick()
SearchBar:GetPropertyChangedSignal("Text"):Connect(function()
    if tick() - searchDebounce < 0.5 then return end
    searchDebounce = tick()
    local text = SearchBar.Text
    if text ~= "" then
        sendWebSocketMsg({
            type = "search_users",
            query = text,
            userId = LocalPlayer.UserId
        })
    else
        for _, child in ipairs(SearchResultsFrame:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
    end
end)

-- ==========================================
-- INICIALIZAÇÃO FINAL
-- ==========================================
renderFriendsList()
renderNotifications()
loadStickersFromGithub()
connectWebSocket()

-- Polling para garantir reconexão se a thread morrer
spawn(function()
    while wait(10) do
        if not wsConnection and not isReconnecting then
            connectWebSocket()
        end
    end
end)
