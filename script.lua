-- ==========================================
-- CHAT-UNIVERSAL (Baseado no design Move Block V4 + Profiles & Stickers)
-- Autor: techno_milgrau
-- ==========================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local SERVER_URL = "https://chat-universal-gb22.onrender.com"

-- Banco de IDs de Stickers (Você pode adicionar mais IDs de imagens do Roblox aqui)
local StickerBank = {
    "rbxassetid://13482381228", "rbxassetid://10672052187", "rbxassetid://1234567890", -- Troque pelos seus
    "rbxassetid://9876543210"
}

-- ==========================================
-- SISTEMA DE PASTAS E ARQUIVOS (JSON)
-- ==========================================
local BaseFolder = "ChatUniversal_Data"
local FriendsFile = BaseFolder .. "/Amigos.json"
local StickersFile = BaseFolder .. "/StickersRecentes.json"

pcall(function() if isfolder and not isfolder(BaseFolder) then makefolder(BaseFolder) end end)

local LocalData = { Friends = {}, RecentStickers = {} }

local function SaveJSON(path, data)
    pcall(function() if writefile then writefile(path, HttpService:JSONEncode(data)) end end)
end

local function LoadJSON(path, default)
    local result = default
    pcall(function()
        if isfile and isfile(path) then
            local decoded = HttpService:JSONDecode(readfile(path))
            if decoded then result = decoded end
        end
    end)
    return result
end

LocalData.Friends = LoadJSON(FriendsFile, {})
LocalData.RecentStickers = LoadJSON(StickersFile, {})

local function SaveFriends() SaveJSON(FriendsFile, LocalData.Friends) end
local function SaveStickers() SaveJSON(StickersFile, LocalData.RecentStickers) end

local function GetChatFilePath(friendName) return BaseFolder .. "/Chat_" .. friendName .. ".json" end
local function SaveChat(friendName, chatHistory) SaveJSON(GetChatFilePath(friendName), chatHistory) end
local function LoadChat(friendName) return LoadJSON(GetChatFilePath(friendName), {}) end

local function GenerateMsgId() return tostring(os.time()) .. tostring(math.random(1000, 9999)) end

-- ==========================================
-- SINC DE AMIGOS E REGISTRO
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

local function SyncFriendsWithServer()
    pcall(function()
        local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_friends?username=" .. player.Name, Method = "GET"})
        if res.Success then
            local serverFriends = HttpService:JSONDecode(res.Body)
            LocalData.Friends = serverFriends
            SaveFriends()
        end
    end)
end

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
MainFrameWrapper.BackgroundColor3 = Color3.fromRGB(15, 15, 18) -- Fundo mais escuro
MainFrameWrapper.BorderSizePixel = 0
MainFrameWrapper.ClipsDescendants = true
local MainCorner = Instance.new("UICorner", MainFrameWrapper)
MainCorner.CornerRadius = UDim.new(0, 10)

-- POPUPS OVERLAY (Fica por cima de tudo)
local PopupOverlay = Instance.new("Frame", ScreenGui)
PopupOverlay.Size = UDim2.new(1, 0, 1, 0)
PopupOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
PopupOverlay.BackgroundTransparency = 0.5
PopupOverlay.Visible = false
PopupOverlay.ZIndex = 100

local PopupBox = Instance.new("Frame", PopupOverlay)
PopupBox.Size = UDim2.new(0, 240, 0, 150)
PopupBox.Position = UDim2.new(0.5, -120, 0.5, -75)
PopupBox.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
Instance.new("UICorner", PopupBox).CornerRadius = UDim.new(0, 8)

local PopupTitle = Instance.new("TextLabel", PopupBox)
PopupTitle.Size = UDim2.new(1, 0, 0, 30) PopupTitle.BackgroundTransparency = 1 PopupTitle.TextColor3 = Color3.fromRGB(255,255,255)
PopupTitle.Font = Enum.Font.GothamBold PopupTitle.TextSize = 14

local PopupInput = Instance.new("TextBox", PopupBox)
PopupInput.Size = UDim2.new(1, -20, 0, 60) PopupInput.Position = UDim2.new(0, 10, 0, 35)
PopupInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25) PopupInput.TextColor3 = Color3.fromRGB(255,255,255)
PopupInput.Font = Enum.Font.Gotham PopupInput.TextSize = 12 PopupInput.TextWrapped = true PopupInput.ClearTextOnFocus = false
PopupInput.MultiLine = true PopupInput.TextYAlignment = Enum.TextYAlignment.Top
Instance.new("UICorner", PopupInput).CornerRadius = UDim.new(0, 4)

local PopupBtnYes = Instance.new("TextButton", PopupBox)
PopupBtnYes.Size = UDim2.new(0, 100, 0, 30) PopupBtnYes.Position = UDim2.new(0, 15, 1, -40)
PopupBtnYes.BackgroundColor3 = Color3.fromRGB(46, 204, 113) PopupBtnYes.Text = "Sim" PopupBtnYes.TextColor3 = Color3.fromRGB(255,255,255) PopupBtnYes.Font = Enum.Font.GothamBold
Instance.new("UICorner", PopupBtnYes).CornerRadius = UDim.new(0, 4)

local PopupBtnNo = Instance.new("TextButton", PopupBox)
PopupBtnNo.Size = UDim2.new(0, 100, 0, 30) PopupBtnNo.Position = UDim2.new(1, -115, 1, -40)
PopupBtnNo.BackgroundColor3 = Color3.fromRGB(231, 76, 60) PopupBtnNo.Text = "Não" PopupBtnNo.TextColor3 = Color3.fromRGB(255,255,255) PopupBtnNo.Font = Enum.Font.GothamBold
Instance.new("UICorner", PopupBtnNo).CornerRadius = UDim.new(0, 4)

local currentPopupCallback = nil
local function ShowPopup(title, showInput, inputText, yesText, noText, callback)
    PopupTitle.Text = title
    PopupInput.Visible = showInput
    if showInput then PopupInput.Text = inputText or "" end
    PopupBtnYes.Text = yesText or "Sim"
    PopupBtnNo.Text = noText or "Não"
    PopupOverlay.Visible = true
    currentPopupCallback = callback
end

PopupBtnYes.MouseButton1Click:Connect(function()
    PopupOverlay.Visible = false
    if currentPopupCallback then currentPopupCallback(true, PopupInput.Text) end
end)
PopupBtnNo.MouseButton1Click:Connect(function()
    PopupOverlay.Visible = false
    if currentPopupCallback then currentPopupCallback(false) end
end)
PopupInput:GetPropertyChangedSignal("Text"):Connect(function()
    if #PopupInput.Text > 80 then PopupInput.Text = string.sub(PopupInput.Text, 1, 80) end
end)

-- Barra de Título
local TitleBar = Instance.new("Frame", MainFrameWrapper)
TitleBar.Size = UDim2.new(1, 0, 0, 40) TitleBar.BackgroundTransparency = 1 TitleBar.ZIndex = 10
local dragging, dragStart, startPos = false, nil, nil
TitleBar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = i.Position startPos = MainFrameWrapper.Position end end)
UserInputService.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement and dragging then local delta = i.Position - dragStart MainFrameWrapper.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -80, 0, 20) Title.Position = UDim2.new(0, 10, 0, 5) Title.BackgroundTransparency = 1 Title.Text = "Chat-universal" Title.TextColor3 = Color3.fromRGB(255, 255, 255) Title.Font = Enum.Font.GothamBold Title.TextSize = 18 Title.TextXAlignment = Enum.TextXAlignment.Left
local Subtitle = Instance.new("TextLabel", TitleBar) Subtitle.Size = UDim2.new(1, -80, 0, 12) Subtitle.Position = UDim2.new(0, 10, 0, 24) Subtitle.BackgroundTransparency = 1 Subtitle.Text = "techno_milgrau" Subtitle.TextColor3 = Color3.fromRGB(150, 150, 150) Subtitle.Font = Enum.Font.Gotham Subtitle.TextSize = 10 Subtitle.TextXAlignment = Enum.TextXAlignment.Left

local NotifyBtn = Instance.new("TextButton", TitleBar) NotifyBtn.Size = UDim2.new(0, 30, 0, 30) NotifyBtn.Position = UDim2.new(1, -65, 0, 5) NotifyBtn.BackgroundTransparency = 1 NotifyBtn.Text = "🔔" NotifyBtn.TextColor3 = Color3.fromRGB(200, 200, 200) NotifyBtn.Font = Enum.Font.GothamBold NotifyBtn.TextSize = 16
local MinimizeBtn = Instance.new("TextButton", TitleBar) MinimizeBtn.Size = UDim2.new(0, 30, 0, 30) MinimizeBtn.Position = UDim2.new(1, -35, 0, 5) MinimizeBtn.BackgroundTransparency = 1 MinimizeBtn.Text = "−" MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200) MinimizeBtn.Font = Enum.Font.GothamBold MinimizeBtn.TextSize = 20

local MinimizedIcon = Instance.new("TextButton", ScreenGui) MinimizedIcon.Size = UDim2.new(0, 50, 0, 50) MinimizedIcon.Position = UDim2.new(0.5, -25, 0.5, -25) MinimizedIcon.BackgroundColor3 = Color3.fromRGB(30,30,35) MinimizedIcon.Text = "C" MinimizedIcon.TextColor3 = Color3.fromRGB(255,255,255) MinimizedIcon.Font = Enum.Font.GothamBold MinimizedIcon.TextSize = 24 MinimizedIcon.Visible = false Instance.new("UICorner", MinimizedIcon).CornerRadius = UDim.new(0,25)
local minDrag = false local minDragStart, minStartPos
MinimizedIcon.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then minDrag = true minDragStart = i.Position minStartPos = MinimizedIcon.Position end end)
UserInputService.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement and minDrag then local delta = i.Position - minDragStart MinimizedIcon.Position = UDim2.new(minStartPos.X.Scale, minStartPos.X.Offset + delta.X, minStartPos.Y.Scale, minStartPos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then minDrag = false end end)

MinimizeBtn.MouseButton1Click:Connect(function() MainFrameWrapper.Visible = false MinimizedIcon.Visible = true end)
MinimizedIcon.MouseButton1Click:Connect(function() MainFrameWrapper.Visible = true MinimizedIcon.Visible = false end)

-- ==========================================
-- GERENCIADOR DE ABAS
-- ==========================================
local SettingsPanel = Instance.new("Frame", MainFrameWrapper) SettingsPanel.Size = UDim2.new(1, 0, 1, -40) SettingsPanel.Position = UDim2.new(0, 0, 0, 40) SettingsPanel.BackgroundTransparency = 1
local function CreateMenuFrame(name) local f = Instance.new("Frame", SettingsPanel) f.Name = name f.Size = UDim2.new(1, 0, 1, 0) f.Position = UDim2.new(1, 0, 0, 0) f.BackgroundTransparency = 1 return f end

local MainMenu = CreateMenuFrame("MainMenu") MainMenu.Position = UDim2.new(0, 0, 0, 0)
local SearchMenu = CreateMenuFrame("SearchMenu")
local FriendsMenu = CreateMenuFrame("FriendsMenu")
local PrivateChatMenu = CreateMenuFrame("PrivateChatMenu")
local NotificationsMenu = CreateMenuFrame("NotificationsMenu")
local ProfileMenu = CreateMenuFrame("ProfileMenu")

local MenuStack = {MainMenu}
local CurrentMenu = MainMenu

local function OpenMenu(newMenu)
    if CurrentMenu == newMenu then return end
    CurrentMenu:TweenPosition(UDim2.new(-1, 0, 0, 0), "Out", "Quad", 0.2, true)
    newMenu.Position = UDim2.new(1, 0, 0, 0) newMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
    table.insert(MenuStack, newMenu) CurrentMenu = newMenu
end
local function CloseMenu()
    if #MenuStack <= 1 then return end
    local menuToClose = table.remove(MenuStack)
    local previousMenu = MenuStack[#MenuStack]
    menuToClose:TweenPosition(UDim2.new(1, 0, 0, 0), "Out", "Quad", 0.2, true)
    previousMenu.Position = UDim2.new(-1, 0, 0, 0) previousMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
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
-- MENU PRINCIPAL (BOTÕES)
-- ==========================================
local function CreateMainBtn(yPos, text, icon, callback)
    local btn = Instance.new("TextButton", MainMenu)
    btn.Size = UDim2.new(0, 240, 0, 45) btn.Position = UDim2.new(0.5, -120, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40) btn.Text = icon .. " " .. text btn.TextColor3 = Color3.fromRGB(255, 255, 255) btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end
CreateMainBtn(20, "Procurar Amigos", "🔍", function() OpenMenu(SearchMenu) end)
CreateMainBtn(75, "Mensagens", "💬", function() SyncFriendsWithServer() OpenMenu(FriendsMenu) LoadFriendsUI() end)
CreateMainBtn(130, "Meu Perfil", "👤", function() OpenProfile(player.Name, player.DisplayName, player.UserId, true) end)
NotifyBtn.MouseButton1Click:Connect(function() if CurrentMenu ~= NotificationsMenu then OpenMenu(NotificationsMenu) LoadNotificationsUI() end end)

-- ==========================================
-- SISTEMA DE PERFIL DETALHADO (UI + LÓGICA)
-- ==========================================
createTopBar(ProfileMenu, "Perfil")
local ProfAvatar = Instance.new("ImageLabel", ProfileMenu) ProfAvatar.Size = UDim2.new(0, 100, 0, 100) ProfAvatar.Position = UDim2.new(0.5, -50, 0, 50) ProfAvatar.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", ProfAvatar).CornerRadius = UDim.new(1, 0)
local ProfDName = Instance.new("TextLabel", ProfileMenu) ProfDName.Size = UDim2.new(1, 0, 0, 25) ProfDName.Position = UDim2.new(0, 0, 0, 160) ProfDName.BackgroundTransparency = 1 ProfDName.TextColor3 = Color3.fromRGB(255, 255, 255) ProfDName.Font = Enum.Font.GothamBold ProfDName.TextSize = 18
local ProfUName = Instance.new("TextLabel", ProfileMenu) ProfUName.Size = UDim2.new(1, 0, 0, 15) ProfUName.Position = UDim2.new(0, 0, 0, 185) ProfUName.BackgroundTransparency = 1 ProfUName.TextColor3 = Color3.fromRGB(180, 180, 180) ProfUName.Font = Enum.Font.Gotham ProfUName.TextSize = 12
local ProfStats = Instance.new("TextLabel", ProfileMenu) ProfStats.Size = UDim2.new(1, 0, 0, 20) ProfStats.Position = UDim2.new(0, 0, 0, 210) ProfStats.BackgroundTransparency = 1 ProfStats.TextColor3 = Color3.fromRGB(255, 255, 255) ProfStats.Font = Enum.Font.GothamBold ProfStats.TextSize = 14

local ProfActionBtn = Instance.new("TextButton", ProfileMenu) ProfActionBtn.Size = UDim2.new(0, 200, 0, 40) ProfActionBtn.Position = UDim2.new(0.5, -100, 0, 240) ProfActionBtn.Font = Enum.Font.GothamBold ProfActionBtn.TextSize = 14 Instance.new("UICorner", ProfActionBtn).CornerRadius = UDim.new(0, 8)
local ProfBioBtn = Instance.new("TextButton", ProfileMenu) ProfBioBtn.Size = UDim2.new(1, -40, 0, 100) ProfBioBtn.Position = UDim2.new(0, 20, 0, 300) ProfBioBtn.BackgroundTransparency = 1 ProfBioBtn.TextColor3 = Color3.fromRGB(255, 255, 255) ProfBioBtn.Font = Enum.Font.Gotham ProfBioBtn.TextSize = 12 ProfBioBtn.TextYAlignment = Enum.TextYAlignment.Top ProfBioBtn.TextWrapped = true

function OpenProfile(targetUser, targetDisplay, targetId, isSelf)
    ProfAvatar.Image = "rbxthumb://type=AvatarHeadShot&id="..targetId.."&w=150&h=150"
    ProfDName.Text = targetDisplay
    ProfUName.Text = "@" .. targetUser
    ProfStats.Text = "Carregando..."
    ProfBioBtn.Text = "Carregando bio..."
    
    local isFriend = table.find(LocalData.Friends, targetUser)
    if isSelf then
        ProfActionBtn.Visible = false
    else
        ProfActionBtn.Visible = true
        if isFriend then
            ProfActionBtn.Text = "Mensagem" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) ProfActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            ProfActionBtn.Text = "Adicionar" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) ProfActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end

    ProfActionBtn.MouseButton1Click:Connect(function()
        if isFriend then
            OpenPrivateChat(targetUser, targetDisplay, targetId)
        else
            ProfActionBtn.Text = "Enviado" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, fromDisplay = player.DisplayName, fromId = player.UserId, to = targetUser})}) end)
        end
    end)

    task.spawn(function()
        local res = pcall(function() return HttpService:RequestAsync({Url = SERVER_URL .. "/get_profile?target=" .. targetUser, Method = "GET"}) end)
        if type(res) == "table" and res.Success then
            local data = HttpService:JSONDecode(res.Body)
            ProfStats.Text = tostring(data.friendsCount) .. "\nAmigos"
            
            local currentBio = data.bio
            if currentBio == "" then
                ProfBioBtn.Text = isSelf and "<font color=\"rgb(255,255,255)\"><b>adicionar bio+</b></font>" or "Sem biografia."
            else
                ProfBioBtn.Text = currentBio
            end
            ProfBioBtn.RichText = true
            
            local connection
            connection = ProfBioBtn.MouseButton1Click:Connect(function()
                if isSelf then
                    local title = currentBio == "" and "Adicionar Bio" or "Editar biografia?"
                    ShowPopup(title, true, currentBio, "Salvar", "Cancelar", function(confirmed, text)
                        if confirmed then
                            ProfBioBtn.Text = text ~= "" and text or "<font color=\"rgb(255,255,255)\"><b>adicionar bio+</b></font>"
                            pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/update_bio", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({username = player.Name, bio = text})}) end)
                        end
                    end)
                end
                connection:Disconnect() -- Prevent memory leaks on multiple profile loads
            end)
        end
    end)
    OpenMenu(ProfileMenu)
end

-- ==========================================
-- PESQUISA, AMIGOS E NOTIFICAÇÕES (UI)
-- ==========================================
local function CreateUserEntry(parent, displayName, username, userId, mode, statusText)
    local frame = Instance.new("Frame", parent) frame.Size = UDim2.new(1, -20, 0, 60) frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30) Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local avatar = Instance.new("ImageLabel", frame) avatar.Size = UDim2.new(0, 45, 0, 45) avatar.Position = UDim2.new(0, 8, 0, 7) avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", avatar).CornerRadius = UDim.new(0, 6) pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..userId.."&w=150&h=150" end)
    local dName = Instance.new("TextLabel", frame) dName.Size = UDim2.new(0, 100, 0, 20) dName.Position = UDim2.new(0, 60, 0, 8) dName.BackgroundTransparency = 1 dName.Text = displayName dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left
    local uName = Instance.new("TextLabel", frame) uName.Size = UDim2.new(0, 90, 0, 16) uName.Position = UDim2.new(0, 60, 0, 32) uName.BackgroundTransparency = 1 uName.Text = "@" .. username uName.TextColor3 = Color3.fromRGB(150, 150, 150) uName.Font = Enum.Font.Gotham uName.TextSize = 10 uName.TextXAlignment = Enum.TextXAlignment.Left
    
    local hitBox = Instance.new("TextButton", frame) hitBox.Size = UDim2.new(1, -80, 1, 0) hitBox.BackgroundTransparency = 1 hitBox.Text = ""
    hitBox.MouseButton1Click:Connect(function() OpenProfile(username, displayName, userId, false) end)

    if mode == "Search" then
        local actionBtn = Instance.new("TextButton", frame) actionBtn.Size = UDim2.new(0, 70, 0, 26) actionBtn.Position = UDim2.new(1, -78, 0.5, -13) actionBtn.Font = Enum.Font.GothamBold actionBtn.TextSize = 11 Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)
        if table.find(LocalData.Friends, username) then
            actionBtn.Text = "Amigos" actionBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            actionBtn.MouseButton1Click:Connect(function()
                ShowPopup("Desfazer amizade?", false, "", "Sim", "Não", function(conf)
                    if conf then
                        pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/remove_friend", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = username})}) end)
                        table.remove(LocalData.Friends, table.find(LocalData.Friends, username)) SaveFriends() actionBtn.Text = "Adicionar" actionBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84)
                    end
                end)
            end)
        else
            actionBtn.Text = "Adicionar" actionBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            actionBtn.MouseButton1Click:Connect(function() actionBtn.Text = "Enviado" actionBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50) pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, fromDisplay = player.DisplayName, fromId = player.UserId, to = username})}) end) end)
        end
    elseif mode == "Friend" then
        local statusLabel = Instance.new("TextLabel", frame) statusLabel.Size = UDim2.new(0, 70, 0, 16) statusLabel.Position = UDim2.new(1, -78, 0.5, -8) statusLabel.BackgroundTransparency = 1 statusLabel.Font = Enum.Font.Gotham statusLabel.TextSize = 10 statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusLabel.Text = statusText or "Offline"
        if statusLabel.Text == "Online" then statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113) elseif statusLabel.Text == "Digitando..." then statusLabel.TextColor3 = Color3.fromRGB(241, 196, 15) else statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150) end
        local fullHitBox = Instance.new("TextButton", frame) fullHitBox.Size = UDim2.new(1,0,1,0) fullHitBox.BackgroundTransparency = 1 fullHitBox.Text = "" fullHitBox.MouseButton1Click:Connect(function() OpenPrivateChat(username, displayName, userId) end)
    end
    return frame
end

createTopBar(SearchMenu, "Procurar Amigos")
local SearchBoxFrame = Instance.new("Frame", SearchMenu) SearchBoxFrame.Size = UDim2.new(1, -20, 0, 35) SearchBoxFrame.Position = UDim2.new(0, 10, 0, 45) SearchBoxFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30) Instance.new("UICorner", SearchBoxFrame).CornerRadius = UDim.new(0, 6)
local SearchInput = Instance.new("TextBox", SearchBoxFrame) SearchInput.Size = UDim2.new(1, -20, 1, 0) SearchInput.Position = UDim2.new(0, 10, 0, 0) SearchInput.BackgroundTransparency = 1 SearchInput.PlaceholderText = "Pesquisar nick..." SearchInput.Text = "" SearchInput.TextColor3 = Color3.fromRGB(255, 255, 255) SearchInput.Font = Enum.Font.Gotham SearchInput.TextSize = 13 SearchInput.TextXAlignment = Enum.TextXAlignment.Left
local SearchResults = Instance.new("ScrollingFrame", SearchMenu) SearchResults.Size = UDim2.new(1, 0, 1, -90) SearchResults.Position = UDim2.new(0, 0, 0, 90) SearchResults.BackgroundTransparency = 1 SearchResults.ScrollBarThickness = 3
local SearchLayout = Instance.new("UIListLayout", SearchResults) SearchLayout.Padding = UDim.new(0, 8) SearchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center SearchLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SearchResults.CanvasSize = UDim2.new(0, 0, 0, SearchLayout.AbsoluteContentSize.Y + 10) end)

SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    for _, child in pairs(SearchResults:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    if SearchInput.Text == "" then return end
    task.delay(0.5, function()
        pcall(function()
            local res = HttpService:RequestAsync({Url = SERVER_URL .. "/users?query=" .. HttpService:UrlEncode(SearchInput.Text), Method = "GET"})
            if res.Success then
                for _, u in ipairs(HttpService:JSONDecode(res.Body)) do
                    if u.username ~= player.Name then CreateUserEntry(SearchResults, u.displayName or u.username, u.username, u.userId or 1, "Search") end
                end
            end
        end)
    end)
end)

createTopBar(NotificationsMenu, "Notificações")
local RequestsList = Instance.new("ScrollingFrame", NotificationsMenu) RequestsList.Size = UDim2.new(1, 0, 1, -50) RequestsList.Position = UDim2.new(0, 0, 0, 50) RequestsList.BackgroundTransparency = 1 RequestsList.ScrollBarThickness = 3
local ReqLayout = Instance.new("UIListLayout", RequestsList) ReqLayout.Padding = UDim.new(0, 8) ReqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center ReqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RequestsList.CanvasSize = UDim2.new(0, 0, 0, ReqLayout.AbsoluteContentSize.Y + 10) end)

function LoadNotificationsUI()
    for _, child in pairs(RequestsList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    pcall(function()
        local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_requests?username=" .. player.Name, Method = "GET"})
        if res.Success then
            for _, req in ipairs(HttpService:JSONDecode(res.Body)) do
                local card = Instance.new("Frame", RequestsList) card.Size = UDim2.new(1, -20, 0, 60) card.BackgroundColor3 = Color3.fromRGB(25, 25, 30) Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
                local dName = Instance.new("TextLabel", card) dName.Size = UDim2.new(0, 100, 0, 18) dName.Position = UDim2.new(0, 60, 0, 10) dName.BackgroundTransparency = 1 dName.Text = req.fromDisplay or req.from dName.TextColor3 = Color3.fromRGB(255, 255, 255) dName.Font = Enum.Font.GothamBold dName.TextXAlignment = Enum.TextXAlignment.Left dName.TextSize = 12
                local acceptBtn = Instance.new("TextButton", card) acceptBtn.Size = UDim2.new(0, 28, 0, 28) acceptBtn.Position = UDim2.new(1, -65, 0.5, -14) acceptBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113) acceptBtn.Text = "✓" acceptBtn.TextColor3 = Color3.fromRGB(255, 255, 255) acceptBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 6)
                local declineBtn = Instance.new("TextButton", card) declineBtn.Size = UDim2.new(0, 28, 0, 28) declineBtn.Position = UDim2.new(1, -32, 0.5, -14) declineBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60) declineBtn.Text = "✕" declineBtn.TextColor3 = Color3.fromRGB(255, 255, 255) declineBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", declineBtn).CornerRadius = UDim.new(0, 6)
                
                acceptBtn.MouseButton1Click:Connect(function()
                    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/accept_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from})}) end)
                    if not table.find(LocalData.Friends, req.from) then table.insert(LocalData.Friends, req.from) SaveFriends() end
                    card:Destroy()
                end)
                declineBtn.MouseButton1Click:Connect(function() pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/decline_request", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({user = player.Name, friend = req.from})}) end) card:Destroy() end)
            end
        end
    end)
end

createTopBar(FriendsMenu, "Mensagens")
local FriendsList = Instance.new("ScrollingFrame", FriendsMenu) FriendsList.Size = UDim2.new(1, 0, 1, -50) FriendsList.Position = UDim2.new(0, 0, 0, 50) FriendsList.BackgroundTransparency = 1 FriendsList.ScrollBarThickness = 3
local FriendsLayout = Instance.new("UIListLayout", FriendsList) FriendsLayout.Padding = UDim.new(0, 8) FriendsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center FriendsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() FriendsList.CanvasSize = UDim2.new(0, 0, 0, FriendsLayout.AbsoluteContentSize.Y + 10) end)

function LoadFriendsUI()
    for _, child in pairs(FriendsList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, friendName in ipairs(LocalData.Friends) do
        local targetId = 1 pcall(function() targetId = Players:GetUserIdFromNameAsync(friendName) end)
        local statusText = "Offline" pcall(function() local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_status?username=" .. friendName, Method = "GET"}) if res.Success then statusText = HttpService:JSONDecode(res.Body).status end end)
        CreateUserEntry(FriendsList, friendName, friendName, targetId, "Friend", statusText)
    end
end

-- ==========================================
-- CHAT PRIVADO E FIGURINHAS (AUTOMATIC SIZE + EDIÇÃO)
-- ==========================================
local ActiveChatTarget = ""
local ActiveChatTargetDisplay = ""
local ActiveChatTargetId = 1

local ChatTitle = createTopBar(PrivateChatMenu, "Chat", function() CloseMenu() ActiveChatTarget = "" end)

local ChatScroll = Instance.new("ScrollingFrame", PrivateChatMenu) ChatScroll.Size = UDim2.new(1, -20, 1, -100) ChatScroll.Position = UDim2.new(0, 10, 0, 45) ChatScroll.BackgroundTransparency = 1 ChatScroll.ScrollBarThickness = 4
local ChatLayout = Instance.new("UIListLayout", ChatScroll) ChatLayout.Padding = UDim.new(0, 8) ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ChatScroll.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10) end)

local ChatInputFrame = Instance.new("Frame", PrivateChatMenu) ChatInputFrame.Size = UDim2.new(1, -20, 0, 40) ChatInputFrame.Position = UDim2.new(0, 10, 1, -50) ChatInputFrame.BackgroundTransparency = 1
local ChatBox = Instance.new("TextBox", ChatInputFrame) ChatBox.Size = UDim2.new(1, -105, 1, 0) ChatBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30) ChatBox.TextColor3 = Color3.fromRGB(255, 255, 255) ChatBox.Font = Enum.Font.Gotham ChatBox.TextSize = 13 ChatBox.PlaceholderText = "Mensagem..." ChatBox.Text = "" ChatBox.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UICorner", ChatBox).CornerRadius = UDim.new(0, 15) local UIPaddingBox = Instance.new("UIPadding", ChatBox) UIPaddingBox.PaddingLeft = UDim.new(0, 10) UIPaddingBox.PaddingRight = UDim.new(0, 10)
local StickerBtn = Instance.new("TextButton", ChatInputFrame) StickerBtn.Size = UDim2.new(0, 30, 0, 30) StickerBtn.Position = UDim2.new(1, -95, 0, 5) StickerBtn.BackgroundTransparency = 1 StickerBtn.Text = "🙂" StickerBtn.TextSize = 20
local SendBtn = Instance.new("TextButton", ChatInputFrame) SendBtn.Size = UDim2.new(0, 50, 1, 0) SendBtn.Position = UDim2.new(1, -50, 0, 0) SendBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) SendBtn.Text = "Enviar" SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255) SendBtn.Font = Enum.Font.GothamBold SendBtn.TextSize = 12 Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 15)

-- MENU DE FIGURINHAS
local StickerMenu = Instance.new("Frame", PrivateChatMenu) StickerMenu.Size = UDim2.new(1, 0, 0, 200) StickerMenu.Position = UDim2.new(0, 0, 1, 0) StickerMenu.BackgroundColor3 = Color3.fromRGB(20, 20, 25) StickerMenu.ZIndex = 5
local StickerScroll = Instance.new("ScrollingFrame", StickerMenu) StickerScroll.Size = UDim2.new(1, 0, 1, 0) StickerScroll.BackgroundTransparency = 1
local StickerGrid = Instance.new("UIGridLayout", StickerScroll) StickerGrid.CellSize = UDim2.new(0, 60, 0, 60) StickerGrid.CellPadding = UDim2.new(0, 5, 0, 5) StickerGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
local stickerOpen = false
StickerBtn.MouseButton1Click:Connect(function()
    stickerOpen = not stickerOpen
    StickerMenu:TweenPosition(UDim2.new(0, 0, 1, stickerOpen and -250 or 0), "Out", "Quad", 0.2, true)
    if stickerOpen then LoadStickersUI() end
end)

local function FormatTime(ts) local d = os.date("*t", ts) return string.format("%02d:%02d", d.hour, d.min) end

local function RenderMessageItem(msgData)
    local msgFrame = Instance.new("Frame", ChatScroll) msgFrame.BackgroundTransparency = 1 msgFrame.AutomaticSize = Enum.AutomaticSize.Y msgFrame.Size = UDim2.new(1, 0, 0, 0)
    local avatar = Instance.new("ImageLabel", msgFrame) avatar.Size = UDim2.new(0, 32, 0, 32) avatar.Position = UDim2.new(0, 0, 0, 2) avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 45) Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0) pcall(function() avatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(msgData.userId or 1).."&w=150&h=150" end)
    local header = Instance.new("TextLabel", msgFrame) header.Size = UDim2.new(1, -42, 0, 16) header.Position = UDim2.new(0, 40, 0, 0) header.BackgroundTransparency = 1 header.TextXAlignment = Enum.TextXAlignment.Left header.Font = Enum.Font.GothamBold header.TextSize = 12 header.TextColor3 = Color3.fromRGB(255, 255, 255) header.RichText = true header.Text = (msgData.displayName or msgData.sender) .. "  <font color=\"rgb(150,150,150)\">" .. FormatTime(msgData.timestamp) .. "</font>"
    
    local contentFrame = Instance.new("Frame", msgFrame) contentFrame.Position = UDim2.new(0, 40, 0, 18) contentFrame.BackgroundTransparency = 1 contentFrame.AutomaticSize = Enum.AutomaticSize.XY
    
    if msgData.isSticker then
        local img = Instance.new("ImageLabel", contentFrame) img.Size = UDim2.new(0, 100, 0, 100) img.BackgroundTransparency = 1 img.Image = msgData.text
        msgFrame.Size = UDim2.new(1, 0, 0, 120)
    else
        local body = Instance.new("TextLabel", contentFrame) body.Size = UDim2.new(0, 200, 0, 0) body.BackgroundTransparency = 1 body.TextXAlignment = Enum.TextXAlignment.Left body.TextYAlignment = Enum.TextYAlignment.Top body.Font = Enum.Font.Gotham body.TextSize = 12 body.TextColor3 = Color3.fromRGB(220, 220, 220) body.TextWrapped = true body.AutomaticSize = Enum.AutomaticSize.Y
        body.Text = msgData.text .. (msgData.isEdited and " <font color=\"rgb(120,120,120)\"><i>(editado)</i></font>" or "") body.RichText = true
    end

    -- Opções de Apagar/Editar (Apenas se for o enviador)
    if msgData.sender == player.Name then
        local hitBox = Instance.new("TextButton", msgFrame) hitBox.Size = UDim2.new(1, 0, 1, 0) hitBox.BackgroundTransparency = 1 hitBox.Text = ""
        hitBox.MouseButton1Click:Connect(function()
            if msgData.isSticker then
                ShowPopup("Apagar figurinha?", false, "", "Apagar", "Cancelar", function(conf)
                    if conf then SendAction("delete", msgData.id) msgFrame:Destroy() RemoveMessage(msgData.id) end
                end)
            else
                ShowPopup("Opções da Mensagem", false, "", "Editar", "Apagar", function(isEdit)
                    if isEdit then
                        ShowPopup("Editar Mensagem", true, msgData.text, "Salvar", "Cancelar", function(conf, newText)
                            if conf and newText ~= "" then SendAction("edit", msgData.id, newText) EditMessage(msgData.id, newText) RefreshChatUI(LoadChat(ActiveChatTarget)) end
                        end)
                    else
                        SendAction("delete", msgData.id) msgFrame:Destroy() RemoveMessage(msgData.id)
                    end
                end)
            end
        end)
    end
end

function RemoveMessage(id)
    local hist = LoadChat(ActiveChatTarget)
    for i, m in ipairs(hist) do if m.id == id then table.remove(hist, i) break end end
    SaveChat(ActiveChatTarget, hist)
end
function EditMessage(id, newText)
    local hist = LoadChat(ActiveChatTarget)
    for i, m in ipairs(hist) do if m.id == id then m.text = newText m.isEdited = true break end end
    SaveChat(ActiveChatTarget, hist)
end

function SendAction(actionType, msgId, newText)
    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_message", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget, msg = {isAction = true, action = actionType, id = msgId, text = newText}})}) end)
end

function RefreshChatUI(history)
    for _, child in pairs(ChatScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _, msg in ipairs(history) do RenderMessageItem(msg) end
    task.wait(0.1) ChatScroll.CanvasPosition = Vector2.new(0, 99999)
end

function OpenPrivateChat(username, displayName, userId)
    ActiveChatTarget = username ActiveChatTargetDisplay = displayName or username ActiveChatTargetId = userId or 1 ChatTitle.Text = ActiveChatTargetDisplay
    OpenMenu(PrivateChatMenu) RefreshChatUI(LoadChat(username))
    stickerOpen = false StickerMenu.Position = UDim2.new(0, 0, 1, 0)
end

local function SendMsg(text, isSticker)
    if ActiveChatTarget == "" then return end
    local msgData = {id = GenerateMsgId(), sender = player.Name, displayName = player.DisplayName, userId = player.UserId, text = text, timestamp = os.time(), isSticker = isSticker, isEdited = false}
    local history = LoadChat(ActiveChatTarget) table.insert(history, msgData) SaveChat(ActiveChatTarget, history)
    RenderMessageItem(msgData) task.wait(0.1) ChatScroll.CanvasPosition = Vector2.new(0, 99999)
    pcall(function() HttpService:RequestAsync({Url = SERVER_URL .. "/send_message", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({from = player.Name, to = ActiveChatTarget, msg = msgData})}) end)
end

SendBtn.MouseButton1Click:Connect(function() if ChatBox.Text ~= "" then SendMsg(ChatBox.Text, false) ChatBox.Text = "" end end)
ChatBox.FocusLost:Connect(function(e) if e and ChatBox.Text ~= "" then SendMsg(ChatBox.Text, false) ChatBox.Text = "" end end)

function LoadStickersUI()
    for _, child in pairs(StickerScroll:GetChildren()) do if child:IsA("ImageButton") then child:Destroy() end end
    -- Combina recentes (sem duplicatas) e o banco padrão
    local allStickers = {}
    for _, s in ipairs(LocalData.RecentStickers) do table.insert(allStickers, s) end
    for _, s in ipairs(StickerBank) do if not table.find(allStickers, s) then table.insert(allStickers, s) end end

    for _, sId in ipairs(allStickers) do
        local sBtn = Instance.new("ImageButton", StickerScroll) sBtn.BackgroundTransparency = 1 sBtn.Image = sId
        sBtn.MouseButton1Click:Connect(function()
            SendMsg(sId, true)
            stickerOpen = false StickerMenu:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.2, true)
            if not table.find(LocalData.RecentStickers, sId) then table.insert(LocalData.RecentStickers, 1, sId) if #LocalData.RecentStickers > 10 then table.remove(LocalData.RecentStickers, 11) end SaveStickers() end
        end)
    end
    StickerScroll.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#allStickers / 4) * 70)
end

-- ==========================================
-- LOOP DE RECEBIMENTO DE MENSAGENS E AÇÕES
-- ==========================================
task.spawn(function()
    while task.wait(3) do
        if ActiveChatTarget ~= "" then
            pcall(function()
                local res = HttpService:RequestAsync({Url = SERVER_URL .. "/get_messages?from=" .. ActiveChatTarget .. "&to=" .. player.Name, Method = "GET"})
                if res.Success then
                    local newMsgs = HttpService:JSONDecode(res.Body)
                    if newMsgs and #newMsgs > 0 then
                        local history = LoadChat(ActiveChatTarget)
                        local needsRefresh = false
                        for _, m in ipairs(newMsgs) do
                            if m.isAction then
                                if m.action == "delete" then
                                    for i, h in ipairs(history) do if h.id == m.id then table.remove(history, i) needsRefresh = true break end end
                                elseif m.action == "edit" then
                                    for i, h in ipairs(history) do if h.id == m.id then h.text = m.text h.isEdited = true needsRefresh = true break end end
                                end
                            else
                                table.insert(history, m) needsRefresh = true
                            end
                        end
                        SaveChat(ActiveChatTarget, history)
                        if needsRefresh then RefreshChatUI(history) end
                    end
                end
            end)
        end
    end
end)
