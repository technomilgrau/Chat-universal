local RENDER_WEBSOCKET_URL = "wss://chat-universal-k9at.onrender.com"

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Criação da Interface Dark
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaPairingMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 330)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -165)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

-- Topbar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA PAIRING SYSTEM"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Navegação de Abas
local TabHolder = Instance.new("Frame")
TabHolder.Size = UDim2.new(1, -20, 0, 30)
TabHolder.Position = UDim2.new(0, 10, 0, 48)
TabHolder.BackgroundTransparency = 1
TabHolder.Parent = MainFrame

local UIListLayoutTabs = Instance.new("UIListLayout")
UIListLayoutTabs.FillDirection = Enum.FillDirection.Horizontal
UIListLayoutTabs.Padding = UDim.new(0, 8)
UIListLayoutTabs.Parent = TabHolder

local function createTabButton(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    return btn
end

local UsersTabBtn = createTabButton("Usuários")
UsersTabBtn.Parent = TabHolder
local ChatTabBtn = createTabButton("Chat")
ChatTabBtn.Parent = TabHolder
local ActionsTabBtn = createTabButton("Ações")
ActionsTabBtn.Parent = TabHolder
ActionsTabBtn.Visible = false

-- Containers de Conteúdo
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -20, 1, -95)
ContentArea.Position = UDim2.new(0, 10, 0, 85)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Lista de Usuários
local UsersFrame = Instance.new("ScrollingFrame")
UsersFrame.Size = UDim2.new(1, 0, 1, 0)
UsersFrame.BackgroundTransparency = 1
UsersFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
UsersFrame.ScrollBarThickness = 4
UsersFrame.Parent = ContentArea

local UsersLayout = Instance.new("UIListLayout")
UsersLayout.Padding = UDim.new(0, 6)
UsersLayout.Parent = UsersFrame

-- Painel de Chat
local ChatFrame = Instance.new("Frame")
ChatFrame.Size = UDim2.new(1, 0, 1, 0)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Visible = false
ChatFrame.Parent = ContentArea

local ChatLog = Instance.new("ScrollingFrame")
ChatLog.Size = UDim2.new(1, 0, 1, -35)
ChatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
ChatLog.BorderSizePixel = 0
ChatLog.CanvasSize = UDim2.new(0, 0, 0, 0)
ChatLog.ScrollBarThickness = 4
ChatLog.Parent = ChatFrame

local ChatLogCorner = Instance.new("UICorner")
ChatLogCorner.CornerRadius = UDim.new(0, 6)
ChatLogCorner.Parent = ChatLog

local ChatLayout = Instance.new("UIListLayout")
ChatLayout.Padding = UDim.new(0, 4)
ChatLayout.Parent = ChatLog

local ChatInput = Instance.new("TextBox")
ChatInput.Size = UDim2.new(1, 0, 0, 30)
ChatInput.Position = UDim2.new(0, 0, 1, -30)
ChatInput.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInput.PlaceholderText = "Digite sua mensagem..."
ChatInput.TextColor3 = Color3.fromRGB(240, 240, 240)
ChatInput.Font = Enum.Font.Gotham
ChatInput.TextSize = 13
ChatInput.BorderSizePixel = 0
ChatInput.Parent = ChatFrame

local ChatInputCorner = Instance.new("UICorner")
ChatInputCorner.CornerRadius = UDim.new(0, 6)
ChatInputCorner.Parent = ChatInput

-- Painel de Ações (Ao Parear)
local ActionsFrame = Instance.new("Frame")
ActionsFrame.Size = UDim2.new(1, 0, 1, 0)
ActionsFrame.BackgroundTransparency = 1
ActionsFrame.Visible = false
ActionsFrame.Parent = ContentArea

local ActionsLayout = Instance.new("UIListLayout")
ActionsLayout.Padding = UDim.new(0, 8)
ActionsLayout.Parent = ActionsFrame

local function createActionButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    return btn
end

local BringBtn = createActionButton("Trazer pra Perto", Color3.fromRGB(0, 130, 210))
BringBtn.Parent = ActionsFrame

local UnpairBtn = createActionButton("Desemparear", Color3.fromRGB(190, 40, 40))
UnpairBtn.Parent = ActionsFrame

-- Troca de Abas
local function switchTab(tab)
    UsersFrame.Visible = (tab == "users")
    ChatFrame.Visible = (tab == "chat")
    ActionsFrame.Visible = (tab == "actions")
end

UsersTabBtn.MouseButton1Click:Connect(function() switchTab("users") end)
ChatTabBtn.MouseButton1Click:Connect(function() switchTab("chat") end)
ActionsTabBtn.MouseButton1Click:Connect(function() switchTab("actions") end)

-- Gerenciamento WebSocket
local ws = nil
local pairedUser = nil

local function sendWS(data)
    if ws then
        ws:Send(HttpService:JSONEncode(data))
    end
end

local function appendChatMessage(sender, text)
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, -10, 0, 24)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = "  " .. sender .. ": " .. text
    msgLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 13
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.Parent = ChatLog
    
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10)
    ChatLog.CanvasPosition = Vector2.new(0, ChatLog.CanvasSize.Y.Offset)
end

local function updateUsersList(users)
    for _, child in ipairs(UsersFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for _, user in ipairs(users) do
        if tostring(user.userId) ~= tostring(LocalPlayer.UserId) then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -6, 0, 45)
            card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
            card.BorderSizePixel = 0
            card.Parent = UsersFrame
            
            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 6)
            cardCorner.Parent = card
            
            local avatarImg = Instance.new("ImageLabel")
            avatarImg.Size = UDim2.new(0, 35, 0, 35)
            avatarImg.Position = UDim2.new(0, 5, 0, 5)
            avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. user.userId .. "&w=150&h=150"
            avatarImg.BackgroundTransparency = 1
            avatarImg.Parent = card
            
            local avatarCorner = Instance.new("UICorner")
            avatarCorner.CornerRadius = UDim.new(0, 18)
            avatarCorner.Parent = avatarImg
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -95, 1, 0)
            nameLabel.Position = UDim2.new(0, 48, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = user.username
            nameLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
            nameLabel.Font = Enum.Font.GothamMedium
            nameLabel.TextSize = 13
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = card
            
            if not user.paired then
                local pairBtn = Instance.new("TextButton")
                pairBtn.Size = UDim2.new(0, 35, 0, 35)
                pairBtn.Position = UDim2.new(1, -40, 0, 5)
                pairBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
                pairBtn.Text = "✅"
                pairBtn.TextSize = 16
                pairBtn.BorderSizePixel = 0
                pairBtn.Parent = card
                
                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 6)
                btnCorner.Parent = pairBtn
                
                pairBtn.MouseButton1Click:Connect(function()
                    sendWS({ type = "pair", targetId = tostring(user.userId) })
                end)
            end
        end
    end
    UsersFrame.CanvasSize = UDim2.new(0, 0, 0, UsersLayout.AbsoluteContentSize.Y + 10)
end

-- Conexão WebSocket para o Delta Executor
local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "user_list" then
            updateUsersList(data.users)
        elseif data.type == "paired" then
            pairedUser = data.targetId
            ActionsTabBtn.Visible = true
            switchTab("chat")
            appendChatMessage("Sistema", "Conectado com " .. data.targetName .. "!")
        elseif data.type == "unpaired" then
            pairedUser = nil
            ActionsTabBtn.Visible = false
            switchTab("users")
            appendChatMessage("Sistema", "Conexão desfeita.")
        elseif data.type == "chat" then
            appendChatMessage(data.sender, data.message)
        elseif data.type == "teleport_to" then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(data.position.x, data.position.y + 3, data.position.z)
            end
        end
    end)
    
    sendWS({
        type = "register",
        userId = tostring(LocalPlayer.UserId),
        username = LocalPlayer.Name
    })
end

-- Envio pelo Chat da UI
ChatInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and ChatInput.Text ~= "" and pairedUser then
        sendWS({ type = "chat", message = ChatInput.Text })
        ChatInput.Text = ""
    end
end)

-- Captura das Mensagens Digitadas no Chat do Próprio Jogo
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(message)
        if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId and pairedUser then
            sendWS({ type = "chat", message = message.Text })
        end
    end)
else
    LocalPlayer.Chatted:Connect(function(msg)
        if pairedUser then
            sendWS({ type = "chat", message = msg })
        end
    end)
end

-- Eventos dos Botões de Ação
UnpairBtn.MouseButton1Click:Connect(function()
    sendWS({ type = "unpair" })
end)

BringBtn.MouseButton1Click:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local pos = LocalPlayer.Character.HumanoidRootPart.Position
        sendWS({
            type = "request_bring",
            position = { x = pos.X, y = pos.Y, z = pos.Z }
        })
    end
end)
