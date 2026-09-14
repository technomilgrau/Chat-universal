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
            if not LocalData.recentStickers then
                LocalData.recentStickers = {}
            end
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
Title.BackgroundTransparency = 1
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Text = "techno_milgrau"
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 12
Subtitle.TextColor3 = Color3.fromRGB(140, 140, 150)
Subtitle.Position = UDim2.new(0, 16, 0, 34)
Subtitle.Size = UDim2.new(0, 200, 0, 16)
Subtitle.BackgroundTransparency = 1
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

-- Botão de Notificações (Sino Emoji)
local BellBtn = Instance.new("TextButton")
BellBtn.Size = UDim2.new(0, 28, 0, 28)
BellBtn.Position = UDim2.new(1, -44, 0, 16)
BellBtn.BackgroundTransparency = 1
BellBtn.Text = "🔔"
BellBtn.TextSize = 20
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

local EmptyNotifText = Instance.new("TextLabel")
EmptyNotifText.Size = UDim2.new(1, 0, 1, 0)
EmptyNotifText.BackgroundTransparency = 1
EmptyNotifText.Text = "Notificações vazias"
EmptyNotifText.TextColor3 = Color3.fromRGB(150, 150, 160)
EmptyNotifText.Font = Enum.Font.Gotham
EmptyNotifText.TextSize = 13
EmptyNotifText.ZIndex = 12
EmptyNotifText.Parent = NotifScroll

-- JANELA DE CHAT PRIVADO
local ChatWindow = Instance.new("Frame")
ChatWindow.Size = UDim2.new(1, 0, 1, 0)
ChatWindow.Position = UDim2.new(1, 0, 0, 0) -- Fora da tela
ChatWindow.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
ChatWindow.ZIndex = 20
ChatWindow.Parent = MainFrame

local ChatHeader = Instance.new("Frame")
ChatHeader.Size = UDim2.new(1, 0, 0, 55)
ChatHeader.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
ChatHeader.ZIndex = 21
ChatHeader.Parent = ChatWindow

local BackBtn = Instance.new("TextButton")
BackBtn.Size = UDim2.new(0, 30, 0, 30)
BackBtn.Position = UDim2.new(0, 10, 0, 12)
BackBtn.BackgroundTransparency = 1
BackBtn.Text = "<"
BackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BackBtn.Font = Enum.Font.GothamBold
BackBtn.TextSize = 20
BackBtn.ZIndex = 21
BackBtn.Parent = ChatHeader

local ChatAvatar = Instance.new("ImageLabel")
ChatAvatar.Size = UDim2.new(0, 36, 0, 36)
ChatAvatar.Position = UDim2.new(0, 45, 0, 9)
ChatAvatar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ChatAvatar.BackgroundTransparency = 1
ChatAvatar.ZIndex = 21
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
ChatName.BackgroundTransparency = 1
ChatName.TextXAlignment = Enum.TextXAlignment.Left
ChatName.ZIndex = 21
ChatName.Parent = ChatHeader

local ChatStatus = Instance.new("TextLabel")
ChatStatus.Size = UDim2.new(0, 180, 0, 14)
ChatStatus.Position = UDim2.new(0, 90, 0, 28)
ChatStatus.Font = Enum.Font.Gotham
ChatStatus.TextSize = 11
ChatStatus.TextColor3 = Color3.fromRGB(140, 140, 150)
ChatStatus.Text = "offline"
ChatStatus.BackgroundTransparency = 1
ChatStatus.TextXAlignment = Enum.TextXAlignment.Left
ChatStatus.ZIndex = 21
ChatStatus.Parent = ChatHeader

local MessagesScroll = Instance.new("ScrollingFrame")
MessagesScroll.Size = UDim2.new(1, -20, 1, -115)
MessagesScroll.Position = UDim2.new(0, 10, 0, 60)
MessagesScroll.BackgroundTransparency = 1
MessagesScroll.ScrollBarThickness = 2
MessagesScroll.ZIndex = 20
MessagesScroll.Parent = ChatWindow

local MessagesLayout = Instance.new("UIListLayout")
MessagesLayout.Padding = UDim.new(0, 8)
MessagesLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
MessagesLayout.Parent = MessagesScroll

-- Input do Chat & Botão de Figurinhas
local ChatInputFrame = Instance.new("Frame")
ChatInputFrame.Size = UDim2.new(1, -20, 0, 42)
ChatInputFrame.Position = UDim2.new(0, 10, 1, -48)
ChatInputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInputFrame.ZIndex = 21
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
EmojiBtn.ZIndex = 21
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
ChatTextBox.TextWrapped = true
ChatTextBox.ZIndex = 21
ChatTextBox.Parent = ChatInputFrame

local SendBtn = Instance.new("TextButton")
SendBtn.Size = UDim2.new(0, 30, 0, 30)
SendBtn.Position = UDim2.new(1, -35, 0, 6)
SendBtn.BackgroundTransparency = 1
SendBtn.Text = "➔"
SendBtn.TextColor3 = Color3.fromRGB(0, 140, 255)
SendBtn.Font = Enum.Font.GothamBold
SendBtn.TextSize = 16
SendBtn.ZIndex = 21
SendBtn.Parent = ChatInputFrame

-- PAINEL DE STICKERS (Aba estilo TikTok)
local StickerPanel = Instance.new("Frame")
StickerPanel.Size = UDim2.new(1, 0, 0, 250)
StickerPanel.Position = UDim2.new(0, 0, 1, -298) -- Sobe e fica logo acima do input de texto
StickerPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
StickerPanel.Visible = false
StickerPanel.ZIndex = 22
StickerPanel.Parent = ChatWindow

local StickerPanelCorner = Instance.new("UICorner")
StickerPanelCorner.CornerRadius = UDim.new(0, 12)
StickerPanelCorner.Parent = StickerPanel

local StickerScroll = Instance.new("ScrollingFrame")
StickerScroll.Size = UDim2.new(1, -10, 1, -10)
StickerScroll.Position = UDim2.new(0, 5, 0, 5)
StickerScroll.BackgroundTransparency = 1
StickerScroll.ScrollBarThickness = 2
StickerScroll.ZIndex = 23
StickerScroll.Parent = StickerPanel

local StickerLayout = Instance.new("UIListLayout")
StickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
StickerLayout.Padding = UDim.new(0, 10)
StickerLayout.Parent = StickerScroll

local RecentLabel = Instance.new("TextLabel")
RecentLabel.Size = UDim2.new(1, 0, 0, 20)
RecentLabel.BackgroundTransparency = 1
RecentLabel.Text = " Usado recentemente"
RecentLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
RecentLabel.Font = Enum.Font.Gotham
RecentLabel.TextSize = 12
RecentLabel.TextXAlignment = Enum.TextXAlignment.Left
RecentLabel.LayoutOrder = 1
RecentLabel.ZIndex = 23
RecentLabel.Parent = StickerScroll

local RecentGridFrame = Instance.new("Frame")
RecentGridFrame.Size = UDim2.new(1, 0, 0, 70)
RecentGridFrame.BackgroundTransparency = 1
RecentGridFrame.LayoutOrder = 2
RecentGridFrame.ZIndex = 23
RecentGridFrame.Parent = StickerScroll

local RecentGrid = Instance.new("UIGridLayout")
RecentGrid.CellSize = UDim2.new(0, 65, 0, 65)
RecentGrid.CellPadding = UDim2.new(0, 8, 0, 8)
RecentGrid.Parent = RecentGridFrame

local AllLabel = Instance.new("TextLabel")
AllLabel.Size = UDim2.new(1, 0, 0, 20)
AllLabel.BackgroundTransparency = 1
AllLabel.Text = " Salvo"
AllLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
AllLabel.Font = Enum.Font.Gotham
AllLabel.TextSize = 12
AllLabel.TextXAlignment = Enum.TextXAlignment.Left
AllLabel.LayoutOrder = 3
AllLabel.ZIndex = 23
AllLabel.Parent = StickerScroll

local AllGridFrame = Instance.new("Frame")
AllGridFrame.Size = UDim2.new(1, 0, 0, 0)
AllGridFrame.BackgroundTransparency = 1
AllGridFrame.LayoutOrder = 4
AllGridFrame.ZIndex = 23
AllGridFrame.Parent = StickerScroll

local AllGrid = Instance.new("UIGridLayout")
AllGrid.CellSize = UDim2.new(0, 65, 0, 65)
AllGrid.CellPadding = UDim2.new(0, 8, 0, 8)
AllGrid.Parent = AllGridFrame

AllGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    AllGridFrame.Size = UDim2.new(1, 0, 0, AllGrid.AbsoluteContentSize.Y)
    StickerScroll.CanvasSize = UDim2.new(0, 0, 0, RecentLabel.AbsoluteSize.Y + RecentGridFrame.AbsoluteSize.Y + AllLabel.AbsoluteSize.Y + AllGridFrame.AbsoluteSize.Y + 40)
end)

-- SISTEMA DE BAIXAR E CARREGAR IMAGENS
local function GetStickerAsset(filename)
    local stickerFolder = FOLDER_NAME .. "/Stickers"
    if not isfolder(stickerFolder) then
        makefolder(stickerFolder)
    end
    local filePath = stickerFolder .. "/" .. filename
    if not isfile(filePath) then
        local url = GITHUB_RAW_BASE .. filename
        local success, imgData = pcall(function() return game:HttpGet(url) end)
        if success and imgData then
            writefile(filePath, imgData)
        else
            return ""
        end
    end
    
    local customAssetFunc = getcustomasset or getsynasset
    if customAssetFunc then
        return customAssetFunc(filePath)
    end
    return ""
end

local function AddRecentSticker(filename)
    for i, v in ipairs(LocalData.recentStickers) do
        if v == filename then
            table.remove(LocalData.recentStickers, i)
            break
        end
    end
    table.insert(LocalData.recentStickers, 1, filename)
    if #LocalData.recentStickers > 5 then
        table.remove(LocalData.recentStickers, 6)
    end
    SaveLocalData()
end

local function SendSticker(filename)
    if activeChatUserId and ws then
        local idStr = tostring(activeChatUserId)
        local newMsg = {sender = "me", type = "sticker", content = filename}

        if not LocalData.chats[idStr] then LocalData.chats[idStr] = {} end
        table.insert(LocalData.chats[idStr], newMsg)
        AddRecentSticker(filename)
        SaveLocalData()
        RenderMessages(activeChatUserId)

        ws:Send(HttpService:JSONEncode({
            type = "send_message",
            toUserId = idStr,
            msgType = "sticker",
            content = filename
        }))
    end
end

local function UpdateRecentStickersUI()
    for _, child in pairs(RecentGridFrame:GetChildren()) do
        if child:IsA("ImageButton") then child:Destroy() end
    end
    for _, filename in ipairs(LocalData.recentStickers) do
        local btn = Instance.new("ImageButton")
        btn.BackgroundTransparency = 1
        btn.ZIndex = 24
        btn.Parent = RecentGridFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        task.spawn(function()
            btn.Image = GetStickerAsset(filename)
        end)

        btn.MouseButton1Click:Connect(function()
            SendSticker(filename)
            StickerPanel.Visible = false
        end)
    end
end

local stickersLoaded = false
EmojiBtn.MouseButton1Click:Connect(function()
    StickerPanel.Visible = not StickerPanel.Visible
    if StickerPanel.Visible then
        UpdateRecentStickersUI()
        if not stickersLoaded then
            stickersLoaded = true
            task.spawn(function()
                local success, res = pcall(function() return game:HttpGet(GITHUB_STICKERS_URL) end)
                if success then
                    local decoded = HttpService:JSONDecode(res)
                    for _, file in ipairs(decoded) do
                        if file.name:match("%.png$") or file.name:match("%.jpg$") or file.name:match("%.jpeg$") then
                            local btn = Instance.new("ImageButton")
                            btn.BackgroundTransparency = 1
                            btn.ZIndex = 24
                            btn.Parent = AllGridFrame

                            local corner = Instance.new("UICorner")
                            corner.CornerRadius = UDim.new(0, 8)
                            corner.Parent = btn

                            task.spawn(function()
                                btn.Image = GetStickerAsset(file.name)
                            end)

                            btn.MouseButton1Click:Connect(function()
                                SendSticker(file.name)
                                StickerPanel.Visible = false
                            end)
                        end
                    end
                end
            end)
        end
    end
end)

-- BARRA DE NAVEGAÇÃO INFERIOR
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

-- FUNÇÕES DA UI
local function UpdateFriendsList()
    for _, child in pairs(FriendsScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for id, name in pairs(LocalData.friends) do
        local FCard = Instance.new("Frame")
        FCard.Size = UDim2.new(1, 0, 0, 50)
        FCard.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
        FCard.Parent = FriendsScroll

        local FCardCorner = Instance.new("UICorner")
        FCardCorner.CornerRadius = UDim.new(0, 8)
        FCardCorner.Parent = FCard

        local FAvatar = Instance.new("ImageLabel")
        FAvatar.Size = UDim2.new(0, 36, 0, 36)
        FAvatar.Position = UDim2.new(0, 8, 0, 7)
        FAvatar.BackgroundTransparency = 1
        FAvatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. id .. "&width=420&height=420&format=png"
        FAvatar.Parent = FCard

        local FAvatarCorner = Instance.new("UICorner")
        FAvatarCorner.CornerRadius = UDim.new(0, 6)
        FAvatarCorner.Parent = FAvatar

        local FName = Instance.new("TextLabel")
        FName.Text = name
        FName.Font = Enum.Font.GothamBold
        FName.TextSize = 13
        FName.TextColor3 = Color3.fromRGB(255, 255, 255)
        FName.Position = UDim2.new(0, 52, 0, 16)
        FName.Size = UDim2.new(0, 130, 0, 18)
        FName.BackgroundTransparency = 1
        FName.TextXAlignment = Enum.TextXAlignment.Left
        FName.Parent = FCard

        local OpenChatBtn = Instance.new("TextButton")
        OpenChatBtn.Size = UDim2.new(0, 60, 0, 28)
        OpenChatBtn.Position = UDim2.new(1, -68, 0, 11)
        OpenChatBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        OpenChatBtn.Text = "Chat"
        OpenChatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        OpenChatBtn.Font = Enum.Font.GothamBold
        OpenChatBtn.TextSize = 12
        OpenChatBtn.Parent = FCard

        local OpenCorner = Instance.new("UICorner")
        OpenCorner.CornerRadius = UDim.new(0, 6)
        OpenCorner.Parent = OpenChatBtn

        OpenChatBtn.MouseButton1Click:Connect(function()
            activeChatUserId = id
            ChatName.Text = name
            ChatAvatar.Image = FAvatar.Image
            
            ChatWindow.Position = UDim2.new(1, 0, 0, 0)
            local tween = TweenService:Create(ChatWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)})
            tween:Play()
            
            RenderMessages(id)
        end)
    end
end

local function UpdateNotifications()
    for _, child in pairs(NotifScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    if #friendRequests == 0 then
        EmptyNotifText.Visible = true
        BellBadge.Visible = false
    else
        EmptyNotifText.Visible = false
        BellBadge.Text = tostring(#friendRequests)
        BellBadge.Visible = true
        
        for i, req in ipairs(friendRequests) do
            local ReqFrame = Instance.new("Frame")
            ReqFrame.Size = UDim2.new(1, 0, 0, 50)
            ReqFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            ReqFrame.Parent = NotifScroll
            
            local ReqCorner = Instance.new("UICorner")
            ReqCorner.CornerRadius = UDim.new(0, 8)
            ReqCorner.Parent = ReqFrame
            
            local ReqAvatar = Instance.new("ImageLabel")
            ReqAvatar.Size = UDim2.new(0, 36, 0, 36)
            ReqAvatar.Position = UDim2.new(0, 8, 0, 7)
            ReqAvatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. req.userId .. "&width=420&height=420&format=png"
            ReqAvatar.BackgroundTransparency = 1
            ReqAvatar.Parent = ReqFrame
            
            local ReqAvatarCorner = Instance.new("UICorner")
            ReqAvatarCorner.CornerRadius = UDim.new(1, 0)
            ReqAvatarCorner.Parent = ReqAvatar
            
            local ReqName = Instance.new("TextLabel")
            ReqName.Size = UDim2.new(0, 100, 0, 18)
            ReqName.Position = UDim2.new(0, 52, 0, 16)
            ReqName.BackgroundTransparency = 1
            ReqName.Text = req.username
            ReqName.Font = Enum.Font.GothamBold
            ReqName.TextSize = 13
            ReqName.TextColor3 = Color3.fromRGB(255, 255, 255)
            ReqName.TextXAlignment = Enum.TextXAlignment.Left
            ReqName.Parent = ReqFrame
            
            -- Botão Aceitar (Verde)
            local AcceptBtn = Instance.new("TextButton")
            AcceptBtn.Size = UDim2.new(0, 30, 0, 30)
            AcceptBtn.Position = UDim2.new(1, -76, 0, 10)
            AcceptBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
            AcceptBtn.Text = "✓"
            AcceptBtn.TextColor3 = Color3.fromRGB(255,255,255)
            AcceptBtn.Font = Enum.Font.GothamBold
            AcceptBtn.Parent = ReqFrame
            
            local AcceptCorner = Instance.new("UICorner")
            AcceptCorner.CornerRadius = UDim.new(0, 6)
            AcceptCorner.Parent = AcceptBtn
            
            -- Botão Recusar (Vermelho)
            local DeclineBtn = Instance.new("TextButton")
            DeclineBtn.Size = UDim2.new(0, 30, 0, 30)
            DeclineBtn.Position = UDim2.new(1, -38, 0, 10)
            DeclineBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
            DeclineBtn.Text = "✗"
            DeclineBtn.TextColor3 = Color3.fromRGB(255,255,255)
            DeclineBtn.Font = Enum.Font.GothamBold
            DeclineBtn.Parent = ReqFrame
            
            local DeclineCorner = Instance.new("UICorner")
            DeclineCorner.CornerRadius = UDim.new(0, 6)
            DeclineCorner.Parent = DeclineBtn
            
            AcceptBtn.MouseButton1Click:Connect(function()
                if ws then
                    ws:Send(HttpService:JSONEncode({
                        type = "accept_friend_request",
                        senderId = tostring(req.userId),
                        username = LocalPlayer.Name
                    }))
                end
                LocalData.friends[tostring(req.userId)] = req.username
                SaveLocalData()
                
                table.remove(friendRequests, i)
                UpdateNotifications()
                UpdateFriendsList()
            end)
            
            DeclineBtn.MouseButton1Click:Connect(function()
                if ws then
                    ws:Send(HttpService:JSONEncode({
                        type = "decline_friend",
                        targetUserId = req.userId
                    }))
                end
                table.remove(friendRequests, i)
                UpdateNotifications()
            end)
        end
    end
end

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
        Avatar.BackgroundTransparency = 1
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
        Name.BackgroundTransparency = 1
        Name.TextXAlignment = Enum.TextXAlignment.Left
        Name.Parent = Card

        local AddBtn = Instance.new("TextButton")
        AddBtn.Size = UDim2.new(0, 80, 0, 28)
        AddBtn.Position = UDim2.new(1, -88, 0, 11)
        AddBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
        AddBtn.Text = "Adicionar"
        AddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        AddBtn.Font = Enum.Font.GothamBold
        AddBtn.TextSize = 12
        AddBtn.Parent = Card
        
        local AddCorner = Instance.new("UICorner")
        AddCorner.CornerRadius = UDim.new(0, 6)
        AddCorner.Parent = AddBtn

        AddBtn.MouseButton1Click:Connect(function()
            if ws then
                ws:Send(HttpService:JSONEncode({
                    type = "send_friend_request",
                    targetUserId = tostring(user.userId),
                    fromName = LocalPlayer.Name
                }))
                AddBtn.Text = "Enviado!"
                AddBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            end
        end)
    end
end

function RenderMessages(userId)
    for _, child in pairs(MessagesScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local chatHistory = LocalData.chats[tostring(userId)] or {}
    for _, msg in ipairs(chatHistory) do
        local MsgFrame = Instance.new("Frame")
        MsgFrame.BackgroundTransparency = 1
        MsgFrame.Parent = MessagesScroll
        
        if msg.type == "sticker" then
            MsgFrame.Size = UDim2.new(1, 0, 0, 100)
            
            local StickerImg = Instance.new("ImageLabel")
            StickerImg.Size = UDim2.new(0, 100, 0, 100)
            StickerImg.BackgroundTransparency = 1
            
            local StickerCorner = Instance.new("UICorner")
            StickerCorner.CornerRadius = UDim.new(0, 12)
            StickerCorner.Parent = StickerImg
            
            if msg.sender == "me" then
                StickerImg.Position = UDim2.new(1, -100, 0, 0)
            else
                StickerImg.Position = UDim2.new(0, 0, 0, 0)
            end
            StickerImg.Parent = MsgFrame
            
            task.spawn(function()
                StickerImg.Image = GetStickerAsset(msg.content)
            end)
        else
            -- Renderização Textual Normal
            MsgFrame.Size = UDim2.new(1, 0, 0, 30)
            local Txt = Instance.new("TextLabel")
            Txt.Text = msg.content
            Txt.Font = Enum.Font.Gotham
            Txt.TextSize = 13
            Txt.TextColor3 = Color3.fromRGB(255, 255, 255)
            Txt.BackgroundTransparency = 0
            
            local TxtCorner = Instance.new("UICorner")
            TxtCorner.CornerRadius = UDim.new(0, 8)
            TxtCorner.Parent = Txt
            
            local textWidth = string.len(msg.content) * 7 + 20
            textWidth = math.clamp(textWidth, 40, 220)
            Txt.Size = UDim2.new(0, textWidth, 1, 0)
            
            if msg.sender == "me" then
                Txt.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
                Txt.Position = UDim2.new(1, -textWidth, 0, 0)
            else
                Txt.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                Txt.Position = UDim2.new(0, 0, 0, 0)
            end
            Txt.Parent = MsgFrame
        end
    end
    MessagesScroll.CanvasPosition = Vector2.new(0, 99999)
end

-- EVENTOS DE CLIQUE E NAVEGAÇÃO
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

BackBtn.MouseButton1Click:Connect(function()
    local tween = TweenService:Create(ChatWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, 0, 0, 0)})
    tween:Play()
    StickerPanel.Visible = false
    activeChatUserId = nil
end)

SendBtn.MouseButton1Click:Connect(function()
    if activeChatUserId and ChatTextBox.Text ~= "" and ws then
        local msgText = ChatTextBox.Text
        ChatTextBox.Text = ""
        
        local newMsg = {sender = "me", type = "text", content = msgText}
        local idStr = tostring(activeChatUserId)
        
        if not LocalData.chats[idStr] then
            LocalData.chats[idStr] = {}
        end
        table.insert(LocalData.chats[idStr], newMsg)
        SaveLocalData()
        RenderMessages(activeChatUserId)
        
        ws:Send(HttpService:JSONEncode({
            type = "send_message",
            toUserId = idStr,
            msgType = "text",
            content = msgText
        }))
    end
end)

-- PESQUISA DE USUÁRIOS LOGIC
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

-- WEBSOCKET INICIALIZAÇÃO
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
                    table.insert(friendRequests, {
                        userId = data.request.fromId,
                        username = data.request.fromName
                    })
                    UpdateNotifications()
                elseif data.type == "friend_requests" then
                    friendRequests = {}
                    for _, req in ipairs(data.requests) do
                        table.insert(friendRequests, {
                            userId = req.fromId,
                            username = req.fromName
                        })
                    end
                    UpdateNotifications()
                elseif data.type == "friend_accepted" then
                    LocalData.friends[tostring(data.userId)] = data.username
                    SaveLocalData()
                    UpdateFriendsList()
                elseif data.type == "private_message" then
                    local idStr = tostring(data.fromUserId)
                    if not LocalData.chats[idStr] then
                        LocalData.chats[idStr] = {}
                    end
                    table.insert(LocalData.chats[idStr], {
                        sender = "them", 
                        type = data.msgType or "text", 
                        content = data.content
                    })
                    SaveLocalData()
                    if activeChatUserId == idStr then
                        RenderMessages(idStr)
                    end
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

-- Inicializa o Websocket e as listas vazias
UpdateNotifications()
ConnectWebSocket()
