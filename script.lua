-- MBChat Universal Client
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local UserId = tostring(LocalPlayer.UserId)

-- Configurações de Rede
local WS_URL = "wss://chat-universal-online.onrender.com"
local ws = nil
local isConnected = false

-- Repositório e Assets
local REPO_URL = "https://api.github.com/repos/technomilgrau/Chat-universal/contents"
local STICKERS_URL = "https://raw.githubusercontent.com/technomilgrau/Chat-universal/main/Stickers/"
local BGS_URL = "https://raw.githubusercontent.com/technomilgrau/Chat-universal/main/Background%20images/"

-- Sistema de Dados Locais (Mbchat_dados)
local DATA_FOLDER = "Mbchat_dados"
local DATA_FILE = DATA_FOLDER .. "/" .. UserId .. "_data.json"

local LocalData = {
    friends = {}, -- [userId] = {username, displayName}
    groups = {}, -- [groupId] = {name, ownerId, members, bg, history}
    chats = {}, -- [chatId] = {participants, history}
    notifications = {},
    settings = { menuSize = 1, recentStickers = {} }
}

if not isfolder(DATA_FOLDER) then makefolder(DATA_FOLDER) end

local function SaveData()
    writefile(DATA_FILE, HttpService:JSONEncode(LocalData))
end

local function LoadData()
    if isfile(DATA_FILE) then
        local success, decoded = pcall(function() return HttpService:JSONDecode(readfile(DATA_FILE)) end)
        if success and decoded then
            for k, v in pairs(decoded) do LocalData[k] = v end
        end
    end
end
LoadData()

-- Estado Ativo
local ActiveChatId = nil
local ActiveGroupId = nil
local ActiveClone = nil

-- Helpers de UI
local function Create(className, props)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    return obj
end

-- --- INTERFACE GRÁFICA PRINCIPAL ---
local UI = Create("ScreenGui", { Name = "MBChat_Universal", Parent = CoreGui, ResetOnSpawn = false })

-- Variáveis de Posição e Escala
local uiScale = LocalData.settings.menuSize
local menuPos = UDim2.new(0.5, -150, 0.5, -250)

local MainFrame = Create("Frame", {
    Parent = UI, Size = UDim2.new(0, 300 * uiScale, 0, 500 * uiScale), Position = menuPos,
    BackgroundColor3 = Color3.fromRGB(20, 20, 20), BackgroundTransparency = 0.05,
    Active = true, Draggable = true, ClipsDescendants = true
})
local Corner = Create("UICorner", { Parent = MainFrame, CornerRadius = UDim.new(0, 12) })

-- Bolha de Minimizar
local Bubble = Create("TextButton", {
    Parent = UI, Size = UDim2.new(0, 50, 0, 50), BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    Text = "D", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextSize = 20,
    Visible = false, Active = true, Draggable = true
})
Create("UICorner", { Parent = Bubble, CornerRadius = UDim.new(1, 0) })

-- TopBar
local TopBar = Create("Frame", {
    Parent = MainFrame, Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromRGB(30, 30, 30)
})
local Title = Create("TextLabel", {
    Parent = TopBar, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 10, 0, 0),
    BackgroundTransparency = 1, Text = "MBChat", TextColor3 = Color3.new(1,1,1),
    Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left
})
local MinBtn = Create("TextButton", {
    Parent = TopBar, Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -35, 0, 5),
    BackgroundColor3 = Color3.fromRGB(50, 50, 50), Text = "-", TextColor3 = Color3.new(1,1,1)
})
Create("UICorner", { Parent = MinBtn, CornerRadius = UDim.new(0, 6) })

-- Lógica de Minimizar
MinBtn.MouseButton1Click:Connect(function()
    menuPos = MainFrame.Position
    MainFrame.Visible = false
    Bubble.Position = UDim2.new(0, menuPos.X.Offset + (MainFrame.Size.X.Offset/2), 0, menuPos.Y.Offset)
    Bubble.Visible = true
end)
Bubble.MouseButton1Click:Connect(function()
    Bubble.Visible = false
    MainFrame.Position = menuPos
    MainFrame.Visible = true
end)

-- Container de Telas
local ContentContainer = Create("Frame", {
    Parent = MainFrame, Size = UDim2.new(1, 0, 1, -90), Position = UDim2.new(0, 0, 0, 40),
    BackgroundTransparency = 1
})

-- Barra de Navegação (Bottom)
local NavBar = Create("Frame", {
    Parent = MainFrame, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 1, -50),
    BackgroundColor3 = Color3.fromRGB(25, 25, 25)
})
local Tabs = {"Amigos", "Notificações", "Chats", "Config"}
local Screens = {}

for i, tabName in ipairs(Tabs) do
    local btn = Create("TextButton", {
        Parent = NavBar, Size = UDim2.new(0.25, 0, 1, 0), Position = UDim2.new((i-1)*0.25, 0, 0, 0),
        BackgroundTransparency = 1, Text = tabName, TextColor3 = Color3.fromRGB(150, 150, 150),
        Font = Enum.Font.Gotham, TextSize = 12
    })
    
    local screen = Create("ScrollingFrame", {
        Parent = ContentContainer, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Visible = (i == 1), CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 4
    })
    Create("UIListLayout", { Parent = screen, Padding = UDim.new(0, 5) })
    Screens[tabName] = screen
    
    btn.MouseButton1Click:Connect(function()
        for _, s in pairs(Screens) do s.Visible = false end
        screen.Visible = true
        for _, b in pairs(NavBar:GetChildren()) do if b:IsA("TextButton") then b.TextColor3 = Color3.fromRGB(150, 150, 150) end end
        btn.TextColor3 = Color3.new(1, 1, 1)
    end)
end

-- --- SISTEMA DE PESQUISA E AMIGOS ---
local SearchBox = Create("TextBox", {
    Parent = Screens["Amigos"], Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0, 5),
    BackgroundColor3 = Color3.fromRGB(40, 40, 40), TextColor3 = Color3.new(1,1,1),
    PlaceholderText = "Procurar amigos (Username)", Font = Enum.Font.Gotham, TextSize = 14
})
local SearchResults = Create("Frame", { Parent = Screens["Amigos"], Size = UDim2.new(1, 0, 0, 400), BackgroundTransparency = 1 })
local SearchLayout = Create("UIListLayout", { Parent = SearchResults, Padding = UDim.new(0, 5) })

local function RenderSearch(query)
    for _, child in pairs(SearchResults:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    if query == "" then return end
    
    -- Pesquisa assíncrona baseada no Roblox Players API (Mock para pesquisa universal requer backend dedicado, usando Players no servidor atual como base de "possíveis amigos")
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and string.match(string.lower(p.Name), string.lower(query)) then
            local pid = tostring(p.UserId)
            if not LocalData.friends[pid] then
                local card = Create("Frame", { Parent = SearchResults, Size = UDim2.new(1, -10, 0, 50), Position = UDim2.new(0, 5, 0, 0), BackgroundColor3 = Color3.fromRGB(35, 35, 35) })
                Create("UICorner", { Parent = card, CornerRadius = UDim.new(0, 8) })
                
                -- Avatar Square
                local avatar = Create("ImageLabel", { Parent = card, Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1 })
                Create("UICorner", { Parent = avatar, CornerRadius = UDim.new(0, 8) })
                task.spawn(function()
                    avatar.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                end)
                
                Create("TextLabel", { Parent = card, Size = UDim2.new(0, 150, 0, 20), Position = UDim2.new(0, 55, 0, 5), BackgroundTransparency = 1, Text = p.DisplayName, TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
                Create("TextLabel", { Parent = card, Size = UDim2.new(0, 150, 0, 20), Position = UDim2.new(0, 55, 0, 25), BackgroundTransparency = 1, Text = "@" .. p.Name, TextColor3 = Color3.fromRGB(150,150,150), Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left })
                
                local addBtn = Create("TextButton", { Parent = card, Size = UDim2.new(0, 70, 0, 30), Position = UDim2.new(1, -75, 0, 10), BackgroundColor3 = Color3.fromRGB(40, 150, 40), Text = "Adicionar", TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamBold })
                Create("UICorner", { Parent = addBtn, CornerRadius = UDim.new(0, 6) })
                
                addBtn.MouseButton1Click:Connect(function()
                    addBtn.Text = "Enviado"
                    ws.Send({ type = "friend_request", targetId = pid, username = LocalPlayer.Name, displayName = LocalPlayer.DisplayName })
                end)
            end
        end
    end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(function() RenderSearch(SearchBox.Text) end)

-- --- REDE WEBSOCKET ---
local function ConnectWS()
    pcall(function()
        if ws then ws:Close() end
        ws = WebSocket.connect(WS_URL)
        isConnected = true
        
        ws:Send(HttpService:JSONEncode({ type = "register", userId = UserId }))
        
        ws.OnMessage:Connect(function(msg)
            local data = HttpService:JSONDecode(msg)
            
            if data.type == "friend_request" then
                table.insert(LocalData.notifications, { type = "friend", fromId = data.fromId, username = data.username, displayName = data.displayName })
                SaveData()
                UpdateNotifications()
            elseif data.type == "friend_accept" then
                LocalData.friends[data.fromId] = { username = data.username, displayName = data.displayName }
                SaveData()
            elseif data.type == "chat_message" then
                local chatId = data.chatId
                if not LocalData.chats[chatId] then LocalData.chats[chatId] = { history = {} } end
                table.insert(LocalData.chats[chatId].history, { sender = data.fromId, text = data.text, isSticker = data.isSticker })
                SaveData()
                if ActiveChatId == chatId then RenderChatHistory(chatId, false) end
            elseif data.type == "group_message" then
                local groupId = data.groupId
                if LocalData.groups[groupId] then
                    table.insert(LocalData.groups[groupId].history, { sender = data.fromId, text = data.text, isSticker = data.isSticker })
                    SaveData()
                    if ActiveGroupId == groupId then RenderChatHistory(groupId, true) end
                end
            elseif data.type == "group_background" then
                if LocalData.groups[data.groupId] then
                    LocalData.groups[data.groupId].bg = data.bgImage
                    SaveData()
                    if ActiveGroupId == data.groupId then ApplyBackground(data.bgImage) end
                end
            elseif data.type == "clone_invite" then
                table.insert(LocalData.notifications, { type = "clone_invite", fromId = data.fromId, username = data.username })
                UpdateNotifications()
            elseif data.type == "clone_accept" then
                ActivateClone(data.fromId)
            end
        end)
        
        ws.OnClose:Connect(function()
            isConnected = false
            task.wait(5)
            ConnectWS() -- Reconexão automática
        end)
    end)
end
ws = { Send = function(t) if isConnected then ws:Send(HttpService:JSONEncode(t)) end end }
task.spawn(ConnectWS)

-- --- NOTIFICAÇÕES ---
function UpdateNotifications()
    for _, child in pairs(Screens["Notificações"]:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    
    for i, notif in ipairs(LocalData.notifications) do
        local card = Create("Frame", { Parent = Screens["Notificações"], Size = UDim2.new(1, -10, 0, 70), Position = UDim2.new(0, 5, 0, 0), BackgroundColor3 = Color3.fromRGB(35, 35, 35) })
        Create("UICorner", { Parent = card, CornerRadius = UDim.new(0, 8) })
        
        local text = Create("TextLabel", { Parent = card, Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, Text = notif.username .. " enviou um pedido de " .. notif.type, TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Gotham, TextScaled = true })
        
        local btnAccept = Create("TextButton", { Parent = card, Size = UDim2.new(0, 80, 0, 25), Position = UDim2.new(0, 10, 0, 40), BackgroundColor3 = Color3.fromRGB(40, 100, 150), Text = "Aceitar", TextColor3 = Color3.new(1,1,1) })
        local btnReject = Create("TextButton", { Parent = card, Size = UDim2.new(0, 80, 0, 25), Position = UDim2.new(0, 100, 0, 40), BackgroundColor3 = Color3.fromRGB(150, 40, 40), Text = "Recusar", TextColor3 = Color3.new(1,1,1) })
        Create("UICorner", { Parent = btnAccept, CornerRadius = UDim.new(0, 4) }) Create("UICorner", { Parent = btnReject, CornerRadius = UDim.new(0, 4) })
        
        btnAccept.MouseButton1Click:Connect(function()
            if notif.type == "friend" then
                LocalData.friends[notif.fromId] = { username = notif.username, displayName = notif.displayName }
                ws.Send({ type = "friend_accept", targetId = notif.fromId, username = LocalPlayer.Name, displayName = LocalPlayer.DisplayName })
            elseif notif.type == "clone_invite" then
                ws.Send({ type = "clone_accept", targetId = notif.fromId })
                ActivateClone(notif.fromId)
            end
            table.remove(LocalData.notifications, i)
            SaveData()
            UpdateNotifications()
        end)
        
        btnReject.MouseButton1Click:Connect(function()
            table.remove(LocalData.notifications, i)
            SaveData()
            UpdateNotifications()
        end)
    end
end
UpdateNotifications()

-- --- CHAT & HISTÓRICO ---
-- Chat View UI
local ChatView = Create("Frame", { Parent = MainFrame, Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0,0,0,40), BackgroundColor3 = Color3.fromRGB(15,15,15), Visible = false, ZIndex = 5 })
local BgImage = Create("ImageLabel", { Parent = ChatView, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ImageTransparency = 0.8, ZIndex = 4, ScaleType = Enum.ScaleType.Crop })
local ChatHistoryScroll = Create("ScrollingFrame", { Parent = ChatView, Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1, ZIndex = 6, CanvasSize = UDim2.new(0,0,0,0) })
local ChatLayout = Create("UIListLayout", { Parent = ChatHistoryScroll, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })
local ChatControls = Create("Frame", { Parent = ChatView, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 1, -50), BackgroundColor3 = Color3.fromRGB(20,20,20), ZIndex = 6 })
local BtnSticker = Create("TextButton", { Parent = ChatControls, Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 5, 0, 5), BackgroundColor3 = Color3.fromRGB(40,40,40), Text = "S", TextColor3 = Color3.new(1,1,1) })
Create("UICorner", { Parent = BtnSticker, CornerRadius = UDim.new(0, 20) })
local ChatContextInfo = Create("TextLabel", { Parent = ChatControls, Size = UDim2.new(1, -55, 0, 40), Position = UDim2.new(0, 50, 0, 5), BackgroundTransparency = 1, Text = "Use o chat do Roblox para digitar", TextColor3 = Color3.fromRGB(150,150,150), Font = Enum.Font.GothamItalic, TextSize = 12 })
local BtnBackChat = Create("TextButton", { Parent = ChatView, Size = UDim2.new(0, 40, 0, 30), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 0.5, BackgroundColor3 = Color3.new(0,0,0), Text = "< Voltar", TextColor3 = Color3.new(1,1,1), ZIndex = 10 })
BtnBackChat.MouseButton1Click:Connect(function() ChatView.Visible = false; ActiveChatId = nil; ActiveGroupId = nil end)

function RenderChatHistory(id, isGroup)
    for _, c in pairs(ChatHistoryScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local history = isGroup and LocalData.groups[id].history or LocalData.chats[id].history
    local yOffset = 0
    
    for i, msg in ipairs(history) do
        local isMe = (msg.sender == UserId)
        local bColor = isMe and Color3.fromRGB(30, 80, 50) or Color3.fromRGB(45, 45, 45)
        local align = isMe and UDim2.new(1, -210, 0, 0) or UDim2.new(0, 10, 0, 0)
        
        local bubble = Create("Frame", { Parent = ChatHistoryScroll, Size = UDim2.new(0, 200, 0, 0), Position = align, BackgroundColor3 = bColor })
        Create("UICorner", { Parent = bubble, CornerRadius = UDim.new(0, 8) })
        
        if msg.isSticker then
            bubble.Size = UDim2.new(0, 120, 0, 120)
            local img = Create("ImageLabel", { Parent = bubble, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, Image = msg.text })
            -- Visualização ampliada
            local btnZoom = Create("TextButton", { Parent = img, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "" })
            btnZoom.MouseButton1Click:Connect(function() ShowStickerZoom(msg.text) end)
        else
            local txt = Create("TextLabel", { Parent = bubble, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5), BackgroundTransparency = 1, Text = msg.text, TextColor3 = Color3.new(1,1,1), Font = Enum.Font.Gotham, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
            bubble.Size = UDim2.new(0, 200, 0, txt.TextBounds.Y + 20)
        end
        yOffset = yOffset + bubble.Size.Y.Offset + 5
    end
    ChatHistoryScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
    ChatHistoryScroll.CanvasPosition = Vector2.new(0, yOffset)
end

function ApplyBackground(imgUrl)
    if imgUrl and imgUrl ~= "nenhuma" then
        BgImage.Image = imgUrl
        BgImage.Visible = true
    else
        BgImage.Visible = false
    end
end

-- Interceptação de Texto (TextChatService & Chatted)
local function HandleOutgoingMessage(message)
    if ActiveChatId then
        ws.Send({ type = "chat_message", targetId = ActiveChatId, text = message })
        table.insert(LocalData.chats[ActiveChatId].history, { sender = UserId, text = message })
        SaveData()
        RenderChatHistory(ActiveChatId, false)
        return true
    elseif ActiveGroupId then
        if message:sub(1, 2) == "//" or message:sub(1, 1) == "/" then
            ProcessGroupCommand(message, ActiveGroupId)
        else
            ws.Send({ type = "group_message", groupId = ActiveGroupId, text = message })
            table.insert(LocalData.groups[ActiveGroupId].history, { sender = UserId, text = message })
            SaveData()
            RenderChatHistory(ActiveGroupId, true)
        end
        return true
    end
    return false
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.SendingMessage:Connect(function(msg)
        if HandleOutgoingMessage(msg.Text) then
            -- Intercepta para não ir ao servidor do Roblox visualmente se possível, 
            -- TextChatService não permite cancelamento nativo fácil via script local injetado, 
            -- mas o envio de dados via WS está garantido.
        end
    end)
else
    LocalPlayer.Chatted:Connect(function(msg)
        HandleOutgoingMessage(msg)
    end)
end

-- Comandos de Grupo
function ProcessGroupCommand(msg, groupId)
    local args = string.split(msg, " ")
    local cmd = args[1]
    local target = args[2] and string.gsub(args[2], "@", "") or nil
    
    local targetId = nil
    if target then
        for fid, fdata in pairs(LocalData.friends) do
            if string.lower(fdata.username) == string.lower(target) then targetId = fid break end
        end
    end

    if cmd == "//invitegp" and targetId then
        ws.Send({ type = "group_invite", groupId = groupId, targetId = targetId })
    elseif cmd == "//ban" and targetId then
        ws.Send({ type = "group_ban", groupId = groupId, targetId = targetId })
    elseif cmd == "//kick" and targetId then
        ws.Send({ type = "group_kick", groupId = groupId, targetId = targetId })
    elseif cmd == "//deletegp" then
        ws.Send({ type = "group_delete_confirm", groupId = groupId })
        LocalData.groups[groupId] = nil
        SaveData()
        ChatView.Visible = false
    elseif cmd == "/background" then
        OpenBackgroundMenu(groupId)
    end
end

-- --- STICKERS ---
local StickerPanel = Create("Frame", { Parent = ChatView, Size = UDim2.new(1, 0, 0, 200), Position = UDim2.new(0, 0, 1, -250), BackgroundColor3 = Color3.fromRGB(25,25,25), Visible = false, ZIndex = 10 })
local StickerScroll = Create("ScrollingFrame", { Parent = StickerPanel, Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0,0,0,40), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,500) })
local StickerGrid = Create("UIGridLayout", { Parent = StickerScroll, CellSize = UDim2.new(0, 60, 0, 60), CellPadding = UDim2.new(0, 5, 0, 5) })
local StickerSearch = Create("TextBox", { Parent = StickerPanel, Size = UDim2.new(1, -10, 0, 30), Position = UDim2.new(0, 5, 0, 5), BackgroundColor3 = Color3.fromRGB(40,40,40), TextColor3 = Color3.new(1,1,1), PlaceholderText = "Encontre a figurinha perfeita" })

BtnSticker.MouseButton1Click:Connect(function() StickerPanel.Visible = not StickerPanel.Visible end)

-- Fetch Stickers from GitHub via API
task.spawn(function()
    local success, res = pcall(function() return HttpService:GetAsync(REPO_URL .. "/Stickers") end)
    if success then
        local files = HttpService:JSONDecode(res)
        for _, file in ipairs(files) do
            if file.type == "file" then
                local btn = Create("ImageButton", { Parent = StickerScroll, BackgroundTransparency = 1, Image = file.download_url })
                btn.MouseButton1Click:Connect(function()
                    StickerPanel.Visible = false
                    if ActiveChatId then
                        ws.Send({ type = "sticker_message", targetId = ActiveChatId, text = file.download_url, isSticker = true })
                        table.insert(LocalData.chats[ActiveChatId].history, { sender = UserId, text = file.download_url, isSticker = true })
                        RenderChatHistory(ActiveChatId, false)
                    elseif ActiveGroupId then
                        ws.Send({ type = "group_message", groupId = ActiveGroupId, text = file.download_url, isSticker = true })
                        table.insert(LocalData.groups[ActiveGroupId].history, { sender = UserId, text = file.download_url, isSticker = true })
                        RenderChatHistory(ActiveGroupId, true)
                    end
                    SaveData()
                end)
            end
        end
    end
end)

local ModalZoom = Create("Frame", { Parent = UI, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 0.5, Visible = false, ZIndex = 100 })
local ZoomImg = Create("ImageLabel", { Parent = ModalZoom, Size = UDim2.new(0, 300, 0, 300), Position = UDim2.new(0.5, -150, 0.5, -150), BackgroundTransparency = 1 })
local ZoomBtnClose = Create("TextButton", { Parent = ModalZoom, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "" })
ZoomBtnClose.MouseButton1Click:Connect(function() ModalZoom.Visible = false end)

function ShowStickerZoom(url)
    ZoomImg.Image = url
    ModalZoom.Visible = true
end

-- --- BACKGROUNDS MENU ---
function OpenBackgroundMenu(groupId)
    local BgPanel = Create("Frame", { Parent = ChatView, Size = UDim2.new(1, 0, 0, 200), Position = UDim2.new(0, 0, 1, -250), BackgroundColor3 = Color3.fromRGB(25,25,25), ZIndex = 11 })
    local Scroll = Create("ScrollingFrame", { Parent = BgPanel, Size = UDim2.new(1,0,1,-40), Position = UDim2.new(0,0,0,40), BackgroundTransparency=1 })
    Create("UIGridLayout", { Parent = Scroll, CellSize = UDim2.new(0, 80, 0, 80) })
    
    local btnNone = Create("TextButton", { Parent = Scroll, BackgroundColor3 = Color3.fromRGB(50,50,50), Text = "Nenhuma", TextColor3 = Color3.new(1,1,1) })
    btnNone.MouseButton1Click:Connect(function()
        BgImage.Visible = false
        ws.Send({ type = "group_background", groupId = groupId, bgImage = "nenhuma" })
        BgPanel:Destroy()
    end)

    task.spawn(function()
        local success, res = pcall(function() return HttpService:GetAsync(REPO_URL .. "/Background%20images") end)
        if success then
            local files = HttpService:JSONDecode(res)
            for _, file in ipairs(files) do
                if file.type == "file" then
                    local btn = Create("ImageButton", { Parent = Scroll, Image = file.download_url })
                    btn.MouseButton1Click:Connect(function()
                        BgImage.Image = file.download_url
                        BgImage.Visible = true
                        ws.Send({ type = "group_background", groupId = groupId, bgImage = file.download_url })
                        BgPanel:Destroy()
                    end)
                end
            end
        end
    end)
end

-- --- CLONE / REPRESENTAÇÃO LOCAL ---
function ActivateClone(targetUserId)
    if ActiveClone then ActiveClone:Destroy() end
    local success, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(tonumber(targetUserId)) end)
    if success then
        -- Mock usando Dummy R15 local, aplica a aparência do alvo
        local dummy = game:GetObjects("rbxassetid://68452456")[1] 
        dummy.Parent = workspace
        dummy:SetPrimaryPartCFrame(LocalPlayer.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -4))
        dummy.Humanoid:ApplyDescription(desc)
        ActiveClone = dummy
    end
end

-- --- CONFIGURAÇÕES ---
local ConfigLayout = Create("UIListLayout", { Parent = Screens["Config"], Padding = UDim.new(0, 10) })
local ScaleFrame = Create("Frame", { Parent = Screens["Config"], Size = UDim2.new(1, -10, 0, 50), BackgroundColor3 = Color3.fromRGB(35,35,35) })
Create("TextLabel", { Parent = ScaleFrame, Size = UDim2.new(1,0,0,20), BackgroundTransparency=1, Text="Menu Size", TextColor3=Color3.new(1,1,1) })
local BtnMinus = Create("TextButton", { Parent = ScaleFrame, Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 10, 0, 20), Text = "-", BackgroundColor3 = Color3.fromRGB(50,50,50), TextColor3 = Color3.new(1,1,1) })
local BtnPlus = Create("TextButton", { Parent = ScaleFrame, Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -40, 0, 20), Text = "+", BackgroundColor3 = Color3.fromRGB(50,50,50), TextColor3 = Color3.new(1,1,1) })
local BtnReset = Create("TextButton", { Parent = ScaleFrame, Size = UDim2.new(0, 60, 0, 30), Position = UDim2.new(0.5, -30, 0, 20), Text = "Reset", BackgroundColor3 = Color3.fromRGB(150,50,50), TextColor3 = Color3.new(1,1,1) })

local function UpdateScale()
    MainFrame.Size = UDim2.new(0, 300 * uiScale, 0, 500 * uiScale)
    LocalData.settings.menuSize = uiScale
    SaveData()
end

BtnMinus.MouseButton1Click:Connect(function() uiScale = math.max(0.5, uiScale - 0.1); UpdateScale() end)
BtnPlus.MouseButton1Click:Connect(function() uiScale = math.min(2.0, uiScale + 0.1); UpdateScale() end)
BtnReset.MouseButton1Click:Connect(function() uiScale = 1; UpdateScale() end)

-- Inicialização da Lista de Chats
local function RefreshChatList()
    local container = Screens["Chats"]
    for _, c in pairs(container:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    local btnCreateGroup = Create("TextButton", { Parent = container, Size = UDim2.new(1,-10,0,40), BackgroundColor3=Color3.fromRGB(40,100,40), Text="Criar Grupo", TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold })
    Create("UICorner", { Parent = btnCreateGroup, CornerRadius=UDim.new(0,8) })
    
    btnCreateGroup.MouseButton1Click:Connect(function()
        local groupId = "grp_" .. HttpService:GenerateGUID(false)
        LocalData.groups[groupId] = { ownerId = UserId, history = {}, bg = "nenhuma" }
        ws.Send({ type = "group_create", groupId = groupId })
        SaveData()
        RefreshChatList()
    end)

    -- Listar Amigos para Chat Privado
    for fid, fdata in pairs(LocalData.friends) do
        local btn = Create("TextButton", { Parent = container, Size = UDim2.new(1,-10,0,50), BackgroundColor3=Color3.fromRGB(35,35,35), Text=" Chat com: " .. fdata.username, TextColor3=Color3.new(1,1,1), TextXAlignment=Enum.TextXAlignment.Left })
        btn.MouseButton1Click:Connect(function()
            ActiveChatId = fid
            ActiveGroupId = nil
            if not LocalData.chats[fid] then LocalData.chats[fid] = { history = {} } end
            ChatView.Visible = true
            RenderChatHistory(fid, false)
        end)
    end
    
    -- Listar Grupos
    for gid, gdata in pairs(LocalData.groups) do
        local btn = Create("TextButton", { Parent = container, Size = UDim2.new(1,-10,0,50), BackgroundColor3=Color3.fromRGB(50,35,50), Text=" Grupo: " .. gid:sub(1,8), TextColor3=Color3.new(1,1,1), TextXAlignment=Enum.TextXAlignment.Left })
        btn.MouseButton1Click:Connect(function()
            ActiveGroupId = gid
            ActiveChatId = nil
            ChatView.Visible = true
            ApplyBackground(gdata.bg)
            RenderChatHistory(gid, true)
        end)
    end
end

-- Refresh Loops
task.spawn(function()
    while true do
        RefreshChatList()
        task.wait(5)
    end
end)
