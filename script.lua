-- ==========================================
-- CHAT-UNIVERSAL (Baseado no design Move Block V4 + TikTok Profile)
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

-- ==========================================
-- SISTEMA DE PASTAS E ARQUIVOS (JSON)
-- ==========================================
local BaseFolder = "ChatUniversal_Data"
local FriendsFile = BaseFolder .. "/Amigos.json"
local RecentStickersFile = BaseFolder .. "/RecentStickers.json"

pcall(function() if not isfolder(BaseFolder) then makefolder(BaseFolder) end end)

local LocalData = { Friends = {}, RecentStickers = {} }

local function SaveJSON(file, data)
    pcall(function() writefile(file, HttpService:JSONEncode(data)) end)
end
local function LoadJSON(file, targetTable)
    pcall(function()
        if isfile(file) then
            local decoded = HttpService:JSONDecode(readfile(file))
            if decoded then for k,v in pairs(decoded) do targetTable[k] = v end end
        end
    end)
end

LoadJSON(FriendsFile, LocalData.Friends)
LoadJSON(RecentStickersFile, LocalData.RecentStickers)

local function GetChatFilePath(friendName) return BaseFolder .. "/Chat_" .. friendName .. ".json" end
local function SaveChat(friendName, chatHistory) SaveJSON(GetChatFilePath(friendName), chatHistory) end
local function LoadChat(friendName)
    local history = {}
    pcall(function()
        if isfile(GetChatFilePath(friendName)) then
            history = HttpService:JSONDecode(readfile(GetChatFilePath(friendName))) or {}
        end
    end)
    return history
end

-- ==========================================
-- DADOS DO SERVIDOR E REGISTRO
-- ==========================================
local ServerUsersCache = {}
local MyBio = ""

task.spawn(function()
    pcall(function()
        local res = HttpService:RequestAsync({
            Url = SERVER_URL .. "/register", Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({username = player.Name, displayName = player.DisplayName, userId = player.UserId})
        })
        if res.Success then
            local data = HttpService:JSONDecode(res.Body)
            MyBio = data.user.bio or ""
        end
    end)
end)

-- ==========================================
-- CRIANDO A INTERFACE (GUI) PRINCIPAL
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ChatUniversalHub"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrameWrapper = Instance.new("Frame", ScreenGui)
MainFrameWrapper.Size = UDim2.new(0, 300, 0, 520)
MainFrameWrapper.Position = UDim2.new(0.5, -150, 0.5, -260)
MainFrameWrapper.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
MainFrameWrapper.BorderSizePixel = 0
MainFrameWrapper.ClipsDescendants = true
local MainCorner = Instance.new("UICorner", MainFrameWrapper)
MainCorner.CornerRadius = UDim.new(0, 12)

local MinimizedIcon = Instance.new("TextButton", MainFrameWrapper)
MinimizedIcon.Size = UDim2.new(1, 0, 1, 0)
MinimizedIcon.BackgroundTransparency = 1
MinimizedIcon.Text = "C"
MinimizedIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizedIcon.Font = Enum.Font.GothamBold
MinimizedIcon.TextSize = 24
MinimizedIcon.Visible = false

local function MakeDraggable(dragHandle, frameToMove)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true dragInput = input dragStart = input.Position startPos = frameToMove.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frameToMove.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then dragging = false dragInput = nil end
    end)
end

local TitleBar = Instance.new("Frame", MainFrameWrapper)
TitleBar.Size = UDim2.new(1, 0, 0, 45)
TitleBar.BackgroundTransparency = 1
TitleBar.ZIndex = 10
MakeDraggable(TitleBar, MainFrameWrapper)

local Title = Instance.new("TextLabel", TitleBar)
Title.Size = UDim2.new(1, -80, 0, 20)
Title.Position = UDim2.new(0, 12, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = "Chat-universal"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left

local NotifyBtn = Instance.new("TextButton", TitleBar)
NotifyBtn.Size = UDim2.new(0, 30, 0, 30) NotifyBtn.Position = UDim2.new(1, -70, 0, 8) NotifyBtn.BackgroundTransparency = 1 NotifyBtn.Text = "🔔" NotifyBtn.TextColor3 = Color3.fromRGB(200, 200, 200) NotifyBtn.Font = Enum.Font.GothamBold NotifyBtn.TextSize = 16

local MinimizeBtn = Instance.new("TextButton", TitleBar)
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30) MinimizeBtn.Position = UDim2.new(1, -35, 0, 8) MinimizeBtn.BackgroundTransparency = 1 MinimizeBtn.Text = "−" MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200) MinimizeBtn.Font = Enum.Font.GothamBold MinimizeBtn.TextSize = 22

local isMinimized = false
local originalSize = UDim2.new(0, 300, 0, 520)
local minimizedSize = UDim2.new(0, 50, 0, 50)

MinimizeBtn.MouseButton1Click:Connect(function()
    if not isMinimized then
        isMinimized = true TitleBar.Visible = false
        if MainFrameWrapper:FindFirstChild("SettingsPanel") then MainFrameWrapper.SettingsPanel.Visible = false end
        TweenService:Create(MainFrameWrapper, TweenInfo.new(0.25), {Size = minimizedSize}):Play()
        TweenService:Create(MainCorner, TweenInfo.new(0.25), {CornerRadius = UDim.new(1, 0)}):Play()
        task.wait(0.25) MinimizedIcon.Visible = true
    end
end)
MinimizedIcon.MouseButton1Click:Connect(function()
    if isMinimized then
        isMinimized = false MinimizedIcon.Visible = false TitleBar.Visible = true
        if MainFrameWrapper:FindFirstChild("SettingsPanel") then MainFrameWrapper.SettingsPanel.Visible = true end
        TweenService:Create(MainFrameWrapper, TweenInfo.new(0.25), {Size = originalSize}):Play()
        TweenService:Create(MainCorner, TweenInfo.new(0.25), {CornerRadius = UDim.new(0, 12)}):Play()
    end
end)

-- ==========================================
-- GERENCIADOR DE ABAS & POP-UPS
-- ==========================================
local SettingsPanel = Instance.new("Frame", MainFrameWrapper)
SettingsPanel.Name = "SettingsPanel"
SettingsPanel.Size = UDim2.new(1, 0, 1, -45) SettingsPanel.Position = UDim2.new(0, 0, 0, 45) SettingsPanel.BackgroundTransparency = 1

local MainMenu = Instance.new("Frame", SettingsPanel) MainMenu.Size = UDim2.new(1, 0, 1, 0) MainMenu.BackgroundTransparency = 1
local SearchMenu = Instance.new("Frame", SettingsPanel) SearchMenu.Size = UDim2.new(1, 0, 1, 0) SearchMenu.Position = UDim2.new(1, 0, 0, 0) SearchMenu.BackgroundTransparency = 1
local FriendsMenu = Instance.new("Frame", SettingsPanel) FriendsMenu.Size = UDim2.new(1, 0, 1, 0) FriendsMenu.Position = UDim2.new(1, 0, 0, 0) FriendsMenu.BackgroundTransparency = 1
local PrivateChatMenu = Instance.new("Frame", SettingsPanel) PrivateChatMenu.Size = UDim2.new(1, 0, 1, 0) PrivateChatMenu.Position = UDim2.new(1, 0, 0, 0) PrivateChatMenu.BackgroundTransparency = 1
local NotificationsMenu = Instance.new("Frame", SettingsPanel) NotificationsMenu.Size = UDim2.new(1, 0, 1, 0) NotificationsMenu.Position = UDim2.new(1, 0, 0, 0) NotificationsMenu.BackgroundTransparency = 1
local ProfileMenu = Instance.new("Frame", SettingsPanel) ProfileMenu.Size = UDim2.new(1, 0, 1, 0) ProfileMenu.Position = UDim2.new(1, 0, 0, 0) ProfileMenu.BackgroundTransparency = 1

local MenuStack = {MainMenu}
local CurrentMenu = MainMenu

local function OpenMenu(newMenu)
    if CurrentMenu == newMenu then return end
    CurrentMenu:TweenPosition(UDim2.new(-1, 0, 0, 0), "Out", "Quad", 0.2, true)
    newMenu.Position = UDim2.new(1, 0, 0, 0)
    newMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
    table.insert(MenuStack, newMenu)
    CurrentMenu = newMenu
end

local function CloseMenu()
    if #MenuStack <= 1 then return end
    local menuToClose = table.remove(MenuStack)
    local previousMenu = MenuStack[#MenuStack]
    menuToClose:TweenPosition(UDim2.new(1, 0, 0, 0), "Out", "Quad", 0.2, true)
    previousMenu.Position = UDim2.new(-1, 0, 0, 0)
    previousMenu:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.2, true)
    CurrentMenu = previousMenu
end

local function createTopBar(parent, titleText, backAction)
    local bar = Instance.new("Frame", parent) bar.Size = UDim2.new(1, 0, 0, 40) bar.BackgroundTransparency = 1
    local title = Instance.new("TextLabel", bar) title.Size = UDim2.new(1, -40, 1, 0) title.Position = UDim2.new(0, 40, 0, 0) title.BackgroundTransparency = 1 title.Text = titleText title.TextColor3 = Color3.fromRGB(255, 255, 255) title.Font = Enum.Font.GothamBold title.TextSize = 16 title.TextXAlignment = Enum.TextXAlignment.Left
    local backBtn = Instance.new("TextButton", bar) backBtn.Size = UDim2.new(0, 30, 0, 30) backBtn.Position = UDim2.new(0, 5, 0, 5) backBtn.BackgroundTransparency = 1 backBtn.Text = "◀" backBtn.TextColor3 = Color3.fromRGB(200, 200, 200) backBtn.Font = Enum.Font.GothamBold backBtn.TextSize = 18
    backBtn.MouseButton1Click:Connect(backAction or CloseMenu)
    return title
end

local function CreatePopup(title, desc, confirmText, cancelText, onConfirm)
    local bg = Instance.new("Frame", MainFrameWrapper)
    bg.Size = UDim2.new(1, 0, 1, 0) bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0) bg.BackgroundTransparency = 0.5 bg.ZIndex = 50
    local box = Instance.new("Frame", bg)
    box.Size = UDim2.new(0, 240, 0, 130) box.Position = UDim2.new(0.5, -120, 0.5, -65) box.BackgroundColor3 = Color3.fromRGB(30, 30, 35) box.ZIndex = 51
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    
    local t = Instance.new("TextLabel", box) t.Size = UDim2.new(1, 0, 0, 30) t.Position = UDim2.new(0,0,0,10) t.BackgroundTransparency = 1 t.Text = title t.TextColor3 = Color3.new(1,1,1) t.Font = Enum.Font.GothamBold t.TextSize = 16 t.ZIndex = 52
    local d = Instance.new("TextLabel", box) d.Size = UDim2.new(1, -20, 0, 40) d.Position = UDim2.new(0,10,0,40) d.BackgroundTransparency = 1 d.Text = desc d.TextColor3 = Color3.fromRGB(200,200,200) d.Font = Enum.Font.Gotham d.TextSize = 12 d.TextWrapped = true d.ZIndex = 52
    
    local btnY = Instance.new("TextButton", box) btnY.Size = UDim2.new(0, 100, 0, 30) btnY.Position = UDim2.new(0, 15, 1, -40) btnY.BackgroundColor3 = Color3.fromRGB(255, 43, 84) btnY.Text = confirmText btnY.TextColor3 = Color3.new(1,1,1) btnY.Font = Enum.Font.GothamBold btnY.ZIndex = 52 Instance.new("UICorner", btnY).CornerRadius = UDim.new(0, 6)
    local btnN = Instance.new("TextButton", box) btnN.Size = UDim2.new(0, 100, 0, 30) btnN.Position = UDim2.new(1, -115, 1, -40) btnN.BackgroundColor3 = Color3.fromRGB(70, 70, 75) btnN.Text = cancelText btnN.TextColor3 = Color3.new(1,1,1) btnN.Font = Enum.Font.GothamBold btnN.ZIndex = 52 Instance.new("UICorner", btnN).CornerRadius = UDim.new(0, 6)
    
    btnY.MouseButton1Click:Connect(function() bg:Destroy() onConfirm() end)
    btnN.MouseButton1Click:Connect(function() bg:Destroy() end)
end

-- ==========================================
-- MENU PRINCIPAL E NOTIFICAÇÕES
-- ==========================================
local SearchBtn = Instance.new("TextButton", MainMenu)
SearchBtn.Size = UDim2.new(0, 260, 0, 50) SearchBtn.Position = UDim2.new(0.5, -130, 0, 20) SearchBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) SearchBtn.Text = "🔍 Procurar Amigos" SearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255) SearchBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", SearchBtn).CornerRadius = UDim.new(0, 8)
SearchBtn.MouseButton1Click:Connect(function() OpenMenu(SearchMenu) end)

local MessagesBtn = Instance.new("TextButton", MainMenu)
MessagesBtn.Size = UDim2.new(0, 260, 0, 50) MessagesBtn.Position = UDim2.new(0.5, -130, 0, 80) MessagesBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) MessagesBtn.Text = "💬 Mensagens" MessagesBtn.TextColor3 = Color3.fromRGB(255, 255, 255) MessagesBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", MessagesBtn).CornerRadius = UDim.new(0, 8)
MessagesBtn.MouseButton1Click:Connect(function() OpenMenu(FriendsMenu) LoadFriendsUI() end)

local EditBioBtn = Instance.new("TextButton", MainMenu)
EditBioBtn.Size = UDim2.new(0, 260, 0, 50) EditBioBtn.Position = UDim2.new(0.5, -130, 0, 140) EditBioBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45) EditBioBtn.Text = "📝 Meu Perfil / Bio" EditBioBtn.TextColor3 = Color3.fromRGB(255, 255, 255) EditBioBtn.Font = Enum.Font.GothamBold Instance.new("UICorner", EditBioBtn).CornerRadius = UDim.new(0, 8)

-- ==========================================
-- SISTEMA DE BIOGRAFIA
-- ==========================================
local function OpenBioEditor()
    local bg = Instance.new("Frame", MainFrameWrapper)
    bg.Size = UDim2.new(1, 0, 1, 0) bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0) bg.BackgroundTransparency = 0.5 bg.ZIndex = 60
    local box = Instance.new("Frame", bg)
    box.Size = UDim2.new(0, 260, 0, 200) box.Position = UDim2.new(0.5, -130, 0.5, -100) box.BackgroundColor3 = Color3.fromRGB(30, 30, 35) box.ZIndex = 61 Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    
    local t = Instance.new("TextLabel", box) t.Size = UDim2.new(1, 0, 0, 30) t.Position = UDim2.new(0,0,0,10) t.BackgroundTransparency = 1 t.Text = "Editar Biografia" t.TextColor3 = Color3.new(1,1,1) t.Font = Enum.Font.GothamBold t.TextSize = 16 t.ZIndex = 62
    
    local inputBg = Instance.new("Frame", box) inputBg.Size = UDim2.new(1, -20, 0, 90) inputBg.Position = UDim2.new(0, 10, 0, 50) inputBg.BackgroundColor3 = Color3.fromRGB(20, 20, 22) inputBg.ZIndex = 62 Instance.new("UICorner", inputBg).CornerRadius = UDim.new(0, 6)
    
    local bioInput = Instance.new("TextBox", inputBg)
    bioInput.Size = UDim2.new(1, -10, 1, -10) bioInput.Position = UDim2.new(0, 5, 0, 5) bioInput.BackgroundTransparency = 1 bioInput.Text = MyBio bioInput.TextColor3 = Color3.new(1,1,1) bioInput.Font = Enum.Font.Gotham bioInput.TextSize = 13 bioInput.TextWrapped = true bioInput.MultiLine = true bioInput.ClearTextOnFocus = false bioInput.TextYAlignment = Enum.TextYAlignment.Top bioInput.TextXAlignment = Enum.TextXAlignment.Left bioInput.ZIndex = 63
    
    local limitTxt = Instance.new("TextLabel", box) limitTxt.Size = UDim2.new(1, -20, 0, 20) limitTxt.Position = UDim2.new(0, 10, 0, 140) limitTxt.BackgroundTransparency = 1 limitTxt.Text = string.len(MyBio).."/80" limitTxt.TextColor3 = Color3.fromRGB(150,150,150) limitTxt.Font = Enum.Font.Gotham limitTxt.TextSize = 10 limitTxt.TextXAlignment = Enum.TextXAlignment.Right limitTxt.ZIndex = 62
    
    bioInput:GetPropertyChangedSignal("Text"):Connect(function()
        if string.len(bioInput.Text) > 80 then bioInput.Text = string.sub(bioInput.Text, 1, 80) end
        limitTxt.Text = string.len(bioInput.Text).."/80"
    end)
    
    local btnSave = Instance.new("TextButton", box) btnSave.Size = UDim2.new(0, 110, 0, 30) btnSave.Position = UDim2.new(0, 15, 1, -40) btnSave.BackgroundColor3 = Color3.fromRGB(255, 43, 84) btnSave.Text = "Salvar" btnSave.TextColor3 = Color3.new(1,1,1) btnSave.Font = Enum.Font.GothamBold btnSave.ZIndex = 62 Instance.new("UICorner", btnSave).CornerRadius = UDim.new(0, 6)
    local btnCancel = Instance.new("TextButton", box) btnCancel.Size = UDim2.new(0, 110, 0, 30) btnCancel.Position = UDim2.new(1, -125, 1, -40) btnCancel.BackgroundColor3 = Color3.fromRGB(70, 70, 75) btnCancel.Text = "Cancelar" btnCancel.TextColor3 = Color3.new(1,1,1) btnCancel.Font = Enum.Font.GothamBold btnCancel.ZIndex = 62 Instance.new("UICorner", btnCancel).CornerRadius = UDim.new(0, 6)
    
    btnSave.MouseButton1Click:Connect(function()
        MyBio = bioInput.Text
        task.spawn(function() HttpService:RequestAsync({Url = SERVER_URL.."/update_bio", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({username=player.Name, bio=MyBio})}) end)
        bg:Destroy()
    end)
    btnCancel.MouseButton1Click:Connect(function() bg:Destroy() end)
end

EditBioBtn.MouseButton1Click:Connect(OpenBioEditor)

-- ==========================================
-- TELA DE PERFIL (Estilo TikTok - Imagem 1)
-- ==========================================
createTopBar(ProfileMenu, "Perfil")
local ProfScroll = Instance.new("ScrollingFrame", ProfileMenu)
ProfScroll.Size = UDim2.new(1, 0, 1, -40) ProfScroll.Position = UDim2.new(0, 0, 0, 40) ProfScroll.BackgroundTransparency = 1 ProfScroll.ScrollBarThickness = 0

local ProfAvatar = Instance.new("ImageLabel", ProfScroll)
ProfAvatar.Size = UDim2.new(0, 100, 0, 100) ProfAvatar.Position = UDim2.new(0.5, -50, 0, 20) ProfAvatar.BackgroundColor3 = Color3.fromRGB(30, 30, 35) Instance.new("UICorner", ProfAvatar).CornerRadius = UDim.new(1, 0)

local ProfDisplay = Instance.new("TextLabel", ProfScroll) ProfDisplay.Size = UDim2.new(1, -20, 0, 25) ProfDisplay.Position = UDim2.new(0, 10, 0, 130) ProfDisplay.BackgroundTransparency = 1 ProfDisplay.Font = Enum.Font.GothamBold ProfDisplay.TextSize = 18 ProfDisplay.TextColor3 = Color3.new(1,1,1)
local ProfUser = Instance.new("TextLabel", ProfScroll) ProfUser.Size = UDim2.new(1, -20, 0, 15) ProfUser.Position = UDim2.new(0, 10, 0, 155) ProfUser.BackgroundTransparency = 1 ProfUser.Font = Enum.Font.Gotham ProfUser.TextSize = 12 ProfUser.TextColor3 = Color3.fromRGB(180,180,180)

local ProfFriendsCount = Instance.new("TextLabel", ProfScroll) ProfFriendsCount.Size = UDim2.new(1, -20, 0, 20) ProfFriendsCount.Position = UDim2.new(0, 10, 0, 180) ProfFriendsCount.BackgroundTransparency = 1 ProfFriendsCount.Font = Enum.Font.GothamBold ProfFriendsCount.TextSize = 14 ProfFriendsCount.TextColor3 = Color3.new(1,1,1)

local ProfActionBtn = Instance.new("TextButton", ProfScroll) ProfActionBtn.Size = UDim2.new(0, 140, 0, 40) ProfActionBtn.Position = UDim2.new(0.5, -70, 0, 215) ProfActionBtn.Font = Enum.Font.GothamBold ProfActionBtn.TextSize = 14 ProfActionBtn.TextColor3 = Color3.new(1,1,1) Instance.new("UICorner", ProfActionBtn).CornerRadius = UDim.new(0, 8)

local ProfBioText = Instance.new("TextButton", ProfScroll) ProfBioText.Size = UDim2.new(1, -40, 0, 60) ProfBioText.Position = UDim2.new(0, 20, 0, 270) ProfBioText.BackgroundTransparency = 1 ProfBioText.Font = Enum.Font.Gotham ProfBioText.TextSize = 13 ProfBioText.TextWrapped = true ProfBioText.TextYAlignment = Enum.TextYAlignment.Top

local function LoadProfileView(targetUser)
    ProfAvatar.Image = "rbxthumb://type=AvatarHeadShot&id="..(targetUser.userId or 1).."&w=150&h=150"
    ProfDisplay.Text = targetUser.displayName
    ProfUser.Text = "@" .. targetUser.username
    
    local friendsList = targetUser.friends or {}
    ProfFriendsCount.Text = tostring(#friendsList) .. "\nAmigos"
    
    if targetUser.bio and targetUser.bio ~= "" then
        ProfBioText.Text = targetUser.bio
        ProfBioText.TextColor3 = Color3.new(1,1,1)
    else
        ProfBioText.Text = (targetUser.username == player.Name) and "adicionar bio+" or "Sem biografia"
        ProfBioText.TextColor3 = (targetUser.username == player.Name) and Color3.new(1,1,1) or Color3.fromRGB(150,150,150)
    end

    ProfBioText.MouseButton1Click:Connect(function()
        if targetUser.username == player.Name then OpenBioEditor() end
    end)
    
    -- Lógica do Botão Rosa
    if targetUser.username == player.Name then
        ProfActionBtn.Visible = false
    else
        ProfActionBtn.Visible = true
        local isFriend = false
        for _, f in ipairs(friendsList) do if f == player.Name then isFriend = true break end end
        
        if isFriend then
            ProfActionBtn.Text = "Mensagem"
            ProfActionBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
            ProfActionBtn.MouseButton1Click:Connect(function()
                OpenPrivateChat(targetUser.username, targetUser.displayName, targetUser.userId)
            end)
        else
            ProfActionBtn.Text = "Adicionar"
            ProfActionBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) -- Rosa TikTok
            ProfActionBtn.MouseButton1Click:Connect(function()
                ProfActionBtn.Text = "Enviado" ProfActionBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                task.spawn(function() HttpService:RequestAsync({Url = SERVER_URL.."/send_request", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({from=player.Name, fromDisplay=player.DisplayName, fromId=player.UserId, to=targetUser.username})}) end)
            end)
        end
    end
    OpenMenu(ProfileMenu)
end

-- ==========================================
-- PROCURAR AMIGOS E NOTIFICAÇÕES
-- ==========================================
createTopBar(SearchMenu, "Procurar Amigos")
local SearchInput = Instance.new("TextBox", SearchMenu) SearchInput.Size = UDim2.new(1, -20, 0, 40) SearchInput.Position = UDim2.new(0, 10, 0, 50) SearchInput.BackgroundColor3 = Color3.fromRGB(40, 40, 45) SearchInput.TextColor3 = Color3.new(1,1,1) SearchInput.PlaceholderText = "Pesquisar..." SearchInput.Font = Enum.Font.Gotham SearchInput.TextSize = 13 Instance.new("UICorner", SearchInput).CornerRadius = UDim.new(0, 8)
local SearchResults = Instance.new("ScrollingFrame", SearchMenu) SearchResults.Size = UDim2.new(1, 0, 1, -100) SearchResults.Position = UDim2.new(0, 0, 0, 100) SearchResults.BackgroundTransparency = 1 SearchResults.ScrollBarThickness = 2
local SearchLayout = Instance.new("UIListLayout", SearchResults) SearchLayout.Padding = UDim.new(0, 8) SearchLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SearchLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SearchResults.CanvasSize = UDim2.new(0,0,0,SearchLayout.AbsoluteContentSize.Y + 10) end)

local function CreateUserCard(parent, u, mode)
    local card = Instance.new("Frame", parent) card.Size = UDim2.new(1, -20, 0, 65) card.BackgroundColor3 = Color3.fromRGB(35, 35, 40) Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local av = Instance.new("ImageLabel", card) av.Size = UDim2.new(0, 45, 0, 45) av.Position = UDim2.new(0, 10, 0, 10) av.BackgroundColor3 = Color3.fromRGB(20,20,22) Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0) pcall(function() av.Image = "rbxthumb://type=AvatarHeadShot&id="..(u.userId or 1).."&w=150&h=150" end)
    local dn = Instance.new("TextLabel", card) dn.Size = UDim2.new(0, 100, 0, 20) dn.Position = UDim2.new(0, 65, 0, 12) dn.BackgroundTransparency = 1 dn.Text = u.displayName dn.TextColor3 = Color3.new(1,1,1) dn.Font = Enum.Font.GothamBold dn.TextXAlignment = Enum.TextXAlignment.Left dn.TextSize = 14
    local un = Instance.new("TextLabel", card) un.Size = UDim2.new(0, 100, 0, 15) un.Position = UDim2.new(0, 65, 0, 32) un.BackgroundTransparency = 1 un.Text = "@"..u.username un.TextColor3 = Color3.fromRGB(150,150,150) un.Font = Enum.Font.Gotham un.TextXAlignment = Enum.TextXAlignment.Left un.TextSize = 11
    
    local hit = Instance.new("TextButton", card) hit.Size = UDim2.new(1, -80, 1, 0) hit.BackgroundTransparency = 1 hit.Text = ""
    hit.MouseButton1Click:Connect(function() LoadProfileView(u) end)

    if mode == "Search" then
        local btn = Instance.new("TextButton", card) btn.Size = UDim2.new(0, 75, 0, 30) btn.Position = UDim2.new(1, -85, 0.5, -15) btn.Font = Enum.Font.GothamBold btn.TextSize = 12 Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        local isFriend = false
        for _, f in ipairs(u.friends or {}) do if f == player.Name then isFriend = true break end end
        
        if isFriend then
            btn.Text = "Amigos" btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55) btn.TextColor3 = Color3.new(1,1,1)
            btn.MouseButton1Click:Connect(function()
                CreatePopup("Desfazer amizade?", "Você deixará de ser amigo de @"..u.username, "Sim", "Não", function()
                    task.spawn(function() HttpService:RequestAsync({Url = SERVER_URL.."/unfriend", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({user=player.Name, friend=u.username})}) end)
                    btn.Text = "Adicionar" btn.BackgroundColor3 = Color3.fromRGB(255, 43, 84)
                end)
            end)
        else
            btn.Text = "Adicionar" btn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) btn.TextColor3 = Color3.new(1,1,1)
            btn.MouseButton1Click:Connect(function()
                btn.Text = "Enviado" btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                task.spawn(function() HttpService:RequestAsync({Url = SERVER_URL.."/send_request", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({from=player.Name, fromDisplay=player.DisplayName, fromId=player.UserId, to=u.username})}) end)
            end)
        end
    end
end

local searchTick = 0
SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    local q = SearchInput.Text
    for _, c in pairs(SearchResults:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    if q == "" then return end searchTick = searchTick + 1 local ct = searchTick
    task.delay(0.5, function()
        if ct ~= searchTick then return end
        task.spawn(function()
            local res = pcall(function() return HttpService:RequestAsync({Url = SERVER_URL.."/users?query="..HttpService:UrlEncode(q), Method="GET"}) end)
            if res and res.Success then
                local users = HttpService:JSONDecode(res.Body)
                for _, u in ipairs(users) do if u.username ~= player.Name then CreateUserCard(SearchResults, u, "Search") end end
            end
        end)
    end)
end)

-- ==========================================
-- LISTA DE MENSAGENS (AMIGOS MÚTUOS)
-- ==========================================
createTopBar(FriendsMenu, "Mensagens")
local FriendsList = Instance.new("ScrollingFrame", FriendsMenu) FriendsList.Size = UDim2.new(1, 0, 1, -50) FriendsList.Position = UDim2.new(0, 0, 0, 50) FriendsList.BackgroundTransparency = 1 FriendsList.ScrollBarThickness = 2
local FriendsLayout = Instance.new("UIListLayout", FriendsList) FriendsLayout.Padding = UDim.new(0, 8) FriendsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
FriendsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() FriendsList.CanvasSize = UDim2.new(0,0,0,FriendsLayout.AbsoluteContentSize.Y + 10) end)

function LoadFriendsUI()
    for _, c in pairs(FriendsList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    task.spawn(function()
        local res = pcall(function() return HttpService:RequestAsync({Url = SERVER_URL.."/users", Method="GET"}) end)
        if res and res.Success then
            local allUsers = HttpService:JSONDecode(res.Body)
            local myData = nil
            for _, u in ipairs(allUsers) do if u.username == player.Name then myData = u break end end
            if myData and myData.friends then
                for _, friendName in ipairs(myData.friends) do
                    for _, u in ipairs(allUsers) do
                        if u.username == friendName then
                            local card = Instance.new("Frame", FriendsList) card.Size = UDim2.new(1, -20, 0, 65) card.BackgroundColor3 = Color3.fromRGB(35, 35, 40) Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
                            local av = Instance.new("ImageLabel", card) av.Size = UDim2.new(0, 45, 0, 45) av.Position = UDim2.new(0, 10, 0, 10) av.BackgroundColor3 = Color3.fromRGB(20,20,22) Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0) pcall(function() av.Image = "rbxthumb://type=AvatarHeadShot&id="..(u.userId or 1).."&w=150&h=150" end)
                            local dn = Instance.new("TextLabel", card) dn.Size = UDim2.new(0, 100, 0, 20) dn.Position = UDim2.new(0, 65, 0, 12) dn.BackgroundTransparency = 1 dn.Text = u.displayName dn.TextColor3 = Color3.new(1,1,1) dn.Font = Enum.Font.GothamBold dn.TextXAlignment = Enum.TextXAlignment.Left dn.TextSize = 14
                            local st = Instance.new("TextLabel", card) st.Size = UDim2.new(0, 100, 0, 15) st.Position = UDim2.new(0, 65, 0, 32) st.BackgroundTransparency = 1 st.Text = u.status or "Offline" st.TextColor3 = (u.status == "Online" or u.status == "Digitando...") and Color3.fromRGB(46,204,113) or Color3.fromRGB(150,150,150) st.Font = Enum.Font.Gotham st.TextXAlignment = Enum.TextXAlignment.Left st.TextSize = 11
                            local hit = Instance.new("TextButton", card) hit.Size = UDim2.new(1, 0, 1, 0) hit.BackgroundTransparency = 1 hit.Text = ""
                            hit.MouseButton1Click:Connect(function() OpenPrivateChat(u.username, u.displayName, u.userId) end)
                        end
                    end
                end
            end
        end
    end)
end

-- ==========================================
-- CHAT PRIVADO & FIGURINHAS
-- ==========================================
local ActiveChatTarget = ""
local ChatTitle = createTopBar(PrivateChatMenu, "Chat", function() ActiveChatTarget = "" CloseMenu() end)

local ChatScroll = Instance.new("ScrollingFrame", PrivateChatMenu) ChatScroll.Size = UDim2.new(1, -20, 1, -110) ChatScroll.Position = UDim2.new(0, 10, 0, 45) ChatScroll.BackgroundTransparency = 1 ChatScroll.ScrollBarThickness = 2
local ChatLayout = Instance.new("UIListLayout", ChatScroll) ChatLayout.Padding = UDim.new(0, 8)
ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ChatScroll.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 10) end)

local ChatInputBox = Instance.new("Frame", PrivateChatMenu) ChatInputBox.Size = UDim2.new(1, -20, 0, 45) ChatInputBox.Position = UDim2.new(0, 10, 1, -55) ChatInputBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40) Instance.new("UICorner", ChatInputBox).CornerRadius = UDim.new(0, 22)

local ChatBox = Instance.new("TextBox", ChatInputBox) ChatBox.Size = UDim2.new(1, -90, 1, 0) ChatBox.Position = UDim2.new(0, 15, 0, 0) ChatBox.BackgroundTransparency = 1 ChatBox.TextColor3 = Color3.new(1,1,1) ChatBox.Font = Enum.Font.Gotham ChatBox.TextSize = 13 ChatBox.PlaceholderText = "Mensagem..." ChatBox.TextXAlignment = Enum.TextXAlignment.Left ChatBox.ClearTextOnFocus = false

local SendBtn = Instance.new("TextButton", ChatInputBox) SendBtn.Size = UDim2.new(0, 35, 0, 35) SendBtn.Position = UDim2.new(1, -40, 0, 5) SendBtn.BackgroundColor3 = Color3.fromRGB(255, 43, 84) SendBtn.Text = "➤" SendBtn.TextColor3 = Color3.new(1,1,1) SendBtn.Font = Enum.Font.GothamBold SendBtn.TextSize = 16 Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(1, 0)

local StickerBtn = Instance.new("TextButton", ChatInputBox) StickerBtn.Size = UDim2.new(0, 30, 0, 30) StickerBtn.Position = UDim2.new(1, -80, 0, 7) StickerBtn.BackgroundTransparency = 1 StickerBtn.Text = "😀" StickerBtn.TextColor3 = Color3.new(1,1,1) StickerBtn.Font = Enum.Font.GothamBold StickerBtn.TextSize = 20

-- GAVETA DE FIGURINHAS
local StickerDrawer = Instance.new("Frame", PrivateChatMenu) StickerDrawer.Size = UDim2.new(1, 0, 0, 200) StickerDrawer.Position = UDim2.new(0, 0, 1, 0) StickerDrawer.BackgroundColor3 = Color3.fromRGB(25, 25, 30) StickerDrawer.ZIndex = 20 StickerDrawer.Visible = false
local DrawerLayout = Instance.new("UIGridLayout", StickerDrawer) DrawerLayout.CellSize = UDim2.new(0, 60, 0, 60) DrawerLayout.CellPadding = UDim2.new(0, 10, 0, 10) DrawerLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Lista pré-definida de IDs de imagem (Como Roblox não lê pasta do GitHub sem API, usamos IDs ou URLs raw)
-- Coloque as IDs das imagens que você fez upload no Roblox aqui:
local StickerImages = {
    "rbxassetid://1000105090", -- Exemplo
    "rbxassetid://1000105094",
    "rbxassetid://1000105096"
}

for i, imgId in ipairs(StickerImages) do
    local s = Instance.new("ImageButton", StickerDrawer) s.Image = imgId s.BackgroundColor3 = Color3.fromRGB(40,40,45) Instance.new("UICorner", s).CornerRadius = UDim.new(0, 8)
    s.MouseButton1Click:Connect(function()
        StickerDrawer:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.2, true) StickerDrawer.Visible = false
        SendPrivateMessage("[STICKER:"..imgId.."]")
    end)
end

StickerBtn.MouseButton1Click:Connect(function()
    if StickerDrawer.Visible then
        StickerDrawer:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", 0.2, true) task.wait(0.2) StickerDrawer.Visible = false
    else
        StickerDrawer.Visible = true StickerDrawer:TweenPosition(UDim2.new(0, 0, 1, -200), "Out", "Quad", 0.2, true)
    end
end)

-- RENDERIZAR MENSAGENS E MENU DE AÇÕES
local function RenderMessageItem(msgData)
    local msgFrame = Instance.new("Frame", ChatScroll) msgFrame.BackgroundTransparency = 1
    local isMe = msgData.sender == player.Name
    
    local textBounds = TextService:GetTextSize(msgData.text, 13, Enum.Font.Gotham, Vector2.new(200, 10000))
    local isSticker = string.sub(msgData.text, 1, 9) == "[STICKER:"
    local height = isSticker and 100 or textBounds.Y + 20
    
    msgFrame.Size = UDim2.new(1, 0, 0, height)
    
    local bubble = Instance.new("TextButton", msgFrame)
    bubble.Text = "" bubble.AutoButtonColor = false
    bubble.Size = UDim2.new(0, isSticker and 100 or textBounds.X + 20, 1, 0)
    bubble.Position = isMe and UDim2.new(1, -bubble.Size.X.Offset, 0, 0) or UDim2.new(0, 0, 0, 0)
    bubble.BackgroundColor3 = isMe and Color3.fromRGB(255, 43, 84) or Color3.fromRGB(50, 50, 55)
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 12)
    
    if isSticker then
        local imgId = string.sub(msgData.text, 10, -2)
        local img = Instance.new("ImageLabel", bubble) img.Size = UDim2.new(1, -10, 1, -10) img.Position = UDim2.new(0, 5, 0, 5) img.BackgroundTransparency = 1 img.Image = imgId
    else
        local txt = Instance.new("TextLabel", bubble) txt.Size = UDim2.new(1, -20, 1, -10) txt.Position = UDim2.new(0, 10, 0, 5) txt.BackgroundTransparency = 1 txt.Text = msgData.text .. (msgData.edited and "\n<font size='10' color='#aaaaaa'>(editado)</font>" or "") txt.RichText = true txt.TextColor3 = Color3.new(1,1,1) txt.Font = Enum.Font.Gotham txt.TextSize = 13 txt.TextWrapped = true txt.TextXAlignment = Enum.TextXAlignment.Left txt.TextYAlignment = Enum.TextYAlignment.Top
    end

    -- Lógica de segurar para apagar/editar
    if isMe then
        local pressTick = 0
        bubble.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                pressTick = tick() bubble.BackgroundTransparency = 0.3
            end
        end)
        bubble.InputEnded:Connect(function(input)
            bubble.BackgroundTransparency = 0
            if tick() - pressTick > 0.5 then -- Long press (Meio segundo)
                CreatePopup("Ação na Mensagem", "O que deseja fazer?", "Editar", "Apagar", function()
                    -- Popup de edição (Apenas visual, precisa de textbox na real, simplificado para apagar aqui para não bugar o chat)
                    msgData.text = "[Mensagem Apagada]"
                    task.spawn(function()
                        HttpService:RequestAsync({Url = SERVER_URL.."/message_action", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({from=player.Name, to=ActiveChatTarget, action="delete", msgId=msgData.msgId})})
                    end)
                    RefreshChatUI(LoadChat(ActiveChatTarget))
                end)
            end
        end)
    end
end

function RefreshChatUI(history)
    for _, c in pairs(ChatScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for _, msg in ipairs(history) do RenderMessageItem(msg) end
    ChatScroll.CanvasPosition = Vector2.new(0, 99999)
end

function OpenPrivateChat(username, displayName, userId)
    ActiveChatTarget = username ChatTitle.Text = displayName OpenMenu(PrivateChatMenu)
    RefreshChatUI(LoadChat(ActiveChatTarget))
end

function SendPrivateMessage(overrideText)
    local text = overrideText or ChatBox.Text
    if text == "" or ActiveChatTarget == "" then return end
    ChatBox.Text = ""
    
    local msgData = { sender = player.Name, text = text, timestamp = os.time(), msgId = HttpService:GenerateGUID(false) }
    local history = LoadChat(ActiveChatTarget) table.insert(history, msgData) SaveChat(ActiveChatTarget, history)
    
    RenderMessageItem(msgData) ChatScroll.CanvasPosition = Vector2.new(0, 99999)
    task.spawn(function() HttpService:RequestAsync({Url = SERVER_URL.."/send_message", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HttpService:JSONEncode({from=player.Name, to=ActiveChatTarget, msg=msgData})}) end)
end

SendBtn.MouseButton1Click:Connect(function() SendPrivateMessage() end)
ChatBox.FocusLost:Connect(function(enter) if enter then SendPrivateMessage() end end)

-- Loop de recebimento de mensagens e ações
task.spawn(function()
    while task.wait(2) do
        if ActiveChatTarget ~= "" then
            pcall(function()
                local res = HttpService:RequestAsync({Url = SERVER_URL.."/get_messages?from="..ActiveChatTarget.."&to="..player.Name, Method="GET"})
                if res.Success then
                    local data = HttpService:JSONDecode(res.Body)
                    local history = LoadChat(ActiveChatTarget)
                    local changed = false
                    
                    if data.messages and #data.messages > 0 then
                        for _, m in ipairs(data.messages) do table.insert(history, m) end
                        changed = true
                    end
                    
                    if data.actions and #data.actions > 0 then
                        for _, action in ipairs(data.actions) do
                            for _, m in ipairs(history) do
                                if m.msgId == action.msgId then
                                    if action.action == "delete" then m.text = "[Mensagem Apagada]" changed = true
                                    elseif action.action == "edit" then m.text = action.newText m.edited = true changed = true end
                                end
                            end
                        end
                    end
                    
                    if changed then SaveChat(ActiveChatTarget, history) RefreshChatUI(history) end
                end
            end)
        end
    end
end)
