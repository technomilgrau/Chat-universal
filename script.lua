-- Chat Universal - techno_milgrau
-- Compatível com Delta Executor

local SERVER_URL = "wss://chat-universal-online.onrender.com" -- Digite seu WSS da Render aqui
local GITHUB_STICKERS_URL = "https://api.github.com/repos/technomilgrau/Chat-universal/contents/Stickers"
local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/technomilgrau/Chat-universal/main/Stickers/"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Gerenciamento de Arquivo Local (Armazenamento Permanente no Celular)
local FOLDER_NAME = "Chat-universal"
local FILE_PATH = FOLDER_NAME .. "/chat_data.json"

if not isfolder(FOLDER_NAME) then
    makefolder(FOLDER_NAME)
end

local LocalData = {
    friends = {}, -- { [userId] = username }
    chats = {},   -- { [userId] = { {sender = "me/them", type = "text/sticker", content = "...", time = "..."}, ... } }
    recentStickers = {} -- Max 5
}

function SaveLocalData()
    writefile(FILE_PATH, HttpService:JSONEncode(LocalData))
end

function LoadLocalData()
    if isfile(FILE_PATH) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(FILE_PATH))
        end)
        if success and result then
            LocalData = result
        end
    else
        SaveLocalData()
    end
end

LoadLocalData()

-- WebSocket Connection
local ws = nil
local activeChatUserId = nil
local friendRequests = {}
local presenceStatuses = {} -- [userId] = "online" | "offline" | "digitando..."

-- UI Blueprint Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatUniversalUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 340, 0, 520)
MainFrame.Position = UDim2.new(0.5, -170, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 16)
MainCorner.Parent = MainFrame

-- Top Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 60)
Header.BackgroundTransparency = 1
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Text = "Chat universal"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Position = UDim2.new(0, 16, 0, 12)
Title.Size = UDim2.new(0, 200, 0, 22)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Text = "techno_milgrau"
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 12
Subtitle.TextColor3 = Color3.fromRGB(140, 140, 150)
Subtitle.Position = UDim2.new(0, 16, 0, 34)
Subtitle.Size = UDim2.new(0, 200, 0, 16)
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

-- Botão de Notificações (Sino)
local BellBtn = Instance.new("ImageButton")
BellBtn.Size = UDim2.new(0, 28, 0, 28)
BellBtn.Position = UDim2.new(1, -44, 0, 16)
BellBtn.BackgroundTransparency = 1
BellBtn.Image = "rbxassetid://6031081531" -- Ícone de sino
BellBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
BellBtn.Parent = Header

local BellBadge = Instance.new("TextLabel")
BellBadge.Size = UDim2.new(0, 16, 0, 16)
BellBadge.Position = UDim2.new(1, -6, 0, -2)
BellBadge.BackgroundColor3 = Color3.fromRGB(255, 50, 80)
BellBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
BellBadge.Font = Enum.Font.GothamBold
BellBadge.TextSize = 10
BellBadge.Text = "0"
BellBadge.Visible = false
BellBadge.Parent = BellBtn

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(1, 0)
BadgeCorner.Parent = BellBadge

-- Área Principal de Conteúdo
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, 0, 1, -115)
ContentArea.Position = UDim2.new(0, 0, 0, 60)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- ABA 1: INÍCIO / PESQUISA
local HomeTab = Instance.new("Frame")
HomeTab.Size = UDim2.new(1, 0, 1, 0)
HomeTab.BackgroundTransparency = 1
HomeTab.Parent = ContentArea

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -32, 0, 40)
SearchBox.Position = UDim2.new(0, 16, 0, 0)
SearchBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.PlaceholderText = "procurar amigos"
SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 14
SearchBox.Text = ""
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = HomeTab

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 10)
SearchCorner.Parent = SearchBox

local SearchResultsScroll = Instance.new("ScrollingFrame")
SearchResultsScroll.Size = UDim2.new(1, -32, 1, -50)
SearchResultsScroll.Position = UDim2.new(0, 16, 0, 50)
SearchResultsScroll.BackgroundTransparency = 1
SearchResultsScroll.ScrollBarThickness = 2
SearchResultsScroll.Parent = HomeTab

local SearchLayout = Instance.new("UIListLayout")
SearchLayout.Padding = UDim.new(0, 8)
SearchLayout.Parent = SearchResultsScroll

-- ABA 2: MENSAGENS / LISTA DE AMIGOS
local MessagesTab = Instance.new("Frame")
MessagesTab.Size = UDim2.new(1, 0, 1, 0)
MessagesTab.BackgroundTransparency = 1
MessagesTab.Visible = false
MessagesTab.Parent = ContentArea

local FriendsScroll = Instance.new("ScrollingFrame")
FriendsScroll.Size = UDim2.new(1, -32, 1, 0)
FriendsScroll.Position = UDim2.new(0, 16, 0, 0)
FriendsScroll.BackgroundTransparency = 1
FriendsScroll.ScrollBarThickness = 2
FriendsScroll.Parent = MessagesTab

local FriendsLayout = Instance.new("UIListLayout")
FriendsLayout.Padding = UDim.new(0, 8)
FriendsLayout.Parent = FriendsScroll

-- JANELA DE NOTIFICAÇÕES (POPUP)
local NotificationsFrame = Instance.new("Frame")
NotificationsFrame.Size = UDim2.new(1, -32, 0, 200)
NotificationsFrame.Position = UDim2.new(0, 16, 0, 50)
NotificationsFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
NotificationsFrame.Visible = false
NotificationsFrame.ZIndex = 10
NotificationsFrame.Parent = MainFrame

local NotifCorner = Instance.new("UICorner")
NotifCorner.CornerRadius = UDim.new(0, 12)
NotifCorner.Parent = NotificationsFrame

local NotifScroll = Instance.new("ScrollingFrame")
NotifScroll.Size = UDim2.new(1, -16, 1, -16)
NotifScroll.Position = UDim2.new(0, 8, 0, 8)
NotifScroll.BackgroundTransparency = 1
NotifScroll.ZIndex = 11
NotifScroll.Parent = NotificationsFrame

local NotifLayout = Instance.new("UIListLayout")
NotifLayout.Padding = UDim.new(0, 6)
NotifLayout.Parent = NotifScroll

-- JANELA DE CHAT PRIVADO (Estilo Instagram/TikTok)
local ChatWindow = Instance.new("Frame")
ChatWindow.Size = UDim2.new(1, 0, 1, 0)
ChatWindow.Position = UDim2.new(1, 0, 0, 0) -- Fora da tela inicialmente
ChatWindow.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
ChatWindow.ZIndex = 5
ChatWindow.Parent = MainFrame

local ChatHeader = Instance.new("Frame")
ChatHeader.Size = UDim2.new(1, 0, 0, 55)
ChatHeader.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
ChatHeader.ZIndex = 6
ChatHeader.Parent = ChatWindow

local BackBtn = Instance.new("TextButton")
BackBtn.Size = UDim2.new(0, 30, 0, 30)
BackBtn.Position = UDim2.new(0, 10, 0, 12)
BackBtn.BackgroundTransparency = 1
BackBtn.Text = "<"
BackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BackBtn.Font = Enum.Font.GothamBold
BackBtn.TextSize = 20
BackBtn.ZIndex = 6
BackBtn.Parent = ChatHeader

local ChatAvatar = Instance.new("ImageLabel")
ChatAvatar.Size = UDim2.new(0, 36, 0, 36)
ChatAvatar.Position = UDim2.new(0, 45, 0, 9)
ChatAvatar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ChatAvatar.ZIndex = 6
ChatAvatar.Parent = ChatHeader

local ChatAvatarCorner = Instance.new("UICorner")
ChatAvatarCorner.CornerRadius = UDim.new(1, 0)
ChatAvatarCorner.Parent = ChatAvatar

local ChatName = Instance.new("TextLabel")
ChatName.Size = UDim2.new(0, 180, 0, 18)
ChatName.Position = UDim2.new(0, 90, 0, 10)
ChatName.Font = Enum.Font.GothamBold
ChatName.TextSize = 14
ChatName.TextColor3 = Color3.fromRGB(255, 255, 255)
ChatName.TextXAlignment = Enum.TextXAlignment.Left
ChatName.ZIndex = 6
ChatName.Parent = ChatHeader

local ChatStatus = Instance.new("TextLabel")
ChatStatus.Size = UDim2.new(0, 180, 0, 14)
ChatStatus.Position = UDim2.new(0, 90, 0, 28)
ChatStatus.Font = Enum.Font.Gotham
ChatStatus.TextSize = 11
ChatStatus.TextColor3 = Color3.fromRGB(140, 140, 150)
ChatStatus.Text = "offline"
ChatStatus.TextXAlignment = Enum.TextXAlignment.Left
ChatStatus.ZIndex = 6
ChatStatus.Parent = ChatHeader

local MessagesScroll = Instance.new("ScrollingFrame")
MessagesScroll.Size = UDim2.new(1, -20, 1, -115)
MessagesScroll.Position = UDim2.new(0, 10, 0, 60)
MessagesScroll.BackgroundTransparency = 1
MessagesScroll.ScrollBarThickness = 2
MessagesScroll.ZIndex = 5
MessagesScroll.Parent = ChatWindow

local MessagesLayout = Instance.new("UIListLayout")
MessagesLayout.Padding = UDim.new(0, 8)
MessagesLayout.VerticalAlignment = Enum.VerticalAlignment.Top
MessagesLayout.Parent = MessagesScroll

-- Input do Chat & Botão de Figurinhas
local ChatInputFrame = Instance.new("Frame")
ChatInputFrame.Size = UDim2.new(1, -20, 0, 42)
ChatInputFrame.Position = UDim2.new(0, 10, 1, -48)
ChatInputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInputFrame.ZIndex = 6
ChatInputFrame.Parent = ChatWindow

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 21)
InputCorner.Parent = ChatInputFrame

local EmojiBtn = Instance.new("TextButton")
EmojiBtn.Size = UDim2.new(0, 30, 0, 30)
EmojiBtn.Position = UDim2.new(0, 8, 0, 6)
EmojiBtn.BackgroundTransparency = 1
EmojiBtn.Text = "😀"
EmojiBtn.TextSize = 18
EmojiBtn.ZIndex = 6
EmojiBtn.Parent = ChatInputFrame

local ChatTextBox = Instance.new("TextBox")
ChatTextBox.Size = UDim2.new(1, -85, 1, 0)
ChatTextBox.Position = UDim2.new(0, 42, 0, 0)
ChatTextBox.BackgroundTransparency = 1
ChatTextBox.PlaceholderText = "Mensagem..."
ChatTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
ChatTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
ChatTextBox.Font = Enum.Font.Gotham
ChatTextBox.TextSize = 13
ChatTextBox.Text = ""
ChatTextBox.ZIndex = 6
ChatTextBox.Parent = ChatInputFrame

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0, 30, 0, 30)
SendBtn.Position = UDim2.new(1, -35, 0, 6)
SendBtn.BackgroundTransparency = 1
SendBtn.Text = "➔"
SendBtn.TextColor3 = Color3.fromRGB(0, 140, 255)
SendBtn.Font = Enum.Font.GothamBold
SendBtn.TextSize = 16
SendBtn.ZIndex = 6
SendBtn.Parent = ChatInputFrame

-- PAINEL DE FIGURINHAS (DRAWER / SLIDE UP)
local StickerDrawer = Instance.new("Frame")
StickerDrawer.Size = UDim2.new(1, 0, 0, 210)
StickerDrawer.Position = UDim2.new(0, 0, 1, 0) -- Escondido embaixo
StickerDrawer.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
StickerDrawer.ZIndex = 7
StickerDrawer.Parent = ChatWindow

local DrawerCorner = Instance.new("UICorner")
DrawerCorner.CornerRadius = UDim.new(0, 16)
DrawerCorner.Parent = StickerDrawer

local RecentLabel = Instance.new("TextLabel")
RecentLabel.Text = "Usado recentemente"
RecentLabel.Font = Enum.Font.GothamBold
RecentLabel.TextSize = 11
RecentLabel.TextColor3 = Color3.fromRGB(160, 160, 170)
RecentLabel.Position = UDim2.new(0, 12, 0, 8)
RecentLabel.Size = UDim2.new(0, 200, 0, 14)
RecentLabel.TextXAlignment = Enum.TextXAlignment.Left
RecentLabel.ZIndex = 8
RecentLabel.Parent = StickerDrawer

local RecentsFrame = Instance.new("Frame")
RecentsFrame.Size = UDim2.new(1, -24, 0, 50)
RecentsFrame.Position = UDim2.new(0, 12, 0, 26)
RecentsFrame.BackgroundTransparency = 1
RecentsFrame.ZIndex = 8
RecentsFrame.Parent = StickerDrawer

local RecentsLayout = Instance.new("UIListLayout")
RecentsLayout.FillDirection = Enum.FillDirection.Horizontal
RecentsLayout.Padding = UDim.new(0, 8)
RecentsLayout.Parent = RecentsFrame

local AllStickersScroll = Instance.new("ScrollingFrame")
AllStickersScroll.Size = UDim2.new(1, -24, 0, 120)
AllStickersScroll.Position = UDim2.new(0, 12, 0, 82)
AllStickersScroll.BackgroundTransparency = 1
AllStickersScroll.ScrollBarThickness = 2
AllStickersScroll.ZIndex = 8
AllStickersScroll.Parent = StickerDrawer

local StickersGrid = Instance.new("UIGridLayout")
StickersGrid.CellSize = UDim2.new(0, 50, 0, 50)
StickersGrid.CellPadding = UDim2.new(0, 8, 0, 8)
StickersGrid.Parent = AllStickersScroll

-- BARRA DE NAVEGAÇÃO INFERIOR (Estilo TikTok)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 55)
TabBar.Position = UDim2.new(0, 0, 1, -55)
TabBar.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
TabBar.Parent = MainFrame

local Tab1Btn = Instance.new("TextButton")
Tab1Btn.Size = UDim2.new(0.5, 0, 1, 0)
Tab1Btn.BackgroundTransparency = 1
Tab1Btn.Text = "Início"
Tab1Btn.Font = Enum.Font.GothamBold
Tab1Btn.TextSize = 13
Tab1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
Tab1Btn.Parent = TabBar

local Tab2Btn = Instance.new("TextButton")
Tab2Btn.Size = UDim2.new(0.5, 0, 1, 0)
Tab2Btn.Position = UDim2.new(0.5, 0, 0, 0)
Tab2Btn.BackgroundTransparency = 1
Tab2Btn.Text = "Mensagens"
Tab2Btn.Font = Enum.Font.Gotham
Tab2Btn.TextSize = 13
Tab2Btn.TextColor3 = Color3.fromRGB(120, 120, 130)
Tab2Btn.Parent = TabBar

-- NAVEGAÇÃO ENTRE ABAS
Tab1Btn.MouseButton1Click:Connect(function()
    HomeTab.Visible = true
    MessagesTab.Visible = false
    Tab1Btn.Font = Enum.Font.GothamBold
    Tab1Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Tab2Btn.Font = Enum.Font.Gotham
    Tab2Btn.TextColor3 = Color3.fromRGB(120, 120, 130)
end)

Tab2Btn.MouseButton1Click:Connect(function()
    HomeTab.Visible = false
    MessagesTab.Visible = true
    Tab2Btn.Font = Enum.Font.GothamBold
    Tab2Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Tab1Btn.Font = Enum.Font.Gotham
    Tab1Btn.TextColor3 = Color3.fromRGB(120, 120, 130)
    UpdateFriendsList()
end)

BellBtn.MouseButton1Click:Connect(function()
    NotificationsFrame.Visible = not NotificationsFrame.Visible
end)

-- SISTEMA DE WEBSOCKET & COMUNICAÇÃO
local function ConnectWebSocket()
    if WebSocket and WebSocket.connect then
        local success, connection = pcall(function()
            return WebSocket.connect(SERVER_URL)
        end)

        if success then
            ws = connection
            -- Registrar Usuário no Servidor
            ws:Send(HttpService:JSONEncode({
                type = "register",
                userId = tostring(LocalPlayer.UserId),
                username = LocalPlayer.Name
            }))

            ws.OnMessage:Connect(function(msg)
                local data = HttpService:JSONDecode(msg)

                if data.type == "search_results" then
                    RenderSearchResults(data.results)
                elseif data.type == "new_friend_request" then
                    table.insert(friendRequests, data.request)
                    UpdateNotifications()
                elseif data.type == "friend_requests" then
                    friendRequests = data.requests
                    UpdateNotifications()
                elseif data.type == "friend_accepted" then
                    LocalData.friends[tostring(data.userId)] = data.username
                    SaveLocalData()
                    UpdateFriendsList()
                elseif data.type == "private_message" then
                    ReceivePrivateMessage(data)
                elseif data.type == "presence_update" then
                    presenceStatuses[tostring(data.userId)] = data.status
                    if activeChatUserId == tostring(data.userId) then
                        ChatStatus.Text = data.status
                    end
                elseif data.type == "typing_status" then
                    if activeChatUserId == tostring(data.fromUserId) then
                        ChatStatus.Text = data.isTyping and "digitando..." or (presenceStatuses[activeChatUserId] or "online")
                    end
                end
            end)
        end
    end
end

-- PESQUISA DE USUÁRIOS
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local text = SearchBox.Text
    if #text > 0 and ws then
        ws:Send(HttpService:JSONEncode({
            type = "search_users",
            query = text
        }))
    else
        for _, child in pairs(SearchResultsScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
    end
end)

function RenderSearchResults(results)
    for _, child in pairs(SearchResultsScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, user in ipairs(results) do
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, 0, 0, 50)
        Card.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        Card.Parent = SearchResultsScroll

        local CardCorner = Instance.new("UICorner")
        CardCorner.CornerRadius = UDim.new(0, 8)
        CardCorner.Parent = Card

        local Avatar = Instance.new("ImageLabel")
        Avatar.Size = UDim2.new(0, 36, 0, 36)
        Avatar.Position = UDim2.new(0, 8, 0, 7)
        Avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. user.userId .. "&width=420&height=420&format=png"
        Avatar.Parent = Card

        local AvatarCorner = Instance.new("UICorner")
        AvatarCorner.CornerRadius = UDim.new(0, 6)
        AvatarCorner.Parent = Avatar

        local Name = Instance.new("TextLabel")
        Name.Text = user.username
        Name.Font = Enum.Font.GothamBold
        Name.TextSize = 13
        Name.TextColor3 = Color3.fromRGB(255, 255, 255)
        Name.Position = UDim2.new(0, 52, 0, 16)
        Name.Size = UDim2.new(0, 130, 0, 18)
        Name.TextXAlignment = Enum.TextXAlignment.Left
        Name.Parent = Card

        local AddBtn = Instance.new("TextButton")
        AddBtn.Size = UDim2.new(0, 80, 0, 28)
        AddBtn.Position = UDim2.new(1, -88, 0, 11)
        AddBtn.BackgroundColor3 = Color3.fromRGB(0, 122, 255)
        AddBtn.Text = "Adicionar"
        AddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        AddBtn.Font = Enum.Font.GothamBold
        AddBtn.TextSize = 11
        AddBtn.Parent = Card

        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 6)
        BtnCorner.Parent = AddBtn

        AddBtn.MouseButton1Click:Connect(function()
            if ws then
                ws:Send(HttpService:JSONEncode({
                    type = "send_friend_request",
                    targetUserId = user.userId,
                    fromName = LocalPlayer.Name
                }))
                AddBtn.Text = "Enviado"
                AddBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            end
        end)
    end
end

-- NOTIFICAÇÕES (SOLICITAÇÕES DE AMIZADE)
function UpdateNotifications()
    if #friendRequests > 0 then
        BellBadge.Text = tostring(#friendRequests)
        BellBadge.Visible = true
    else
        BellBadge.Visible = false
    end

    for _, child in pairs(NotifScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for idx, req in ipairs(friendRequests) do
        local Item = Instance.new("Frame")
        Item.Size = UDim2.new(1, 0, 0, 40)
        Item.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
        Item.Parent = NotifScroll

        local ItemCorner = Instance.new("UICorner")
        ItemCorner.CornerRadius = UDim.new(0, 6)
        ItemCorner.Parent = Item

        local Label = Instance.new("TextLabel")
        Label.Text = req.fromName
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 12
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.Position = UDim2.new(0, 10, 0, 12)
        Label.Size = UDim2.new(0, 120, 0, 16)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = Item

        local AcceptBtn = Instance.new("TextButton")
        AcceptBtn.Size = UDim2.new(0, 60, 0, 24)
        AcceptBtn.Position = UDim2.new(1, -68, 0, 8)
        AcceptBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        AcceptBtn.Text = "Aceitar"
        AcceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        AcceptBtn.Font = Enum.Font.GothamBold
        AcceptBtn.TextSize = 10
        AcceptBtn.Parent = Item

        local AccCorner = Instance.new("UICorner")
        AccCorner.CornerRadius = UDim.new(0, 4)
        AccCorner.Parent = AcceptBtn

        AcceptBtn.MouseButton1Click:Connect(function()
            LocalData.friends[tostring(req.fromId)] = req.fromName
            SaveLocalData()
            if ws then
                ws:Send(HttpService:JSONEncode({
                    type = "accept_friend_request",
                    senderId = req.fromId,
                    username = LocalPlayer.Name
                }))
            end
            table.remove(friendRequests, idx)
            UpdateNotifications()
            UpdateFriendsList()
        end)
    end
end

-- ATUALIZAR LISTA DE AMIGOS (ABA MENSAGENS)
function UpdateFriendsList()
    for _, child in pairs(FriendsScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for userId, username in pairs(LocalData.friends) do
        local Card = Instance.new("Frame")
        Card.Size = UDim2.new(1, 0, 0, 56)
        Card.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        Card.Parent = FriendsScroll

        local CardCorner = Instance.new("UICorner")
        CardCorner.CornerRadius = UDim.new(0, 10)
        CardCorner.Parent = Card

        local Avatar = Instance.new("ImageLabel")
        Avatar.Size = UDim2.new(0, 40, 0, 40)
        Avatar.Position = UDim2.new(0, 8, 0, 8)
        Avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=420&height=420&format=png"
        Avatar.Parent = Card

        local AvatarCorner = Instance.new("UICorner")
        AvatarCorner.CornerRadius = UDim.new(1, 0) -- Redonda
        AvatarCorner.Parent = Avatar

        local Name = Instance.new("TextLabel")
        Name.Text = username
        Name.Font = Enum.Font.GothamBold
        Name.TextSize = 14
        Name.TextColor3 = Color3.fromRGB(255, 255, 255)
        Name.Position = UDim2.new(0, 56, 0, 18)
        Name.Size = UDim2.new(0, 180, 0, 18)
        Name.TextXAlignment = Enum.TextXAlignment.Left
        Name.Parent = Card

        -- Click no retângulo para abrir chat
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Size = UDim2.new(1, 0, 1, 0)
        ClickBtn.BackgroundTransparency = 1
        ClickBtn.Text = ""
        ClickBtn.Parent = Card

        ClickBtn.MouseButton1Click:Connect(function()
            OpenChat(userId, username)
        end)
    end
end

-- ABRIR E GERENCIAR CHAT PRIVADO
function OpenChat(userId, username)
    activeChatUserId = userId
    ChatName.Text = username
    ChatAvatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. userId .. "&width=420&height=420&format=png"

    -- Requisitar status online
    if ws then
        ws:Send(HttpService:JSONEncode({
            type = "check_status",
            targetUserId = userId
        }))
    end

    RenderChatHistory(userId)

    -- Animação de deslizar janela de chat
    TweenService:Create(ChatWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
end

BackBtn.MouseButton1Click:Connect(function()
    activeChatUserId = nil
    TweenService:Create(ChatWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(1, 0, 0, 0)
    }):Play()
end)

-- DESENHAR MENSAGENS E FIGURINHAS NO CHAT
function RenderChatHistory(userId)
    for _, child in pairs(MessagesScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local history = LocalData.chats[userId] or {}
    for _, msg in ipairs(history) do
        CreateMessageBubble(msg.sender == "me", msg.type, msg.content)
    end
    MessagesScroll.CanvasPosition = Vector2.new(0, MessagesScroll.AbsoluteCanvasSize.Y)
end

function CreateMessageBubble(isMe, msgType, content)
    local Bubble = Instance.new("Frame")
    Bubble.BackgroundColor3 = isMe and Color3.fromRGB(0, 122, 255) or Color3.fromRGB(40, 40, 48) -- Cinza claro arredondado / Azul
    Bubble.Parent = MessagesScroll

    local BCorner = Instance.new("UICorner")
    BCorner.CornerRadius = UDim.new(0, 14)
    BCorner.Parent = Bubble

    if msgType == "text" then
        local Text = Instance.new("TextLabel")
        Text.Text = content
        Text.Font = Enum.Font.Gotham
        Text.TextSize = 13
        Text.TextColor3 = Color3.fromRGB(255, 255, 255)
        Text.Size = UDim2.new(0, 0, 0, 0)
        Text.TextWrapped = true
        Text.Parent = Bubble

        -- Ajusta tamanho do balão baseado no texto
        local textSize = game:GetService("TextService"):GetTextSize(content, 13, Enum.Font.Gotham, Vector2.new(200, 1000))
        Bubble.Size = UDim2.new(0, textSize.X + 24, 0, textSize.Y + 14)
        Text.Size = UDim2.new(1, -12, 1, -8)
        Text.Position = UDim2.new(0, 6, 0, 4)
    elseif msgType == "sticker" then
        Bubble.BackgroundTransparency = 1
        Bubble.Size = UDim2.new(0, 90, 0, 90)

        local Img = Instance.new("ImageLabel")
        Img.Size = UDim2.new(1, 0, 1, 0)
        Img.BackgroundTransparency = 1
        Img.Image = content
        Img.Parent = Bubble
    end

    -- Alinhamento à direita (👉) pra você e à esquerda pro amigo (Igual Insta/TikTok)
    if isMe then
        Bubble.Position = UDim2.new(1, -Bubble.Size.X.Offset, 0, 0)
    else
        Bubble.Position = UDim2.new(0, 0, 0, 0)
    end
end

-- ENVIAR MENSAGENS
function SendMessage(msgType, content)
    if not activeChatUserId then return end

    if not LocalData.chats[activeChatUserId] then
        LocalData.chats[activeChatUserId] = {}
    end

    table.insert(LocalData.chats[activeChatUserId], {
        sender = "me",
        type = msgType,
        content = content,
        timestamp = os.time()
    })
    SaveLocalData()

    CreateMessageBubble(true, msgType, content)
    MessagesScroll.CanvasPosition = Vector2.new(0, MessagesScroll.AbsoluteCanvasSize.Y)

    if ws then
        ws:Send(HttpService:JSONEncode({
            type = "send_message",
            toUserId = activeChatUserId,
            msgType = msgType,
            content = content
        }))
    end
end

SendBtn.MouseButton1Click:Connect(function()
    if #ChatTextBox.Text > 0 then
        SendMessage("text", ChatTextBox.Text)
        ChatTextBox.Text = ""
    end
end)

-- RECEBER MENSAGENS
function ReceivePrivateMessage(data)
    local fromId = tostring(data.fromUserId)

    if not LocalData.chats[fromId] then
        LocalData.chats[fromId] = {}
    end

    table.insert(LocalData.chats[fromId], {
        sender = "them",
        type = data.msgType,
        content = data.content,
        timestamp = data.timestamp
    })
    SaveLocalData()

    if activeChatUserId == fromId then
        CreateMessageBubble(false, data.msgType, data.content)
        MessagesScroll.CanvasPosition = Vector2.new(0, MessagesScroll.AbsoluteCanvasSize.Y)
    end
end

-- DETECTAR SE ESTÁ DIGITANDO...
ChatTextBox:GetPropertyChangedSignal("Text"):Connect(function()
    if ws and activeChatUserId then
        ws:Send(HttpService:JSONEncode({
            type = "typing_status",
            toUserId = activeChatUserId,
            isTyping = (#ChatTextBox.Text > 0)
        }))
    end
end)

-- SISTEMA DE FIGURINHAS (GITHUB & PAINEL)
local drawerOpen = false

local function LoadStickersFromGitHub()
    pcall(function()
        local response = game:HttpGet(GITHUB_STICKERS_URL)
        local items = HttpService:JSONDecode(response)

        for _, item in ipairs(items) do
            if item.type == "file" then
                local imgUrl = GITHUB_RAW_BASE .. item.name

                local Btn = Instance.new("ImageButton")
                Btn.Size = UDim2.new(0, 50, 0, 50)
                Btn.BackgroundTransparency = 1
                Btn.Image = imgUrl
                Btn.Parent = AllStickersScroll

                Btn.MouseButton1Click:Connect(function()
                    SendMessage("sticker", imgUrl)
                    AddRecentSticker(imgUrl)
                end)
            end
        end
    end)
end

function AddRecentSticker(url)
    for i, v in ipairs(LocalData.recentStickers) do
        if v == url then table.remove(LocalData.recentStickers, i) end
    end
    table.insert(LocalData.recentStickers, 1, url)
    if #LocalData.recentStickers > 5 then
        table.remove(LocalData.recentStickers, 6)
    end
    SaveLocalData()
    RenderRecentStickers()
end

function RenderRecentStickers()
    for _, child in pairs(RecentsFrame:GetChildren()) do
        if child:IsA("ImageButton") then child:Destroy() end
    end

    for _, url in ipairs(LocalData.recentStickers) do
        local Btn = Instance.new("ImageButton")
        Btn.Size = UDim2.new(0, 48, 0, 48)
        Btn.BackgroundTransparency = 1
        Btn.Image = url
        Btn.Parent = RecentsFrame

        Btn.MouseButton1Click:Connect(function()
            SendMessage("sticker", url)
        end)
    end
end

EmojiBtn.MouseButton1Click:Connect(function()
    drawerOpen = not drawerOpen
    local targetPos = drawerOpen and UDim2.new(0, 0, 1, -210) or UDim2.new(0, 0, 1, 0)
    local chatScrollSize = drawerOpen and UDim2.new(1, -20, 1, -315) or UDim2.new(1, -20, 1, -115)

    TweenService:Create(StickerDrawer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = targetPos
    }):Play()

    TweenService:Create(MessagesScroll, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = chatScrollSize
    }):Play()
end)

-- INICIALIZAÇÃO
ConnectWebSocket()
LoadStickersFromGitHub()
RenderRecentStickers()
