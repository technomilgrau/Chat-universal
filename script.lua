-- ==========================================
-- MBCHAT UNIVERSAL - REBUILD COMPLETO DO ZERO
-- ==========================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TextChatService = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- CONFIGURAÇÕES
-- ==========================================
local WS_URL = "wss://chat-universal-online.onrender.com"
local GITHUB_REPO = "SeuUsuario/SeuRepositorio" -- Mude para o repositório correto (ex: "fulano/Mbchat-assets")
local BRANCH = "main"

-- ==========================================
-- SISTEMA DE DADOS LOCAIS (JSON)
-- ==========================================
local DADOS_FOLDER = "Mbchat_dados"
if not isfolder(DADOS_FOLDER) then makefolder(DADOS_FOLDER) end

local function readJSON(fileName, default)
    if isfile(DADOS_FOLDER .. "/" .. fileName) then
        local s, res = pcall(function() return HttpService:JSONDecode(readfile(DADOS_FOLDER .. "/" .. fileName)) end)
        if s and res then return res end
    end
    return default
end

local function writeJSON(fileName, data)
    writefile(DADOS_FOLDER .. "/" .. fileName, HttpService:JSONEncode(data))
end

local Config = readJSON("config.json", { menuSize = 1, recentStickers = {}, savedPosition = nil, bubblePosition = nil })
local Friends = readJSON("friends.json", {}) -- array de userIds
local Chats = readJSON("chats.json", {}) -- chatId -> { history = {}, participants = {} }
local Groups = readJSON("groups.json", {}) -- groupId -> { name, ownerId, history = {}, bg = "nenhuma", bgPos = "{0,0},{0,0}" }

-- ==========================================
-- ESTADO DO APLICATIVO
-- ==========================================
local AppState = {
    CurrentTab = "Home",
    ActiveChatId = nil,
    ActiveGroupId = nil,
    Socket = nil,
    ReconnectTask = nil,
    StickersCache = {},
    BackgroundsCache = {},
    CloneTarget = nil,
    CloneDummy = nil,
    PendingDeleteGroup = nil,
    RepositioningBg = false,
    BgTempPos = nil,
    ChatBoxConnection = nil
}

-- ==========================================
-- GITHUB ASSETS FETCHER
-- ==========================================
local function fetchGithubFolder(folderName)
    local url = string.format("https://api.github.com/repos/%s/contents/%s?ref=%s", GITHUB_REPO, folderName, BRANCH)
    local success, response = pcall(function() return game:HttpGet(url) end)
    local items = {}
    if success then
        local data = HttpService:JSONDecode(response)
        for _, item in ipairs(data) do
            if item.type == "file" then
                table.insert(items, { name = item.name:gsub("%.%w+$", ""), url = item.download_url })
            end
        end
    end
    return items
end

task.spawn(function()
    AppState.StickersCache = fetchGithubFolder("Stickers")
    AppState.BackgroundsCache = fetchGithubFolder("Background images")
end)

-- ==========================================
-- INTERFACE (UI BUILDER)
-- ==========================================
-- Proteção contra múltiplas execuções
if CoreGui:FindFirstChild("MBChat_Universal") then CoreGui.MBChat_Universal:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MBChat_Universal"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local UIScale = Instance.new("UIScale")
UIScale.Scale = Config.menuSize or 1
UIScale.Parent = ScreenGui

-- CORES TEMA DARK
local Colors = {
    BG = Color3.fromRGB(20, 20, 25),
    Header = Color3.fromRGB(30, 30, 38),
    Element = Color3.fromRGB(40, 40, 48),
    Text = Color3.fromRGB(240, 240, 240),
    TextMuted = Color3.fromRGB(150, 150, 150),
    Primary = Color3.fromRGB(0, 120, 215),
    Green = Color3.fromRGB(40, 180, 80),
    Red = Color3.fromRGB(200, 60, 60),
    MessageHost = Color3.fromRGB(0, 90, 160),
    MessageGuest = Color3.fromRGB(50, 50, 60)
}

local function CreateRoundedFrame(parent, size, pos, color)
    local f = Instance.new("Frame")
    f.Size, f.Position, f.BackgroundColor3, f.BorderSizePixel, f.Parent = size, pos, color, 0, parent
    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 12)
    uic.Parent = f
    return f
end

local function CreateText(parent, text, size, pos, color, fontSize, align)
    local t = Instance.new("TextLabel")
    t.Size, t.Position, t.BackgroundTransparency, t.Text, t.TextColor3, t.TextSize, t.Font, t.TextXAlignment, t.Parent = size, pos, 1, text, color, fontSize, Enum.Font.GothamSemibold, align or Enum.TextXAlignment.Left, parent
    return t
end

local function CreateButton(parent, text, size, pos, color, textColor)
    local btn = Instance.new("TextButton")
    btn.Size, btn.Position, btn.BackgroundColor3, btn.Text, btn.TextColor3, btn.TextSize, btn.Font, btn.Parent = size, pos, color, text, textColor, 14, Enum.Font.GothamBold, parent
    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 8)
    uic.Parent = btn
    return btn
end

-- BOLHA DE MINIMIZAR
local Bubble = Instance.new("TextButton")
Bubble.Size = UDim2.new(0, 50, 0, 50)
Bubble.Position = Config.bubblePosition and UDim2.new(Config.bubblePosition[1], Config.bubblePosition[2], Config.bubblePosition[3], Config.bubblePosition[4]) or UDim2.new(0.5, -25, 0.05, 0)
Bubble.BackgroundColor3 = Colors.Primary
Bubble.Text = "D"
Bubble.TextColor3 = Colors.Text
Bubble.TextSize = 24
Bubble.Font = Enum.Font.GothamBlack
Bubble.Visible = false
Bubble.Parent = ScreenGui
local BubbleCorner = Instance.new("UICorner", Bubble)
BubbleCorner.CornerRadius = UDim.new(1, 0)

-- MENU PRINCIPAL
local MainFrame = CreateRoundedFrame(ScreenGui, UDim2.new(0, 350, 0, 550), Config.savedPosition and UDim2.new(Config.savedPosition[1], Config.savedPosition[2], Config.savedPosition[3], Config.savedPosition[4]) or UDim2.new(0.5, -175, 0.5, -275), Colors.BG)
MainFrame.ClipsDescendants = true

local Header = CreateRoundedFrame(MainFrame, UDim2.new(1, 0, 0, 50), UDim2.new(0, 0, 0, 0), Colors.Header)
local HeaderCornerFix = Instance.new("Frame") -- Cobre cantos inferiores
HeaderCornerFix.Size, HeaderCornerFix.Position, HeaderCornerFix.BackgroundColor3, HeaderCornerFix.BorderSizePixel, HeaderCornerFix.Parent = UDim2.new(1, 0, 0, 10), UDim2.new(0, 0, 1, -10), Colors.Header, 0, Header
CreateText(Header, "  MBChat", UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 0, 0, 0), Colors.Text, 18)

local MinimizeBtn = CreateButton(Header, "-", UDim2.new(0, 30, 0, 30), UDim2.new(1, -40, 0.5, -15), Colors.Element, Colors.Text)
MinimizeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    Bubble.Visible = true
end)
Bubble.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    Bubble.Visible = false
end)

-- SISTEMA DE ARRASTE
local function MakeDraggable(ui, dragElement, isBubble)
    local dragging, dragInput, dragStart, startPos
    dragElement.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, ui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if isBubble then Config.bubblePosition = {ui.Position.X.Scale, ui.Position.X.Offset, ui.Position.Y.Scale, ui.Position.Y.Offset}
                    else Config.savedPosition = {ui.Position.X.Scale, ui.Position.X.Offset, ui.Position.Y.Scale, ui.Position.Y.Offset} end
                    writeJSON("config.json", Config)
                end
            end)
        end
    end)
    dragElement.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            ui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end
MakeDraggable(MainFrame, Header, false)
MakeDraggable(Bubble, Bubble, true)

-- AREA DE CONTEÚDO E NAVEGAÇÃO
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size, ContentArea.Position, ContentArea.BackgroundTransparency = UDim2.new(1, 0, 1, -110), UDim2.new(0, 0, 0, 50), 1

local NavBar = CreateRoundedFrame(MainFrame, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 1, -60), Colors.Header)
local NavFix = Instance.new("Frame", NavBar)
NavFix.Size, NavFix.Position, NavFix.BackgroundColor3, NavFix.BorderSizePixel = UDim2.new(1, 0, 0, 10), UDim2.new(0, 0, 0, 0), Colors.Header, 0

local navLayout = Instance.new("UIListLayout", NavBar)
navLayout.FillDirection, navLayout.HorizontalAlignment, navLayout.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.SpaceEvenly, Enum.VerticalAlignment.Center

local Tabs = {}
local function CreateTabNav(name, text)
    local btn = CreateButton(NavBar, text, UDim2.new(0, 60, 0, 40), UDim2.new(), Colors.Element, Colors.TextMuted)
    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
    return btn
end
local BtnHome = CreateTabNav("Home", "🏠")
local BtnFriends = CreateTabNav("Friends", "👥")
local BtnNotifs = CreateTabNav("Notifs", "🔔")
local BtnSettings = CreateTabNav("Settings", "⚙️")

-- FUNÇÃO DE NAVEGAÇÃO
function SwitchTab(tabName)
    AppState.CurrentTab = tabName
    for name, frame in pairs(Tabs) do frame.Visible = (name == tabName) end
    if AppState.ActiveChatId and tabName ~= "Chat" then AppState.ActiveChatId = nil end
    if AppState.ActiveGroupId and tabName ~= "GroupChat" then AppState.ActiveGroupId = nil end
    UpdateUIState()
end

-- ==========================================
-- TELAS (TABS)
-- ==========================================
-- HOME (Lista de Chats e Grupos)
Tabs.Home = Instance.new("ScrollingFrame", ContentArea)
Tabs.Home.Size, Tabs.Home.BackgroundTransparency, Tabs.Home.Visible = UDim2.new(1, -20, 1, -20), 1, true
Tabs.Home.Position = UDim2.new(0, 10, 0, 10)
Tabs.Home.ScrollBarThickness = 2
local HomeLayout = Instance.new("UIListLayout", Tabs.Home)
HomeLayout.Padding, HomeLayout.SortOrder = UDim.new(0, 5), Enum.SortOrder.LayoutOrder

-- AMIGOS (Pesquisa e Lista)
Tabs.Friends = Instance.new("Frame", ContentArea)
Tabs.Friends.Size, Tabs.Friends.BackgroundTransparency, Tabs.Friends.Visible = UDim2.new(1, 0, 1, 0), 1, false
local FriendSearch = Instance.new("TextBox", Tabs.Friends)
FriendSearch.Size, FriendSearch.Position, FriendSearch.BackgroundColor3, FriendSearch.Text, FriendSearch.TextColor3, FriendSearch.PlaceholderText = UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 10), Colors.Element, "", Colors.Text, "Procurar amigos..."
Instance.new("UICorner", FriendSearch).CornerRadius = UDim.new(0, 8)
local FriendList = Instance.new("ScrollingFrame", Tabs.Friends)
FriendList.Size, FriendList.Position, FriendList.BackgroundTransparency, FriendList.ScrollBarThickness = UDim2.new(1, -20, 1, -60), UDim2.new(0, 10, 0, 60), 1, 2
local FriendLayout = Instance.new("UIListLayout", FriendList)
FriendLayout.Padding = UDim.new(0, 5)

-- NOTIFICAÇÕES
Tabs.Notifs = Instance.new("ScrollingFrame", ContentArea)
Tabs.Notifs.Size, Tabs.Notifs.Position, Tabs.Notifs.BackgroundTransparency, Tabs.Notifs.Visible, Tabs.Notifs.ScrollBarThickness = UDim2.new(1, -20, 1, -20), UDim2.new(0, 10, 0, 10), 1, false, 2
local NotifLayout = Instance.new("UIListLayout", Tabs.Notifs)
NotifLayout.Padding = UDim.new(0, 5)

-- CONFIGURAÇÕES
Tabs.Settings = Instance.new("Frame", ContentArea)
Tabs.Settings.Size, Tabs.Settings.BackgroundTransparency, Tabs.Settings.Visible = UDim2.new(1, -20, 1, -20), 1, false
Tabs.Settings.Position = UDim2.new(0, 10, 0, 10)
CreateText(Tabs.Settings, "Tamanho do Menu:", UDim2.new(1, 0, 0, 30), UDim2.new(0,0,0,0), Colors.Text, 16)
local SizeControls = Instance.new("Frame", Tabs.Settings)
SizeControls.Size, SizeControls.Position, SizeControls.BackgroundTransparency = UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 40), 1
local BtnMinus = CreateButton(SizeControls, "-", UDim2.new(0, 40, 1, 0), UDim2.new(0, 0, 0, 0), Colors.Element, Colors.Text)
local BtnPlus = CreateButton(SizeControls, "+", UDim2.new(0, 40, 1, 0), UDim2.new(1, -40, 0, 0), Colors.Element, Colors.Text)
local SizeDisplay = CreateText(SizeControls, tostring(Config.menuSize), UDim2.new(1, -100, 1, 0), UDim2.new(0, 50, 0, 0), Colors.Text, 16, Enum.TextXAlignment.Center)
local BtnResetSize = CreateButton(Tabs.Settings, "Resetar Tamanho", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 100), Colors.Element, Colors.Text)
local BtnCreateGroup = CreateButton(Tabs.Settings, "Criar Grupo", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 150), Colors.Primary, Colors.Text)
local BtnCloneMenu = CreateButton(Tabs.Settings, "Menu de Clone", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 200), Colors.Element, Colors.Text)

-- CHAT INTERFACE (Privado e Grupo compartilham base visual, instâncias separadas para evitar conflito)
local function CreateChatInterface(parentTabName)
    local t = Instance.new("Frame", ContentArea)
    t.Size, t.BackgroundTransparency, t.Visible = UDim2.new(1, 0, 1, 0), 1, false
    
    local topBar = CreateRoundedFrame(t, UDim2.new(1, 0, 0, 40), UDim2.new(), Colors.Header)
    local btnBack = CreateButton(topBar, "<", UDim2.new(0, 40, 1, 0), UDim2.new(), Colors.Element, Colors.Text)
    btnBack.MouseButton1Click:Connect(function() SwitchTab("Home") end)
    local title = CreateText(topBar, "Chat", UDim2.new(1, -90, 1, 0), UDim2.new(0, 50, 0, 0), Colors.Text, 16, Enum.TextXAlignment.Center)
    local btnAction = CreateButton(topBar, "⋮", UDim2.new(0, 40, 1, 0), UDim2.new(1, -40, 0, 0), Colors.Element, Colors.Text)
    
    local chatBg = Instance.new("ImageLabel", t) -- Para o sistema de Backgrounds
    chatBg.Size, chatBg.Position, chatBg.ZIndex, chatBg.BackgroundTransparency = UDim2.new(1, 0, 1, -80), UDim2.new(0, 0, 0, 40), 0, 1
    chatBg.ImageTransparency = 0.5
    chatBg.Visible = false
    
    local scroller = Instance.new("ScrollingFrame", t)
    scroller.Size, scroller.Position, scroller.BackgroundTransparency, scroller.ScrollBarThickness, scroller.ZIndex = UDim2.new(1, -10, 1, -80), UDim2.new(0, 5, 0, 40), 1, 2, 1
    local list = Instance.new("UIListLayout", scroller)
    list.Padding, list.SortOrder = UDim.new(0, 5), Enum.SortOrder.LayoutOrder
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scroller.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 10); scroller.CanvasPosition = Vector2.new(0, scroller.CanvasSize.Y.Offset) end)
    
    local inputArea = CreateRoundedFrame(t, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 1, -40), Colors.Element)
    local chatHint = CreateText(inputArea, "Use o chat do Roblox para digitar...", UDim2.new(1, -40, 1, 0), UDim2.new(0, 10, 0, 0), Colors.TextMuted, 12)
    local btnSticker = CreateButton(inputArea, "😊", UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0.5, -15), Colors.BG, Colors.Text)
    
    Tabs[parentTabName] = t
    return { Frame = t, Scroller = scroller, Title = title, BtnAction = btnAction, BtnSticker = btnSticker, Bg = chatBg }
end
local PrivateChatUI = CreateChatInterface("Chat")
local GroupChatUI = CreateChatInterface("GroupChat")

-- MENU DE STICKERS
local StickerMenu = CreateRoundedFrame(MainFrame, UDim2.new(1, 0, 0.6, 0), UDim2.new(0, 0, 0.4, 0), Colors.Header)
StickerMenu.Visible, StickerMenu.ZIndex = false, 10
local SBtnClose = CreateButton(StickerMenu, "X", UDim2.new(0, 30, 0, 30), UDim2.new(1, -35, 0, 5), Colors.Red, Colors.Text)
SBtnClose.ZIndex = 11; SBtnClose.MouseButton1Click:Connect(function() StickerMenu.Visible = false end)
local SSearch = Instance.new("TextBox", StickerMenu)
SSearch.Size, SSearch.Position, SSearch.BackgroundColor3, SSearch.Text, SSearch.TextColor3, SSearch.PlaceholderText, SSearch.ZIndex = UDim2.new(1, -50, 0, 30), UDim2.new(0, 10, 0, 5), Colors.Element, "", Colors.Text, "Encontre a figurinha perfeita", 11
local SScroller = Instance.new("ScrollingFrame", StickerMenu)
SScroller.Size, SScroller.Position, SScroller.BackgroundTransparency, SScroller.ScrollBarThickness, SScroller.ZIndex = UDim2.new(1, -10, 1, -45), UDim2.new(0, 5, 0, 40), 1, 2, 11
local SGrid = Instance.new("UIGridLayout", SScroller)
SGrid.CellSize, SGrid.CellPadding = UDim2.new(0, 60, 0, 60), UDim2.new(0, 10, 0, 10)

-- STICKER MODAL AMPLIADO
local StickerModal = Instance.new("TextButton", ScreenGui)
StickerModal.Size, StickerModal.BackgroundColor3, StickerModal.BackgroundTransparency, StickerModal.Text, StickerModal.Visible, StickerModal.ZIndex = UDim2.new(1,0,1,0), Color3.new(0,0,0), 0.7, "", false, 100
local SModalImg = Instance.new("ImageLabel", StickerModal)
SModalImg.Size, SModalImg.Position, SModalImg.BackgroundTransparency, SModalImg.ZIndex = UDim2.new(0, 200, 0, 200), UDim2.new(0.5, -100, 0.5, -100), 1, 101
local SModalText = CreateText(StickerModal, "", UDim2.new(0, 200, 0, 30), UDim2.new(0.5, -100, 0.5, 110), Colors.Text, 16, Enum.TextXAlignment.Center)
SModalText.ZIndex = 101
StickerModal.MouseButton1Click:Connect(function() StickerModal.Visible = false end)

-- AUTOCOMPLETE OVERLAY
local AutoCompleteFrame = CreateRoundedFrame(ScreenGui, UDim2.new(0, 200, 0, 150), UDim2.new(0,0,0,0), Colors.Header)
AutoCompleteFrame.Visible, AutoCompleteFrame.ZIndex = false, 50
local ACScroller = Instance.new("ScrollingFrame", AutoCompleteFrame)
ACScroller.Size, ACScroller.BackgroundTransparency, ACScroller.ScrollBarThickness = UDim2.new(1,0,1,0), 1, 2
local ACList = Instance.new("UIListLayout", ACScroller)

-- ==========================================
-- WEBSOCKET & COMUNICAÇÃO
-- ==========================================
local function SendWS(data)
    if AppState.Socket then
        pcall(function() AppState.Socket:Send(HttpService:JSONEncode(data)) end)
    end
end

local function InitWebSocket()
    if AppState.Socket then pcall(function() AppState.Socket:Close() end) end
    local success, ws = pcall(function() return WebSocket.connect(WS_URL) end)
    if success and ws then
        AppState.Socket = ws
        SendWS({ type = "register", userId = LocalPlayer.UserId, username = LocalPlayer.Name, displayName = LocalPlayer.DisplayName })
        
        ws.OnMessage:Connect(function(msg)
            local s, data = pcall(function() return HttpService:JSONDecode(msg) end)
            if not s then return end
            HandleServerMessage(data)
        end)
        
        ws.OnClose:Connect(function()
            AppState.Socket = nil
            if not AppState.ReconnectTask then
                AppState.ReconnectTask = task.spawn(function()
                    task.wait(5)
                    AppState.ReconnectTask = nil
                    InitWebSocket()
                end)
            end
        end)
    else
        task.wait(5)
        InitWebSocket()
    end
end

-- ==========================================
-- FUNÇÕES DE DADOS E RENDERIZAÇÃO
-- ==========================================
local function SaveLocalData()
    writeJSON("friends.json", Friends)
    writeJSON("chats.json", Chats)
    writeJSON("groups.json", Groups)
end

local function GetUserAvatar(userId)
    return "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
end

local function RenderMessage(scroller, msgData)
    local isMe = msgData.senderId == LocalPlayer.UserId
    local frame = CreateRoundedFrame(scroller, UDim2.new(0.8, 0, 0, 0), UDim2.new(isMe and 0.2 or 0, 0, 0, 0), isMe and Colors.MessageHost or Colors.MessageGuest)
    
    local nameLbl = CreateText(frame, msgData.username, UDim2.new(1, -10, 0, 15), UDim2.new(0, 5, 0, 2), Colors.TextMuted, 12)
    local contentHeight = 30
    
    if msgData.type == "sticker" then
        local img = Instance.new("ImageLabel", frame)
        img.Size, img.Position, img.BackgroundTransparency, img.Image = UDim2.new(0, 100, 0, 100), UDim2.new(0, 10, 0, 20), 1, msgData.url
        contentHeight = 130
        local btn = Instance.new("TextButton", img)
        btn.Size, btn.BackgroundTransparency, btn.Text = UDim2.new(1,0,1,0), 1, ""
        btn.MouseButton1Click:Connect(function()
            SModalImg.Image, SModalText.Text, StickerModal.Visible = msgData.url, msgData.name, true
        end)
    else
        local txt = CreateText(frame, msgData.content, UDim2.new(1, -20, 0, 0), UDim2.new(0, 10, 0, 20), Colors.Text, 14)
        txt.TextWrapped = true
        txt.Size = UDim2.new(1, -20, 0, txt.TextBounds.Y + 10)
        contentHeight = txt.Size.Y.Offset + 25
    end
    
    frame.Size = UDim2.new(0.8, 0, 0, contentHeight)
end

local function RefreshChatView(chatId, isGroup)
    local ui = isGroup and GroupChatUI or PrivateChatUI
    local history = isGroup and (Groups[chatId] and Groups[chatId].history or {}) or (Chats[chatId] and Chats[chatId].history or {})
    for _, child in ipairs(ui.Scroller:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, msg in ipairs(history) do RenderMessage(ui.Scroller, msg) end
    
    if isGroup and Groups[chatId] then
        ui.Title.Text = Groups[chatId].name
        if Groups[chatId].background ~= "nenhuma" then
            ui.Bg.Image = Groups[chatId].background
            ui.Bg.Visible = true
            local p = string.split(Groups[chatId].bgPos:gsub("[{}]", ""), "},{")
            if #p == 2 then
                local p1, p2 = string.split(p[1], ","), string.split(p[2], ",")
                ui.Bg.Position = UDim2.new(tonumber(p1[1]), tonumber(p1[2]), tonumber(p2[1]), tonumber(p2[2]))
            end
        else ui.Bg.Visible = false end
    end
end

local function AddNotification(text, onAccept, onReject)
    local f = CreateRoundedFrame(Tabs.Notifs, UDim2.new(1, 0, 0, 60), UDim2.new(), Colors.Element)
    CreateText(f, text, UDim2.new(1, -120, 1, 0), UDim2.new(0, 10, 0, 0), Colors.Text, 12).TextWrapped = true
    local bA = CreateButton(f, "✓", UDim2.new(0, 40, 0, 40), UDim2.new(1, -95, 0, 10), Colors.Green, Colors.Text)
    local bR = CreateButton(f, "X", UDim2.new(0, 40, 0, 40), UDim2.new(1, -50, 0, 10), Colors.Red, Colors.Text)
    bA.MouseButton1Click:Connect(function() onAccept(); f:Destroy() end)
    bR.MouseButton1Click:Connect(function() onReject(); f:Destroy() end)
end

-- ==========================================
-- RECEBIMENTO DE EVENTOS DO SERVIDOR
-- ==========================================
function HandleServerMessage(data)
    local t = data.type
    
    if t == "search_results" then
        for _, c in ipairs(FriendList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        for _, user in ipairs(data.results) do
            local f = CreateRoundedFrame(FriendList, UDim2.new(1, 0, 0, 50), UDim2.new(), Colors.Element)
            local img = Instance.new("ImageLabel", f)
            img.Size, img.Position, img.BackgroundTransparency, img.Image = UDim2.new(0, 40, 0, 40), UDim2.new(0, 5, 0, 5), 1, GetUserAvatar(user.userId)
            Instance.new("UICorner", img).CornerRadius = UDim.new(0, 8)
            CreateText(f, user.displayName .. " (@" .. user.username .. ")", UDim2.new(1, -110, 1, 0), UDim2.new(0, 55, 0, 0), Colors.Text, 14)
            local btnAdd = CreateButton(f, "Add", UDim2.new(0, 50, 0, 30), UDim2.new(1, -55, 0, 10), Colors.Green, Colors.Text)
            btnAdd.MouseButton1Click:Connect(function()
                SendWS({ type = "friend_request", targetId = user.userId })
                btnAdd.Text = "Enviado"
            end)
        end
        
    elseif t == "friend_request_received" then
        AddNotification("Pedido de amizade de " .. data.sender.displayName, 
            function() SendWS({ type = "friend_accept", targetId = data.sender.userId }); table.insert(Friends, data.sender.userId); SaveLocalData() end,
            function() end)
            
    elseif t == "friend_accepted" then
        table.insert(Friends, data.sender.userId)
        SaveLocalData()
        
    elseif t == "chat_invite_received" then
        AddNotification("Convite de chat privado de " .. data.sender.displayName,
            function() SendWS({ type = "chat_invite_accept", chatId = data.chatId, hostId = data.sender.userId }) end,
            function() end)
            
    elseif t == "chat_join_success" then
        if not Chats[data.chatId] then Chats[data.chatId] = { history = {}, participants = {} } end
        AppState.ActiveChatId = data.chatId
        SwitchTab("Chat")
        RefreshChatView(data.chatId, false)
        
    elseif t == "chat_message" or t == "sticker_message" then
        local target = Chats[data.chatId]
        if target then
            table.insert(target.history, data)
            SaveLocalData()
            if AppState.ActiveChatId == data.chatId and AppState.CurrentTab == "Chat" then
                RenderMessage(PrivateChatUI.Scroller, data)
            end
        end
        
    elseif t == "group_invite_received" then
        AddNotification("Convite para grupo '" .. data.groupName .. "' de " .. data.sender.displayName,
            function() SendWS({ type = "group_invite_accept", groupId = data.groupId }) end,
            function() end)
            
    elseif t == "group_join_success" then
        if not Groups[data.groupId] then Groups[data.groupId] = { history = {}, background = data.background, bgPos = data.bgPosition, name = "Grupo" } end
        AppState.ActiveGroupId = data.groupId
        SwitchTab("GroupChat")
        RefreshChatView(data.groupId, true)
        
    elseif t == "group_message" or t == "group_sticker" then
        local grp = Groups[data.groupId]
        if grp then
            table.insert(grp.history, data)
            SaveLocalData()
            if AppState.ActiveGroupId == data.groupId and AppState.CurrentTab == "GroupChat" then
                RenderMessage(GroupChatUI.Scroller, data)
            end
        end
        
    elseif t == "group_background_update" then
        if Groups[data.groupId] then
            Groups[data.groupId].background = data.background
            Groups[data.groupId].bgPos = data.bgPosition
            SaveLocalData()
            if AppState.ActiveGroupId == data.groupId then RefreshChatView(data.groupId, true) end
        end
        
    elseif t == "group_deleted" then
        Groups[data.groupId] = nil
        SaveLocalData()
        if AppState.ActiveGroupId == data.groupId then SwitchTab("Home") end
        
    elseif t == "error_message" then
        -- Simples print ou toast (para manter compacto, usaremos print no console exploit)
        print("[MBChat] Erro: " .. data.message)
        
    elseif t == "clone_invite_received" then
        AddNotification("Convite de CLONE de " .. data.username,
            function() SendWS({ type = "clone_accept", targetId = data.senderId }); AppState.CloneTarget = data.senderId end,
            function() end)
            
    elseif t == "clone_accepted" then
        AppState.CloneTarget = data.senderId
        -- Criar dummy
        pcall(function()
            if AppState.CloneDummy then AppState.CloneDummy:Destroy() end
            local model = Players:CreateHumanoidModelFromUserId(data.senderId)
            model.Name = "MBChat_Clone_" .. data.senderId
            model.Parent = workspace
            AppState.CloneDummy = model
        end)
        
    elseif t == "clone_update" and AppState.CloneDummy then
        pcall(function()
            local cf = string.split(data.cframe, ",")
            local newCf = CFrame.new(tonumber(cf[1]), tonumber(cf[2]), tonumber(cf[3])) * CFrame.Angles(tonumber(cf[4]), tonumber(cf[5]), tonumber(cf[6]))
            TweenService:Create(AppState.CloneDummy.PrimaryPart, TweenInfo.new(0.2), {CFrame = newCf}):Play()
            local hum = AppState.CloneDummy:FindFirstChild("Humanoid")
            if hum then
                local md = string.split(data.moveDir, ",")
                hum:Move(Vector3.new(tonumber(md[1]), tonumber(md[2]), tonumber(md[3])))
                hum.Jump = data.jump
            end
        end)
    end
    UpdateUIState()
end

-- ==========================================
-- INTERAÇÕES LOCAIS E CHAT HOOK
-- ==========================================
local function SendChatMessage(content)
    if AppState.CurrentTab == "Chat" and AppState.ActiveChatId then
        local msg = { type = "chat_message", chatId = AppState.ActiveChatId, senderId = LocalPlayer.UserId, username = LocalPlayer.Name, content = content }
        SendWS(msg)
        HandleServerMessage(msg) -- Self render
    elseif AppState.CurrentTab == "GroupChat" and AppState.ActiveGroupId then
        -- Comandos de grupo
        local cmd, arg = string.match(content, "^(//%w+)%s*(.*)")
        if cmd then
            local grp = Groups[AppState.ActiveGroupId]
            if cmd == "//invitegp" then
                local tId = tonumber(arg) -- simplificando para ID, a UI de autocomplete resolve nomes para IDs
                if tId then SendWS({ type = "group_invite", groupId = AppState.ActiveGroupId, groupName = grp.name, targetId = tId }) end
            elseif cmd == "//deletegp" then
                if grp.ownerId == LocalPlayer.UserId then
                    AppState.PendingDeleteGroup = AppState.ActiveGroupId
                    local prompt = { type = "group_message", groupId = AppState.ActiveGroupId, senderId = 0, username = "Sistema", content = "Você realmente deseja deletar este grupo? Escreva //sim para confirmar ou //não para cancelar." }
                    HandleServerMessage(prompt)
                end
            elseif cmd == "//sim" and AppState.PendingDeleteGroup == AppState.ActiveGroupId then
                SendWS({ type = "group_delete_confirm", groupId = AppState.ActiveGroupId })
                AppState.PendingDeleteGroup = nil
            elseif cmd == "//não" then
                AppState.PendingDeleteGroup = nil
            end
            return -- Não envia comando como mensagem
        end
        local msg = { type = "group_message", groupId = AppState.ActiveGroupId, senderId = LocalPlayer.UserId, username = LocalPlayer.Name, content = content }
        SendWS(msg)
        -- Self render já é feito no broadcast do server, mas para evitar lag visual, podemos adicionar localmente se quisermos
    end
end

-- Hook no chat do Roblox
local function SetupChatHook()
    if AppState.ChatBoxConnection then AppState.ChatBoxConnection:Disconnect() end
    
    -- Suporte TextChatService (Moderno)
    TextChatService.SendingMessage:Connect(function(textMsg)
        if AppState.CurrentTab == "Chat" or AppState.CurrentTab == "GroupChat" then
            SendChatMessage(textMsg.Text)
        end
    end)
    
    -- Suporte Legacy
    LocalPlayer.Chatted:Connect(function(msg)
        if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
            if AppState.CurrentTab == "Chat" or AppState.CurrentTab == "GroupChat" then
                SendChatMessage(msg)
            end
        end
    end)
end

-- Atualizar lista da Home
function UpdateUIState()
    if AppState.CurrentTab == "Home" then
        for _, c in ipairs(Tabs.Home:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end
        
        local btnNewChat = CreateButton(Tabs.Home, "Novo Chat Privado", UDim2.new(1, 0, 0, 40), UDim2.new(), Colors.Element, Colors.Text)
        btnNewChat.MouseButton1Click:Connect(function()
            local cid = HttpService:GenerateGUID(false)
            Chats[cid] = { history = {}, participants = {} }
            SaveLocalData()
            AppState.ActiveChatId = cid
            SwitchTab("Chat")
            RefreshChatView(cid, false)
        end)
        
        for cid, data in pairs(Chats) do
            local btn = CreateButton(Tabs.Home, "Chat Privado", UDim2.new(1, 0, 0, 40), UDim2.new(), Colors.Element, Colors.Text)
            btn.MouseButton1Click:Connect(function() AppState.ActiveChatId = cid; SwitchTab("Chat"); RefreshChatView(cid, false) end)
        end
        for gid, data in pairs(Groups) do
            local btn = CreateButton(Tabs.Home, "Grupo: " .. (data.name or "Grupo"), UDim2.new(1, 0, 0, 40), UDim2.new(), Colors.Primary, Colors.Text)
            btn.MouseButton1Click:Connect(function() AppState.ActiveGroupId = gid; SwitchTab("GroupChat"); RefreshChatView(gid, true) end)
        end
    end
end

-- Eventos UI
FriendSearch.FocusLost:Connect(function(enter)
    if enter and FriendSearch.Text ~= "" then
        SendWS({ type = "search_users", query = FriendSearch.Text, friends = Friends })
    end
end)

local function PopulateStickers()
    for _, c in ipairs(SScroller:GetChildren()) do if c:IsA("ImageButton") then c:Destroy() end end
    
    local function addS(item)
        local btn = Instance.new("ImageButton", SScroller)
        btn.Size, btn.BackgroundTransparency, btn.Image = UDim2.new(0, 60, 0, 60), 1, item.url
        btn.MouseButton1Click:Connect(function()
            local msg = { type = (AppState.CurrentTab == "GroupChat") and "group_sticker" or "sticker_message", senderId = LocalPlayer.UserId, username = LocalPlayer.Name, url = item.url, name = item.name }
            if AppState.CurrentTab == "Chat" then msg.chatId = AppState.ActiveChatId else msg.groupId = AppState.ActiveGroupId end
            SendWS(msg)
            if AppState.CurrentTab == "Chat" then HandleServerMessage(msg) end -- self render
            StickerMenu.Visible = false
        end)
    end
    
    for _, st in ipairs(Config.recentStickers) do addS(st) end
    for _, st in ipairs(AppState.StickersCache) do addS(st) end
end

PrivateChatUI.BtnSticker.MouseButton1Click:Connect(function() PopulateStickers(); StickerMenu.Visible = true end)
GroupChatUI.BtnSticker.MouseButton1Click:Connect(function() PopulateStickers(); StickerMenu.Visible = true end)

SSearch:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SSearch.Text:lower()
    for _, c in ipairs(SScroller:GetChildren()) do
        if c:IsA("ImageButton") then
            c.Visible = q == "" or c.Image:lower():match(q) ~= nil -- simplificação da busca
        end
    end
end)

-- Configurações Size
local function UpdateScale()
    UIScale.Scale = Config.menuSize
    SizeDisplay.Text = string.format("%.1f", Config.menuSize)
end
local sizeLoop = nil
local function changeSize(amount) Config.menuSize = math.clamp(Config.menuSize + amount, 0.5, 2); UpdateScale(); writeJSON("config.json", Config) end
BtnPlus.MouseButton1Down:Connect(function() changeSize(0.1); sizeLoop = task.spawn(function() task.wait(0.5); while true do changeSize(0.1); task.wait(0.1) end end) end)
BtnMinus.MouseButton1Down:Connect(function() changeSize(-0.1); sizeLoop = task.spawn(function() task.wait(0.5); while true do changeSize(-0.1); task.wait(0.1) end end) end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then if sizeLoop then task.cancel(sizeLoop); sizeLoop = nil end end end)
BtnResetSize.MouseButton1Click:Connect(function() Config.menuSize = 1; UpdateScale(); writeJSON("config.json", Config) end)

BtnCreateGroup.MouseButton1Click:Connect(function()
    local gid = HttpService:GenerateGUID(false)
    Groups[gid] = { name = "Novo Grupo", ownerId = LocalPlayer.UserId, history = {}, background = "nenhuma", bgPos = "{0,0},{0,0}" }
    SaveLocalData()
    SendWS({ type = "group_create", groupId = gid, name = "Novo Grupo" })
    AppState.ActiveGroupId = gid
    SwitchTab("GroupChat")
    RefreshChatView(gid, true)
end)

-- Clone Sync Loop
RunService.Heartbeat:Connect(function()
    if AppState.CloneTarget and AppState.Socket then
        local cf = LocalPlayer.Character and LocalPlayer.Character:GetPivot()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if cf and hum then
            local md = hum.MoveDirection
            SendWS({
                type = "clone_sync",
                targetId = AppState.CloneTarget,
                cframe = string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f", cf.X, cf.Y, cf.Z, cf:ToEulerAnglesXYZ()),
                moveDir = string.format("%.2f,%.2f,%.2f", md.X, md.Y, md.Z),
                jump = hum.Jump
            })
        end
    end
end)

-- Iniciar
InitWebSocket()
SetupChatHook()
SwitchTab("Home")
UpdateScale()

print("[MBChat] Inicializado com sucesso!")
