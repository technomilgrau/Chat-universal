local RENDER_WEBSOCKET_URL = "wss://chat-universal-k9at.onrender.com"

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local Chat = game:GetService("Chat")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- UI Principal
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaAdvancedMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Bolinha Minimizar ("D")
local MinimizeCircle = Instance.new("TextButton")
MinimizeCircle.Size = UDim2.new(0, 50, 0, 50)
MinimizeCircle.Position = UDim2.new(0.5, -25, 0.1, 0)
MinimizeCircle.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MinimizeCircle.Text = "D"
MinimizeCircle.TextColor3 = Color3.fromRGB(240, 240, 245)
MinimizeCircle.Font = Enum.Font.GothamBold
MinimizeCircle.TextSize = 24
MinimizeCircle.Active = true
MinimizeCircle.Draggable = true
MinimizeCircle.Visible = false
MinimizeCircle.Parent = ScreenGui
Instance.new("UICorner", MinimizeCircle).CornerRadius = UDim.new(1, 0)

-- Janela Principal
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 340)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -170)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Sistema de Scale (Engrenagem / Tamanho)
local UIScale = Instance.new("UIScale", MainFrame)
UIScale.Scale = 1

local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA ADVANCED SYSTEM"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Botões do Header
local HeaderBtnsLayout = Instance.new("UIListLayout", Header)
HeaderBtnsLayout.FillDirection = Enum.FillDirection.Horizontal
HeaderBtnsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
HeaderBtnsLayout.SortOrder = Enum.SortOrder.LayoutOrder
HeaderBtnsLayout.Padding = UDim.new(0, 5)

local HeaderBtnsFrame = Instance.new("Frame", Header)
HeaderBtnsFrame.Size = UDim2.new(0, 100, 1, 0)
HeaderBtnsFrame.Position = UDim2.new(1, -105, 0, 0)
HeaderBtnsFrame.BackgroundTransparency = 1

local SettingsBtn = Instance.new("TextButton", HeaderBtnsFrame)
SettingsBtn.Size = UDim2.new(0, 30, 0, 30)
SettingsBtn.Position = UDim2.new(0, 30, 0, 5)
SettingsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
SettingsBtn.Text = "⚙️"
Instance.new("UICorner", SettingsBtn).CornerRadius = UDim.new(0, 6)

local MinBtn = Instance.new("TextButton", HeaderBtnsFrame)
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(0, 65, 0, 5)
MinBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255,255,255)
MinBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Abas
local TabHolder = Instance.new("Frame", MainFrame)
TabHolder.Size = UDim2.new(1, -20, 0, 30)
TabHolder.Position = UDim2.new(0, 10, 0, 45)
TabHolder.BackgroundTransparency = 1
local TabListLayout = Instance.new("UIListLayout", TabHolder)
TabListLayout.FillDirection = Enum.FillDirection.Horizontal
TabListLayout.Padding = UDim.new(0, 8)

local function createTabBtn(text)
    local b = Instance.new("TextButton", TabHolder)
    b.Size = UDim2.new(0, 90, 1, 0)
    b.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(200, 200, 210)
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local TabUsers = createTabBtn("Usuários")
local TabFriends = createTabBtn("Amigos")
local TabChat = createTabBtn("Chat")
local TabActions = createTabBtn("Ações")
TabActions.Visible = false

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -20, 1, -90)
ContentArea.Position = UDim2.new(0, 10, 0, 80)
ContentArea.BackgroundTransparency = 1

-- Painéis
local PanelUsers = Instance.new("ScrollingFrame", ContentArea)
PanelUsers.Size = UDim2.new(1, 0, 1, 0)
PanelUsers.BackgroundTransparency = 1
PanelUsers.ScrollBarThickness = 4
local LUsers = Instance.new("UIListLayout", PanelUsers)
LUsers.Padding = UDim.new(0, 6)

local PanelFriends = Instance.new("ScrollingFrame", ContentArea)
PanelFriends.Size = UDim2.new(1, 0, 1, 0)
PanelFriends.BackgroundTransparency = 1
PanelFriends.ScrollBarThickness = 4
PanelFriends.Visible = false
local LFriends = Instance.new("UIListLayout", PanelFriends)
LFriends.Padding = UDim.new(0, 6)

-- Painel Configurações (Settings)
local PanelSettings = Instance.new("Frame", ContentArea)
PanelSettings.Size = UDim2.new(1, 0, 1, 0)
PanelSettings.BackgroundTransparency = 1
PanelSettings.Visible = false

local SetLabel = Instance.new("TextLabel", PanelSettings)
SetLabel.Size = UDim2.new(1, 0, 0, 30)
SetLabel.BackgroundTransparency = 1
SetLabel.Text = "Menu Size"
SetLabel.TextColor3 = Color3.fromRGB(255,255,255)
SetLabel.Font = Enum.Font.GothamMedium

local MinusScale = Instance.new("TextButton", PanelSettings)
MinusScale.Size = UDim2.new(0, 40, 0, 40)
MinusScale.Position = UDim2.new(0.5, -90, 0, 40)
MinusScale.Text = "-"
MinusScale.BackgroundColor3 = Color3.fromRGB(40,40,48)
MinusScale.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", MinusScale).CornerRadius = UDim.new(0,8)

local PlusScale = Instance.new("TextButton", PanelSettings)
PlusScale.Size = UDim2.new(0, 40, 0, 40)
PlusScale.Position = UDim2.new(0.5, 50, 0, 40)
PlusScale.Text = "+"
PlusScale.BackgroundColor3 = Color3.fromRGB(40,40,48)
PlusScale.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", PlusScale).CornerRadius = UDim.new(0,8)

local ResetScale = Instance.new("TextButton", PanelSettings)
ResetScale.Size = UDim2.new(0, 80, 0, 40)
ResetScale.Position = UDim2.new(0.5, -40, 0, 40)
ResetScale.Text = "Resetar"
ResetScale.BackgroundColor3 = Color3.fromRGB(200,50,50)
ResetScale.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", ResetScale).CornerRadius = UDim.new(0,8)

local BackSettingsBtn = Instance.new("TextButton", PanelSettings)
BackSettingsBtn.Size = UDim2.new(0, 120, 0, 30)
BackSettingsBtn.Position = UDim2.new(0.5, -60, 1, -30)
BackSettingsBtn.Text = "Voltar"
BackSettingsBtn.BackgroundColor3 = Color3.fromRGB(60,60,70)
BackSettingsBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", BackSettingsBtn).CornerRadius = UDim.new(0,6)

-- Painel Chat
local PanelChat = Instance.new("Frame", ContentArea)
PanelChat.Size = UDim2.new(1, 0, 1, 0)
PanelChat.BackgroundTransparency = 1
PanelChat.Visible = false

local ChatLog = Instance.new("ScrollingFrame", PanelChat)
ChatLog.Size = UDim2.new(1, 0, 1, -35)
ChatLog.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
ChatLog.ScrollBarThickness = 4
Instance.new("UICorner", ChatLog).CornerRadius = UDim.new(0, 6)
local LChat = Instance.new("UIListLayout", ChatLog)
LChat.Padding = UDim.new(0, 4)

local ChatInput = Instance.new("TextBox", PanelChat)
ChatInput.Size = UDim2.new(1, 0, 0, 30)
ChatInput.Position = UDim2.new(0, 0, 1, -30)
ChatInput.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInput.PlaceholderText = "Digite sua mensagem..."
ChatInput.TextColor3 = Color3.fromRGB(240, 240, 240)
ChatInput.ClearTextOnFocus = false
Instance.new("UICorner", ChatInput).CornerRadius = UDim.new(0, 6)

-- Painel Ações
local PanelActions = Instance.new("Frame", ContentArea)
PanelActions.Size = UDim2.new(1, 0, 1, 0)
PanelActions.BackgroundTransparency = 1
PanelActions.Visible = false
local LActions = Instance.new("UIListLayout", PanelActions)
LActions.Padding = UDim.new(0, 8)

local function createActionBtn(txt, col)
    local b = Instance.new("TextButton", PanelActions)
    b.Size = UDim2.new(1, 0, 0, 40)
    b.BackgroundColor3 = col
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    return b
end

local InviteToGroupBtn = createActionBtn("Convidar Amigos pro Chat", Color3.fromRGB(150, 100, 200))
local CloneBtn = createActionBtn("Convite de Clone", Color3.fromRGB(0, 130, 210))
local UnpairBtn = createActionBtn("Desemparear", Color3.fromRGB(190, 40, 40))

-- UI de Pop-up Dinâmico
local PopupFrame = Instance.new("Frame", ScreenGui)
PopupFrame.Size = UDim2.new(0, 300, 0, 150)
PopupFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
PopupFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
PopupFrame.Visible = false
Instance.new("UICorner", PopupFrame).CornerRadius = UDim.new(0, 10)

local PopupText = Instance.new("TextLabel", PopupFrame)
PopupText.Size = UDim2.new(1, -20, 0, 80)
PopupText.Position = UDim2.new(0, 10, 0, 10)
PopupText.BackgroundTransparency = 1
PopupText.TextColor3 = Color3.fromRGB(255,255,255)
PopupText.TextWrapped = true
PopupText.Font = Enum.Font.GothamMedium

local PopYesBtn = Instance.new("TextButton", PopupFrame)
PopYesBtn.Size = UDim2.new(0, 100, 0, 35)
PopYesBtn.Position = UDim2.new(0, 30, 1, -45)
PopYesBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
PopYesBtn.Text = "Sim"
PopYesBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", PopYesBtn).CornerRadius = UDim.new(0, 6)

local PopNoBtn = Instance.new("TextButton", PopupFrame)
PopNoBtn.Size = UDim2.new(0, 100, 0, 35)
PopNoBtn.Position = UDim2.new(1, -130, 1, -45)
PopNoBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
PopNoBtn.Text = "Não"
PopNoBtn.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", PopNoBtn).CornerRadius = UDim.new(0, 6)

local popupConnections = {}
local function showPopup(msg, onYes, onNo)
    PopupText.Text = msg
    PopupFrame.Visible = true
    for _, c in pairs(popupConnections) do c:Disconnect() end
    
    table.insert(popupConnections, PopYesBtn.MouseButton1Click:Connect(function()
        PopupFrame.Visible = false
        if onYes then onYes() end
    end))
    table.insert(popupConnections, PopNoBtn.MouseButton1Click:Connect(function()
        PopupFrame.Visible = false
        if onNo then onNo() end
    end))
end

-- Lógica de Abas
local function switchTab(tab)
    PanelUsers.Visible = (tab == "users")
    PanelFriends.Visible = (tab == "friends")
    PanelChat.Visible = (tab == "chat")
    PanelActions.Visible = (tab == "actions")
    PanelSettings.Visible = (tab == "settings")
end

TabUsers.MouseButton1Click:Connect(function() switchTab("users") end)
TabFriends.MouseButton1Click:Connect(function() switchTab("friends") end)
TabChat.MouseButton1Click:Connect(function() switchTab("chat") end)
TabActions.MouseButton1Click:Connect(function() switchTab("actions") end)
SettingsBtn.MouseButton1Click:Connect(function() switchTab("settings") end)
BackSettingsBtn.MouseButton1Click:Connect(function() switchTab("users") end)

-- Lógica Minimizar/Redimensionar
MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinimizeCircle.Visible = true
    MinimizeCircle.Position = UDim2.new(0, MainFrame.AbsolutePosition.X, 0, MainFrame.AbsolutePosition.Y)
end)
MinimizeCircle.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    MinimizeCircle.Visible = false
    MainFrame.Position = UDim2.new(0, MinimizeCircle.AbsolutePosition.X, 0, MinimizeCircle.AbsolutePosition.Y)
end)

PlusScale.MouseButton1Click:Connect(function() UIScale.Scale = UIScale.Scale + 0.1 end)
MinusScale.MouseButton1Click:Connect(function() UIScale.Scale = math.max(0.5, UIScale.Scale - 0.1) end)
ResetScale.MouseButton1Click:Connect(function() UIScale.Scale = 1 end)

-- WebSocket & Lógica Core
local ws = nil
local inGroup = false
local myFriends = {}
local clonedModels = {}
local cloneSyncConnection = nil

local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function appendChat(sender, text)
    local msg = Instance.new("TextLabel", ChatLog)
    msg.Size = UDim2.new(1, -10, 0, 24)
    msg.BackgroundTransparency = 1
    msg.Text = "  " .. sender .. ": " .. text
    msg.TextColor3 = Color3.fromRGB(230, 230, 240)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 13
    msg.TextXAlignment = Enum.TextXAlignment.Left
    
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, LChat.AbsoluteContentSize.Y + 10)
    ChatLog.CanvasPosition = Vector2.new(0, ChatLog.CanvasSize.Y.Offset)
end

-- Função auxiliar corrigida para não usar Clone e manter os eventos funcionando
local function createUserCard(user, isFriendPanel)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 45)
    card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    
    local img = Instance.new("ImageLabel", card)
    img.Size = UDim2.new(0, 35, 0, 35)
    img.Position = UDim2.new(0, 5, 0, 5)
    img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. user.userId .. "&w=150&h=150"
    img.BackgroundTransparency = 1
    Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
    
    local name = Instance.new("TextLabel", card)
    name.Size = UDim2.new(1, -130, 1, 0)
    name.Position = UDim2.new(0, 48, 0, 0)
    name.BackgroundTransparency = 1
    name.Text = user.username
    name.TextColor3 = Color3.fromRGB(255,255,255)
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.Font = Enum.Font.GothamMedium
    
    -- Botão Parear (✅)
    local pairBtn = Instance.new("TextButton", card)
    pairBtn.Size = UDim2.new(0, 30, 0, 30)
    pairBtn.Position = UDim2.new(1, -35, 0, 7)
    pairBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    pairBtn.Text = "✅"
    Instance.new("UICorner", pairBtn).CornerRadius = UDim.new(0, 6)
    pairBtn.MouseButton1Click:Connect(function()
        sendWS({ type = "pair", targetId = tostring(user.userId) })
    end)
    
    return card
end

-- Renderiza Lista de Usuários e Amigos
local function renderUsers(usersData)
    for _, c in ipairs(PanelUsers:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for _, c in ipairs(PanelFriends:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    local me = nil
    for _, u in ipairs(usersData) do
        if tostring(u.userId) == tostring(LocalPlayer.UserId) then me = u end
    end
    if me then myFriends = me.friends or {} end

    for _, user in ipairs(usersData) do
        if tostring(user.userId) ~= tostring(LocalPlayer.UserId) then
            local isFriend = table.find(myFriends, tostring(user.userId)) ~= nil

            -- Cria o cartão de usuário pra lista Global
            local userCard = createUserCard(user, false)
            userCard.Parent = PanelUsers
            
            -- Se não for amigo, add botão de amizade na lista global
            if not isFriend then
                local addBtn = Instance.new("TextButton", userCard)
                addBtn.Size = UDim2.new(0, 30, 0, 30)
                addBtn.Position = UDim2.new(1, -70, 0, 7)
                addBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
                addBtn.Text = "🫂"
                Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)
                addBtn.MouseButton1Click:Connect(function()
                    sendWS({ type = "friend_request", targetId = tostring(user.userId) })
                    addBtn.Text = "⏳"
                end)
            end

            -- Se for amigo, recria um cartão fresquinho pra lista de amigos
            if isFriend then
                local friendCard = createUserCard(user, true)
                friendCard.Parent = PanelFriends
            end
        end
    end
    PanelUsers.CanvasSize = UDim2.new(0, 0, 0, LUsers.AbsoluteContentSize.Y + 10)
    PanelFriends.CanvasSize = UDim2.new(0, 0, 0, LFriends.AbsoluteContentSize.Y + 10)
end

-- Botão de convidar no menu de ações (redireciona pra amigos)
InviteToGroupBtn.MouseButton1Click:Connect(function()
    switchTab("friends")
end)

-- Conexão e Recebimento
local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "user_list" then
            renderUsers(data.users)
            
        elseif data.type == "friend_request" then
            showPopup(data.fromName .. " te enviou um pedido de amizade!", 
                function() sendWS({ type = "friend_accept", targetId = data.fromId }) end, 
                function() end)
                
        elseif data.type == "paired" then
            inGroup = true
            TabActions.Visible = true
            switchTab("chat")
            appendChat("Sistema", "Você entrou no chat!")
            
        elseif data.type == "unpaired" then
            inGroup = false
            TabActions.Visible = false
            switchTab("users")
            appendChat("Sistema", "Você saiu do grupo.")
            
        elseif data.type == "chat" then
            appendChat(data.sender, data.message)
            -- Replica no balão do clone se ele existir
            for id, cloneModel in pairs(clonedModels) do
                if cloneModel and cloneModel:FindFirstChild("Head") and data.sender ~= "Sistema" then
                    Chat:Chat(cloneModel.Head, data.message, Enum.ChatColor.White)
                end
            end
            
        -- LOGICA DO CLONE 
        elseif data.type == "clone_request" then
            showPopup(data.fromName .. " quer criar um clone seu e se sincronizar!", 
                function() sendWS({ type = "clone_accept", targetId = data.fromId }) end, 
                function() sendWS({ type = "clone_cancel_request", targetId = data.fromId }) end)
                
        elseif data.type == "clone_start" then
            CloneBtn.Text = "Cancelar Clone"
            CloneBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
            
            -- Cria o Manequim
            pcall(function()
                local clone = Players:CreateHumanoidModelFromUserId(tonumber(data.targetId))
                clone.Parent = workspace
                clone.Name = "Clone_" .. data.targetId
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    clone:PivotTo(LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4))
                end
                clonedModels[tostring(data.targetId)] = clone
            end)
            
            -- Começa a enviar a própria posição se estiver com o clone ativo
            if not cloneSyncConnection then
                cloneSyncConnection = RunService.Heartbeat:Connect(function()
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = LocalPlayer.Character.HumanoidRootPart
                        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
                        local anim = "Idle"
                        if hum then
                            if hum:GetState() == Enum.HumanoidStateType.Running then
                                anim = hum.MoveDirection.Magnitude > 0 and "Walk" or "Idle"
                            elseif hum:GetState() == Enum.HumanoidStateType.Jumping then anim = "Jump" end
                        end
                        
                        sendWS({
                            type = "clone_sync",
                            x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z,
                            rx = hrp.Orientation.X, ry = hrp.Orientation.Y, rz = hrp.Orientation.Z,
                            animation = anim
                        })
                    end
                end)
            end
            
        elseif data.type == "clone_cancel_request" then
            showPopup(data.fromName .. " quer cancelar o clone. Aceitar?", 
                function() sendWS({ type = "clone_cancel_accept", targetId = data.fromId }) end, 
                function() end)

        elseif data.type == "clone_stop" then
            CloneBtn.Text = "Convite de Clone"
            CloneBtn.BackgroundColor3 = Color3.fromRGB(0, 130, 210)
            if clonedModels[tostring(data.targetId)] then
                clonedModels[tostring(data.targetId)]:Destroy()
                clonedModels[tostring(data.targetId)] = nil
            end
            if cloneSyncConnection then cloneSyncConnection:Disconnect() cloneSyncConnection = nil end
            
        elseif data.type == "clone_sync" then
            -- Recebe os dados de movimento do clone
            local clone = clonedModels[tostring(data.fromId)]
            if clone and clone:FindFirstChild("HumanoidRootPart") then
                clone:PivotTo(CFrame.new(data.x, data.y, data.z) * CFrame.Angles(math.rad(data.rx), math.rad(data.ry), math.rad(data.rz)))
                local hum = clone:FindFirstChild("Humanoid")
                if hum then
                    if data.animation == "Jump" then hum.Jump = true end
                    if data.animation == "Walk" then hum:Move(Vector3.new(0,0,-1)) else hum:Move(Vector3.new(0,0,0)) end
                end
            end
        end
    end)
    
    sendWS({ type = "register", userId = tostring(LocalPlayer.UserId), username = LocalPlayer.Name })
end

-- Input de Chat: Enviar apenas no Enter
ChatInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        if ChatInput.Text ~= "" and inGroup then
            sendWS({ type = "chat", message = ChatInput.Text })
            ChatInput.Text = "" 
        end
    end
end)

-- Capturar chat normal do jogo
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(message)
        if message.TextSource and message.TextSource.UserId == LocalPlayer.UserId and inGroup then
            sendWS({ type = "chat", message = message.Text })
        end
    end)
else
    LocalPlayer.Chatted:Connect(function(msg)
        if inGroup then sendWS({ type = "chat", message = msg }) end
    end)
end

-- Botões Ações
UnpairBtn.MouseButton1Click:Connect(function() sendWS({ type = "unpair" }) end)

CloneBtn.MouseButton1Click:Connect(function()
    if CloneBtn.Text == "Convite de Clone" then
        appendChat("Sistema", "Convite de clone enviado!")
        for _, u in ipairs(myFriends) do
            sendWS({ type = "clone_request", targetId = u })
        end
    else
        for id, _ in pairs(clonedModels) do
            sendWS({ type = "clone_cancel_request", targetId = id })
        end
    end
end)
