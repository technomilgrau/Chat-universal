local RENDER_WEBSOCKET_URL = "wss://chat-universal-k9at.onrender.com"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- SISTEMA DE ARQUIVOS (DELTA / KRNL API)
-- ==========================================
local folderName = "Mbchat_dados"
if not isfolder(folderName) then makefolder(folderName) end
if not isfolder("Stickers") then makefolder("Stickers") end
if not isfolder("Background_images") then makefolder("Background_images") end

local function SaveData(fileName, data)
    writefile(folderName .. "/" .. fileName .. ".json", HttpService:JSONEncode(data))
end

local function LoadData(fileName, defaultData)
    local path = folderName .. "/" .. fileName .. ".json"
    if isfile(path) then
        local success, result = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if success then return result end
    end
    return defaultData
end

local db_friends = LoadData("friends", {})
local db_history = LoadData("history", {})
local db_recent_stickers = LoadData("recent_stickers", {})
local db_settings = LoadData("settings", { UIScale = 1, PosX = 0.5, PosY = 0.5 })

-- ==========================================
-- CONSTRUÇÃO DA INTERFACE (UI)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaUniversalChat"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = (gethui and gethui()) or CoreGui

local UIScale = Instance.new("UIScale", ScreenGui)
UIScale.Scale = db_settings.UIScale

-- Botão Minimizado (Bolinha "D")
local MinimizedBtn = Instance.new("TextButton")
MinimizedBtn.Size = UDim2.new(0, 50, 0, 50)
MinimizedBtn.Position = UDim2.new(db_settings.PosX, 0, db_settings.PosY, 0)
MinimizedBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
MinimizedBtn.Text = "D"
MinimizedBtn.TextColor3 = Color3.fromRGB(0, 150, 255)
MinimizedBtn.Font = Enum.Font.GothamBlack
MinimizedBtn.TextSize = 24
MinimizedBtn.Visible = false
MinimizedBtn.Parent = ScreenGui
Instance.new("UICorner", MinimizedBtn).CornerRadius = UDim.new(1, 0)

-- Janela Principal
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 520, 0, 380)
MainFrame.Position = UDim2.new(db_settings.PosX, -260, db_settings.PosY, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Background Dinâmico (Grupos)
local ChatBackground = Instance.new("ImageLabel", MainFrame)
ChatBackground.Size = UDim2.new(1, 0, 1, 0)
ChatBackground.BackgroundTransparency = 1
ChatBackground.ImageTransparency = 0.8
ChatBackground.ZIndex = 0

-- Salvar posição ao arrastar
MainFrame:GetPropertyChangedSignal("Position"):Connect(function()
    db_settings.PosX = MainFrame.Position.X.Scale
    db_settings.PosY = MainFrame.Position.Y.Scale
    SaveData("settings", db_settings)
end)

-- Topbar & Controles
local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "DELTA UNIVERSAL"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local ConfigBtn = Instance.new("TextButton", Header)
ConfigBtn.Size = UDim2.new(0, 30, 0, 30)
ConfigBtn.Position = UDim2.new(1, -75, 0, 5)
ConfigBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ConfigBtn.Text = "⚙️"
Instance.new("UICorner", ConfigBtn).CornerRadius = UDim.new(0, 6)

local MinimizeTopBtn = Instance.new("TextButton", Header)
MinimizeTopBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeTopBtn.Position = UDim2.new(1, -35, 0, 5)
MinimizeTopBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
MinimizeTopBtn.Text = "-"
MinimizeTopBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", MinimizeTopBtn).CornerRadius = UDim.new(0, 6)

-- Abas
local TabHolder = Instance.new("Frame", MainFrame)
TabHolder.Size = UDim2.new(1, -20, 0, 30)
TabHolder.Position = UDim2.new(0, 10, 0, 48)
TabHolder.BackgroundTransparency = 1
local TabLayout = Instance.new("UIListLayout", TabHolder)
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 6)

local function createTabBtn(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local SearchFriendsBtn = createTabBtn("Procurar Amigos")
local NotifBtn = createTabBtn("Notificações")
local ChatBtn = createTabBtn("Bate-Papo")
local GroupBtn = createTabBtn("Grupos")
local ActionsBtn = createTabBtn("Ações")

SearchFriendsBtn.Parent, NotifBtn.Parent, ChatBtn.Parent, GroupBtn.Parent, ActionsBtn.Parent = TabHolder, TabHolder, TabHolder, TabHolder, TabHolder
ActionsBtn.Visible = false

-- Containers
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -20, 1, -95)
ContentArea.Position = UDim2.new(0, 10, 0, 85)
ContentArea.BackgroundTransparency = 1

local SearchFrame = Instance.new("Frame", ContentArea)
SearchFrame.Size = UDim2.new(1, 0, 1, 0)
SearchFrame.BackgroundTransparency = 1

local SearchInput = Instance.new("TextBox", SearchFrame)
SearchInput.Size = UDim2.new(1, 0, 0, 30)
SearchInput.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
SearchInput.PlaceholderText = " Pesquisar usuário..."
SearchInput.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", SearchInput).CornerRadius = UDim.new(0, 6)

local SearchScroll = Instance.new("ScrollingFrame", SearchFrame)
SearchScroll.Size = UDim2.new(1, 0, 1, -35)
SearchScroll.Position = UDim2.new(0, 0, 0, 35)
SearchScroll.BackgroundTransparency = 1
SearchScroll.CanvasSize = UDim2.new(0,0,0,0)
local SearchLayout = Instance.new("UIListLayout", SearchScroll)
SearchLayout.Padding = UDim.new(0, 5)

local ChatFrame = Instance.new("Frame", ContentArea)
ChatFrame.Size = UDim2.new(1, 0, 1, 0)
ChatFrame.BackgroundTransparency = 1
ChatFrame.Visible = false

local ChatLog = Instance.new("ScrollingFrame", ChatFrame)
ChatLog.Size = UDim2.new(1, 0, 1, -40)
ChatLog.BackgroundTransparency = 1
local ChatLayout = Instance.new("UIListLayout", ChatLog)
ChatLayout.Padding = UDim.new(0, 4)

local ChatInputBox = Instance.new("TextBox", ChatFrame)
ChatInputBox.Size = UDim2.new(1, -45, 0, 35)
ChatInputBox.Position = UDim2.new(0, 0, 1, -35)
ChatInputBox.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ChatInputBox.PlaceholderText = "Digite a mensagem ou /invite @nick..."
ChatInputBox.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", ChatInputBox).CornerRadius = UDim.new(0, 6)

local StickerBtn = Instance.new("TextButton", ChatFrame)
StickerBtn.Size = UDim2.new(0, 35, 0, 35)
StickerBtn.Position = UDim2.new(1, -35, 1, -35)
StickerBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
StickerBtn.Text = "🙂"
Instance.new("UICorner", StickerBtn).CornerRadius = UDim.new(0, 6)

-- Autocomplete Frame (Discord style)
local AutocompleteFrame = Instance.new("ScrollingFrame", ChatFrame)
AutocompleteFrame.Size = UDim2.new(0, 200, 0, 120)
AutocompleteFrame.Position = UDim2.new(0, 0, 1, -160)
AutocompleteFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
AutocompleteFrame.Visible = false
AutocompleteFrame.ZIndex = 5
local AutoCompLayout = Instance.new("UIListLayout", AutocompleteFrame)

-- Painel Configurações
local ConfigFrame = Instance.new("Frame", MainFrame)
ConfigFrame.Size = UDim2.new(1, 0, 1, 0)
ConfigFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
ConfigFrame.Visible = false
ConfigFrame.ZIndex = 10

local ConfigTitle = Instance.new("TextLabel", ConfigFrame)
ConfigTitle.Size = UDim2.new(1, 0, 0, 40)
ConfigTitle.Text = "Configurações"
ConfigTitle.TextColor3 = Color3.new(1,1,1)
ConfigTitle.BackgroundTransparency = 1

local SizeSlider = Instance.new("TextBox", ConfigFrame)
SizeSlider.Size = UDim2.new(0, 200, 0, 30)
SizeSlider.Position = UDim2.new(0.5, -100, 0.4, 0)
SizeSlider.Text = tostring(db_settings.UIScale)
SizeSlider.BackgroundColor3 = Color3.fromRGB(40,40,50)
SizeSlider.TextColor3 = Color3.new(1,1,1)

local CloseConfig = Instance.new("TextButton", ConfigFrame)
CloseConfig.Size = UDim2.new(0, 100, 0, 30)
CloseConfig.Position = UDim2.new(0.5, -50, 0.7, 0)
CloseConfig.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
CloseConfig.Text = "Voltar"
CloseConfig.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", CloseConfig).CornerRadius = UDim.new(0,6)

-- ==========================================
-- LÓGICA DE INTERFACE
-- ==========================================

local function SwitchTab(tab)
    SearchFrame.Visible = (tab == "search")
    ChatFrame.Visible = (tab == "chat")
    -- Notif e Group usariam a mesma lógica expandida
end

SearchFriendsBtn.MouseButton1Click:Connect(function() SwitchTab("search") end)
ChatBtn.MouseButton1Click:Connect(function() SwitchTab("chat") end)

MinimizeTopBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    MinimizedBtn.Visible = true
end)

MinimizedBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    MinimizedBtn.Visible = false
end)

ConfigBtn.MouseButton1Click:Connect(function() ConfigFrame.Visible = true end)
CloseConfig.MouseButton1Click:Connect(function() ConfigFrame.Visible = false end)

SizeSlider.FocusLost:Connect(function()
    local val = tonumber(SizeSlider.Text)
    if val then
        UIScale.Scale = val
        db_settings.UIScale = val
        SaveData("settings", db_settings)
    end
end)

-- ==========================================
-- WEBSOCKET & SISTEMA DE MENSAGENS
-- ==========================================
local ws = nil
local activeChatId = nil
local activeUsers = {}
local activeClone = nil

local function sendWS(data)
    if ws then ws:Send(HttpService:JSONEncode(data)) end
end

local function addChatMessage(sender, text, isSystem)
    local msg = Instance.new("TextLabel", ChatLog)
    msg.Size = UDim2.new(1, -10, 0, 25)
    msg.BackgroundTransparency = 1
    msg.Text = (isSystem and "⚙️ " or (sender .. ": ")) .. text
    msg.TextColor3 = isSystem and Color3.fromRGB(150, 150, 255) or Color3.fromRGB(240, 240, 240)
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 13
    msg.TextWrapped = true
    msg.TextXAlignment = Enum.TextXAlignment.Left
    
    ChatLog.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10)
    ChatLog.CanvasPosition = Vector2.new(0, ChatLog.CanvasSize.Y.Offset)
end

-- Correção do TextBox apagando
ChatInputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local txt = ChatInputBox.Text
        if txt == "" then return end
        
        -- Parse de Comandos
        if txt:match("^/invite @") then
            local targetNick = txt:gsub("/invite @", "")
            for uid, data in pairs(db_friends) do
                if data.username:lower() == targetNick:lower() then
                    sendWS({type = "chat_invite", targetId = uid, sender = LocalPlayer.Name})
                    addChatMessage("Sistema", "Convite enviado para " .. data.username, true)
                end
            end
        elseif txt == "//leave" then
            activeChatId = nil
            addChatMessage("Sistema", "Você saiu do bate-papo.", true)
        else
            -- Mensagem normal salva no histórico JSON e enviada pro WS
            local payload = {type = "chat_message", targetId = activeChatId, sender = LocalPlayer.Name, message = txt}
            sendWS(payload)
            
            -- Salva localmente
            if activeChatId then
                if not db_history[activeChatId] then db_history[activeChatId] = {} end
                table.insert(db_history[activeChatId], payload)
                SaveData("history", db_history)
            end
        end
        ChatInputBox.Text = "" -- Só limpa se deu Enter e processou
    end
end)

-- Sistema Autocomplete
ChatInputBox:GetPropertyChangedSignal("Text"):Connect(function()
    local txt = ChatInputBox.Text
    if txt:match("^/invite @") or txt:match("^//invitegp @") then
        local query = txt:match("@(.*)"):lower()
        AutocompleteFrame.Visible = true
        for _, c in ipairs(AutocompleteFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        
        for uid, data in pairs(db_friends) do
            if data.username:lower():find(query) then
                local btn = Instance.new("TextButton", AutocompleteFrame)
                btn.Size = UDim2.new(1, 0, 0, 30)
                btn.Text = " " .. data.username
                btn.TextColor3 = Color3.new(1,1,1)
                btn.BackgroundTransparency = 1
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.MouseButton1Click:Connect(function()
                    ChatInputBox.Text = (txt:match("^/invite") and "/invite @" or "//invitegp @") .. data.username
                    ChatInputBox:CaptureFocus()
                    AutocompleteFrame.Visible = false
                end)
            end
        end
    else
        AutocompleteFrame.Visible = false
    end
end)

-- ==========================================
-- CLONE CROSS-GAME & ANIMAÇÕES R6/R15
-- ==========================================
local clonedRig = nil

local function BuildCloneRig(targetUserId)
    pcall(function()
        if clonedRig then clonedRig:Destroy() end
        -- Gera a aparência do usuário perfeitamente
        clonedRig = Players:CreateHumanoidModelFromUserId(targetUserId)
        clonedRig.Parent = workspace
        
        local targetPos = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4)
        clonedRig:SetPrimaryPartCFrame(CFrame.lookAt(targetPos.Position, LocalPlayer.Character.HumanoidRootPart.Position))
        
        addChatMessage("Sistema", "Clone carregado. Sincronizando manipulação de parts...", true)
    end)
end

local function SyncCloneData()
    if not activeClone or not LocalPlayer.Character then return end
    
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    -- Extrai animações e CFrame
    local anims = {}
    for _, track in pairs(hum:GetPlayingAnimationTracks()) do
        table.insert(anims, track.Animation.AnimationId)
    end
    
    sendWS({
        type = "sync_clone",
        targetId = activeClone,
        cframe = {x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z, rx = hrp.Orientation.X, ry = hrp.Orientation.Y, rz = hrp.Orientation.Z},
        animations = anims
    })
end

-- Envia dados físicos 10 vezes por segundo se o clone estiver ativo
RunService.Heartbeat:Connect(function()
    if tick() % 0.1 < 0.05 and activeClone then
        SyncCloneData()
    end
end)

-- ==========================================
-- INICIALIZAÇÃO E RECEPÇÃO WEBSOCKET
-- ==========================================
local WebSocketApi = WebSocket or (syn and syn.websocket)
if WebSocketApi then
    ws = WebSocketApi.connect(RENDER_WEBSOCKET_URL)
    
    ws.OnMessage:Connect(function(msg)
        local data = HttpService:JSONDecode(msg)
        
        if data.type == "chat_message" then
            addChatMessage(data.sender, data.message, false)
            
            -- Salva mensagens recebidas no JSON correspondente
            local chatKey = data.groupId or data.senderId
            if chatKey then
                if not db_history[chatKey] then db_history[chatKey] = {} end
                table.insert(db_history[chatKey], data)
                SaveData("history", db_history)
            end
            
        elseif data.type == "chat_invite" then
            addChatMessage("Notificação", data.sender .. " te convidou para um bate-papo! Escreva /accept", true)
            -- A lógica de /accept setaria activeChatId = data.senderId
            
        elseif data.type == "clone_invite" then
            addChatMessage("Notificação", "Convite de clone recebido! (Acesse a aba ações)", true)
            ActionsBtn.Visible = true
            
        elseif data.type == "sync_clone" and clonedRig then
            -- Mapeia a posição recebida
            local cframeData = data.cframe
            clonedRig:SetPrimaryPartCFrame(CFrame.new(cframeData.x, cframeData.y, cframeData.z) * CFrame.Angles(math.rad(cframeData.rx), math.rad(cframeData.ry), math.rad(cframeData.rz)))
            
            -- Nota: A execução exata de partes e JSONs (como no editor R6 3D que você tem em mente)
            -- seria inserida aqui, mapeando offsets customizados diretamente nos Motor6Ds do clone.
        end
    end)
    
    sendWS({ type = "register", userId = tostring(LocalPlayer.UserId), username = LocalPlayer.Name })
end

-- ==========================================
-- BACKGROUND & FIGURINHAS (CARREGAMENTO LOCAL)
-- ==========================================
local function LoadStickers()
    -- Lê os arquivos na pasta Stickers usando funções de exploit
    if listfiles then
        local files = listfiles("Stickers")
        for _, file in ipairs(files) do
            -- Cria botão na UI de figurinhas com file (que pode ser convertido em rbxasset ou base64)
        end
    end
end

local function SetBackground(imageName, opacity)
    -- Carrega imagem da pasta Background_images
    if isfile("Background_images/" .. imageName) then
        -- Roblox exploit API function (getcustomasset) permite usar imagens locais
        if getcustomasset then
            ChatBackground.Image = getcustomasset("Background_images/" .. imageName)
            ChatBackground.ImageTransparency = opacity
        end
    end
end

-- Final: Notifica conclusão de carregamento UI
print("Delta Universal carregado com sucesso. Dados armazenados em: " .. folderName)
