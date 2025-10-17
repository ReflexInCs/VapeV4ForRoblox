local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return areadfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/ReflexInCs/VapeV4ForRoblox/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('newvape/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		local plrstr = self.hashes[plr.Name..plr.UserId]
		for _, v in self.data.WhitelistedUsers do
			if v.hash == plrstr then
				return v.level, v.attackable or whitelist.localprio >= v.level, v.tags
			end
		end
		return 0, true
	end

	function whitelist:isingame()
		for _, v in playersService:GetPlayers() do
			if self:get(v) ~= 0 then return true end
		end
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = select(3, self:get(plr)) or self.customtags[plr.Name] or {}, ''
		if not text then return plrtag end
		for _, v in plrtag do
			newtag = newtag..(rich and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end
		return newtag
	end

	function whitelist:getplayer(arg)
		if arg == 'default' and self.localprio == 0 then return true end
		if arg == 'private' and self.localprio == 1 then return true end
		if arg and lplr.Name:lower():sub(1, arg:len()) == arg:lower() then return true end
		return false
	end

	local olduninject
	function whitelist:playeradded(v, joined)
		if self:get(v) ~= 0 then
			if self.alreadychecked[v.UserId] then return end
			self.alreadychecked[v.UserId] = true
			self:hook()
			if self.localprio == 0 then
				olduninject = vape.Uninject
				vape.Uninject = function()
					notif('Vape', 'No escaping the private members :)', 10)
				end
				if joined then
					task.wait(10)
				end
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					local oldchannel = textChatService.ChatInputBarConfiguration.TargetTextChannel
					local newchannel = cloneref(game:GetService('RobloxReplicatedStorage')).ExperienceChat.WhisperChat:InvokeServer(v.UserId)
					if newchannel then
						newchannel:SendAsync('helloimusinginhaler')
					end
					textChatService.ChatInputBarConfiguration.TargetTextChannel = oldchannel
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('/w '..v.Name..' helloimusinginhaler', 'All')
				end
			end
		end
	end

	function whitelist:process(msg, plr)
		if plr == lplr and msg == 'helloimusinginhaler' then return true end

		if self.localprio > 0 and not self.said[plr.Name] and msg == 'helloimusinginhaler' and plr ~= lplr then
			self.said[plr.Name] = true
			notif('Vape', plr.Name..' is using vape!', 60)
			self.customtags[plr.Name] = {{
				text = 'VAPE USER',
				color = Color3.new(1, 1, 0)
			}}
			local newent = entitylib.getEntity(plr)
			if newent then
				entitylib.Events.EntityUpdated:Fire(newent)
			end
			return true
		end

		if self.localprio < self:get(plr) or plr == lplr then
			local args = msg:split(' ')
			table.remove(args, 1)
			if self:getplayer(args[1]) then
				table.remove(args, 1)
				for cmd, func in self.commands do
					if msg:sub(1, cmd:len() + 1):lower() == ';'..cmd:lower() then
						func(args, plr)
						return true
					end
				end
			end
		end

		return false
	end

	function whitelist:newchat(obj, plr, skip)
		obj.Text = self:tag(plr, true, true)..obj.Text
		local sub = obj.ContentText:find(': ')
		if sub then
			if not skip and self:process(obj.ContentText:sub(sub + 3, #obj.ContentText), plr) then
				obj.Visible = false
			end
		end
	end

	function whitelist:oldchat(func)
		local msgtable, oldchat = debug.getupvalue(func, 3)
		if typeof(msgtable) == 'table' and msgtable.CurrentChannel then
			whitelist.oldchattable = msgtable
		end

		oldchat = hookfunction(func, function(data, ...)
			local plr = playersService:GetPlayerByUserId(data.SpeakerUserId)
			if plr then
				data.ExtraData.Tags = data.ExtraData.Tags or {}
				for _, v in self:tag(plr) do
					table.insert(data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
				end
				if data.Message and self:process(data.Message, plr) then
					data.Message = ''
				end
			end
			return oldchat(data, ...)
		end)

		vape:Clean(function()
			hookfunction(func, oldchat)
		end)
	end

	function whitelist:hook()
		if self.hooked then return end
		self.hooked = true

		local exp = coreGui:FindFirstChild('ExperienceChat')
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if exp and exp:WaitForChild('appLayout', 5) then
				vape:Clean(exp:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(obj)
					local plr = playersService:GetPlayerByUserId(tonumber(obj.Name:split('-')[1]) or 0)
					obj = obj:FindFirstChild('TextMessage', true)
					if obj and obj:IsA('TextLabel') then
						if plr then
							self:newchat(obj, plr, true)
							obj:GetPropertyChangedSignal('Text'):Wait()
							self:newchat(obj, plr)
						end

						if obj.ContentText:sub(1, 35) == 'You are now privately chatting with' then
							obj.Visible = false
						end
					end
				end))
			end
		elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
			pcall(function()
				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessagePostedInChannel') then
						whitelist:oldchat(v.Function)
						break
					end
				end

				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessageFiltered') then
						whitelist:oldchat(v.Function)
						break
					end
				end
			end)
		end

		if exp then
			local bubblechat = exp:WaitForChild('bubbleChat', 5)
			if bubblechat then
				vape:Clean(bubblechat.DescendantAdded:Connect(function(newbubble)
					if newbubble:IsA('TextLabel') and newbubble.Text:find('helloimusinginhaler') then
						newbubble.Parent.Parent.Visible = false
					end
				end))
			end
		end
	end

	function whitelist:update(first)
		local suc = pcall(function()
			local _, subbed = pcall(function()
				return game:HttpGet('https://github.com/ReflexInCs/whitelists')
			end)
			local commit = subbed:find('currentOid')
			commit = commit and subbed:sub(commit + 13, commit + 52) or nil
			commit = commit and #commit == 40 and commit or 'main'
			whitelist.textdata = game:HttpGet('https://raw.githubusercontent.com/ReflexInCs/whitelists/'..commit..'/PlayerWhitelist.json', true)
		end)
		if not suc or not hash or not whitelist.get then return true end
		whitelist.loaded = true

		if not first or whitelist.textdata ~= whitelist.olddata then
			if not first then
				whitelist.olddata = isfile('newvape/profiles/whitelist.json') and readfile('newvape/profiles/whitelist.json') or nil
			end

			local suc, res = pcall(function()
				return httpService:JSONDecode(whitelist.textdata)
			end)

			whitelist.data = suc and type(res) == 'table' and res or whitelist.data
			whitelist.localprio = whitelist:get(lplr)

			for _, v in whitelist.data.WhitelistedUsers do
				if v.tags then
					for _, tag in v.tags do
						tag.color = Color3.fromRGB(unpack(tag.color))
					end
				end
			end

			if not whitelist.connection then
				whitelist.connection = playersService.PlayerAdded:Connect(function(v)
					whitelist:playeradded(v, true)
				end)
				vape:Clean(whitelist.connection)
			end

			for _, v in playersService:GetPlayers() do
				whitelist:playeradded(v)
			end

			if entitylib.Running and vape.Loaded then
				entitylib.refresh()
			end

			if whitelist.textdata ~= whitelist.olddata then
				if whitelist.data.Announcement.expiretime > os.time() then
					local targets = whitelist.data.Announcement.targets
					targets = targets == 'all' and {tostring(lplr.UserId)} or targets:split(',')

					if table.find(targets, tostring(lplr.UserId)) then
						local hint = Instance.new('Hint')
						hint.Text = 'VAPE ANNOUNCEMENT: '..whitelist.data.Announcement.text
						hint.Parent = workspace
						game:GetService('Debris'):AddItem(hint, 20)
					end
				end
				whitelist.olddata = whitelist.textdata
				pcall(function()
					writefile('newvape/profiles/whitelist.json', whitelist.textdata)
				end)
			end

			if whitelist.data.KillVape then
				vape:Uninject()
				return true
			end

			if whitelist.data.BlacklistedUsers[tostring(lplr.UserId)] then
				task.spawn(lplr.kick, lplr, whitelist.data.BlacklistedUsers[tostring(lplr.UserId)])
				return true
			end
		end
	end

	whitelist.commands = {
		byfron = function()
			task.spawn(function()
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local UIBlox = getrenv().require(game:GetService('CorePackages').UIBlox)
				local Roact = getrenv().require(game:GetService('CorePackages').Roact)
				UIBlox.init(getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppUIBloxConfig))
				local auth = getrenv().require(coreGui.RobloxGui.Modules.LuaApp.Components.Moderation.ModerationPrompt)
				local darktheme = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Style).Themes.DarkTheme
				local fonttokens = getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.App.Style.Tokens).getTokens('Desktop', 'Dark', true)
				local buildersans = getrenv().require(game:GetService('CorePackages').Packages._Index.UIBlox.UIBlox.App.Style.Fonts.FontLoader).new(true, fonttokens):loadFont()
				local tLocalization = getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppLocales).Localization
				local localProvider = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Localization).LocalizationProvider
				lplr.PlayerGui:ClearAllChildren()
				vape.gui.Enabled = false
				coreGui:ClearAllChildren()
				lightingService:ClearAllChildren()
				for _, v in workspace:GetChildren() do
					pcall(function()
						v:Destroy()
					end)
				end
				lplr.kick(lplr)
				guiService:ClearError()
				local gui = Instance.new('ScreenGui')
				gui.IgnoreGuiInset = true
				gui.Parent = coreGui
				local frame = Instance.new('ImageLabel')
				frame.BorderSizePixel = 0
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromRGB(224, 223, 225)
				frame.ScaleType = Enum.ScaleType.Crop
				frame.Parent = gui
				task.delay(0.3, function()
					frame.Image = 'rbxasset://textures/ui/LuaApp/graphic/Auth/GridBackground.jpg'
				end)
				task.delay(0.6, function()
					local modPrompt = Roact.createElement(auth, {
						style = {},
						screenSize = vape.gui.AbsoluteSize or Vector2.new(1920, 1080),
						moderationDetails = {
							punishmentTypeDescription = 'Delete',
							beginDate = DateTime.fromUnixTimestampMillis(DateTime.now().UnixTimestampMillis - ((60 * math.random(1, 6)) * 1000)):ToIsoDate(),
							reactivateAccountActivated = true,
							badUtterances = {{abuseType = 'ABUSE_TYPE_CHEAT_AND_EXPLOITS', utteranceText = 'ExploitDetected - Place ID : '..game.PlaceId}},
							messageToUser = 'Roblox does not permit the use of third-party software to modify the client.'
						},
						termsActivated = function() end,
						communityGuidelinesActivated = function() end,
						supportFormActivated = function() end,
						reactivateAccountActivated = function() end,
						logoutCallback = function() end,
						globalGuiInset = {top = 0}
					})

					local screengui = Roact.createElement(localProvider, {
						localization = tLocalization.new('en-us')
					}, {Roact.createElement(UIBlox.Style.Provider, {
						style = {
							Theme = darktheme,
							Font = buildersans
						},
					}, {modPrompt})})

					Roact.mount(screengui, coreGui)
				end)
			end)
		end,
		crash = function()
			task.spawn(function()
				repeat
					local part = Instance.new('Part')
					part.Size = Vector3.new(1e10, 1e10, 1e10)
					part.Parent = workspace
				until false
			end)
		end,
		deletemap = function()
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if terrain then
				terrain:Clear()
			end

			for _, v in workspace:GetChildren() do
				if v ~= terrain and not v:IsDescendantOf(lplr.Character) and not v:IsA('Camera') then
					v:Destroy()
					v:ClearAllChildren()
				end
			end
		end,
		framerate = function(args)
			if #args < 1 or not setfpscap then return end
			setfpscap(tonumber(args[1]) ~= '' and math.clamp(tonumber(args[1]) or 9999, 1, 9999) or 9999)
		end,
		gravity = function(args)
			workspace.Gravity = tonumber(args[1]) or workspace.Gravity
		end,
		jump = function()
			if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end,
		kick = function(args)
			task.spawn(function()
				lplr:Kick(table.concat(args, ' '))
			end)
		end,
		kill = function()
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				entitylib.character.Humanoid.Health = 0
			end
		end,
		reveal = function()
			task.delay(0.1, function()
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('I am using the inhaler client')
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('I am using the inhaler client', 'All')
				end
			end)
		end,
		shutdown = function()
			game:Shutdown()
		end,
		toggle = function(args)
			if #args < 1 then return end
			if args[1]:lower() == 'all' then
				for i, v in vape.Modules do
					if i ~= 'Panic' and i ~= 'ServerHop' and i ~= 'Rejoin' then
						v:Toggle()
					end
				end
			else
				for i, v in vape.Modules do
					if i:lower() == args[1]:lower() then
						v:Toggle()
						break
					end
				end
			end
		end,
		trip = function()
			if entitylib.isAlive then
				if entitylib.character.RootPart.Velocity.Magnitude < 15 then
					entitylib.character.RootPart.Velocity = entitylib.character.RootPart.CFrame.LookVector * 15
				end
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
			end
		end,
		uninject = function()
			if olduninject then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				olduninject(vape)
			else
				vape:Uninject()
			end
		end,
		void = function()
			if entitylib.isAlive then
				entitylib.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
			end
		end
	}

	task.spawn(function()
		repeat
			if whitelist:update(whitelist.loaded) then return end
			task.wait(10)
		until vape.Loaded == nil
	end)

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)

entitylib.start()

-- WalkSpeed Module
run(function()
	local WalkSpeed
	local Value
	local oldWalkSpeed
	
	WalkSpeed = vape.Categories.Player:CreateModule({
		Name = 'WalkSpeed',
		Function = function(callback)
			if callback then
				if entitylib.isAlive then
					oldWalkSpeed = entitylib.character.Humanoid.WalkSpeed
					entitylib.character.Humanoid.WalkSpeed = Value.Value
				end
				
				WalkSpeed:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					oldWalkSpeed = char.Humanoid.WalkSpeed
					char.Humanoid.WalkSpeed = Value.Value
				end))
				
				WalkSpeed:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive then
						entitylib.character.Humanoid.WalkSpeed = Value.Value
					end
				end))
			else
				if entitylib.isAlive and oldWalkSpeed then
					entitylib.character.Humanoid.WalkSpeed = oldWalkSpeed
				end
			end
		end,
		Tooltip = 'Changes your walk speed'
	})
	
	Value = WalkSpeed:CreateSlider({
		Name = 'Speed',
		Min = 16,
		Max = 100,
		Default = 23,
		Function = function(val)
			if WalkSpeed.Enabled and entitylib.isAlive then
				entitylib.character.Humanoid.WalkSpeed = val
			end
		end
	})
end)

-- JumpPower Module
run(function()
	local JumpPower
	local Value
	local oldJumpPower
	
	JumpPower = vape.Categories.Player:CreateModule({
		Name = 'JumpPower',
		Function = function(callback)
			if callback then
				if entitylib.isAlive then
					oldJumpPower = entitylib.character.Humanoid.JumpPower
					entitylib.character.Humanoid.JumpPower = Value.Value
					entitylib.character.Humanoid.UseJumpPower = true
				end
				
				JumpPower:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					oldJumpPower = char.Humanoid.JumpPower
					char.Humanoid.JumpPower = Value.Value
					char.Humanoid.UseJumpPower = true
				end))
				
				JumpPower:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive then
						entitylib.character.Humanoid.JumpPower = Value.Value
						entitylib.character.Humanoid.UseJumpPower = true
					end
				end))
			else
				if entitylib.isAlive and oldJumpPower then
					entitylib.character.Humanoid.JumpPower = oldJumpPower
					entitylib.character.Humanoid.UseJumpPower = true
				end
			end
		end,
		Tooltip = 'Changes your jump power'
	})
	
	Value = JumpPower:CreateSlider({
		Name = 'Power',
		Min = 50,
		Max = 150,
		Default = 50,
		Function = function(val)
			if JumpPower.Enabled and entitylib.isAlive then
				entitylib.character.Humanoid.JumpPower = val
			end
		end
	})
end)

-- Infinite Jump Module
run(function()
	local InfiniteJump
	
	InfiniteJump = vape.Categories.Player:CreateModule({
		Name = 'InfiniteJump',
		Function = function(callback)
			if callback then
				InfiniteJump:Clean(inputService.JumpRequest:Connect(function()
					if entitylib.isAlive then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end))
			end
		end,
		Tooltip = 'Allows you to jump infinitely in the air'
	})
end)
-- Auto Join Dungeon Module (Lobby Only)
run(function()
	local AutoJoinDungeon
	local DifficultySlider
	local AutoStartToggle
	local dungeonLoop
	local isRunning = false
	
	AutoJoinDungeon = vape.Categories.AutoFarm:CreateModule({
		Name = 'AutoJoinDungeon',
		Function = function(callback)
			if callback then
				-- Check if we're in the lobby
				if game.PlaceId ~= 3823781113 then
					notif('Auto Join', 'This module only works in the lobby (PlaceId: 3823781113)!', 5, 'warning')
					AutoJoinDungeon:Toggle()
					return
				end
				
				isRunning = true
				
				-- Get required modules
				local success, err = pcall(function()
					local ReplicatedStorage = game:GetService("ReplicatedStorage")
					local Players = game:GetService("Players")
					local LocalPlayer = Players.LocalPlayer
					
					local DungeonInfo = require(ReplicatedStorage.Modules.DungeonInfo)
					local DungeonGroupModule = require(ReplicatedStorage.Modules.DungeonGroupModule)
					local ClientDataManager = require(LocalPlayer.PlayerScripts.MainClient.ClientDataManager)
					local DateTimeManager = require(LocalPlayer.PlayerScripts.MainClient.DateTimeManager)
					local UIAction = ReplicatedStorage.Events.UIAction
					
					local DUNGEON = next(DungeonInfo.Dungeons)
					
					-- Main dungeon loop
					dungeonLoop = task.spawn(function()
						notif('Auto Join', 'Started! Difficulty: '..DifficultySlider.Value, 3)
						
						while isRunning and AutoJoinDungeon.Enabled do
							task.wait(5)
							
							if not DUNGEON then continue end
							
							-- Check cooldown
							local cooldown = math.max(0, ClientDataManager.Data.DungeonCooldownEndDT - DateTimeManager:Now())
							if cooldown > 0 then continue end
							
							local group = DungeonGroupModule.GetPlayersGroup(LocalPlayer)
							
							-- Create group if doesn't exist
							if not group then
								UIAction:FireServer("DungeonGroupAction", "Create", "Public", DUNGEON, DifficultySlider.Value)
								task.wait(1)
								group = DungeonGroupModule.GetPlayersGroup(LocalPlayer)
							end
							
							-- Start dungeon if we're the owner
							if group and DungeonGroupModule.CheckIsOwner(LocalPlayer, group) then
								UIAction:FireServer("DungeonGroupAction", "SwitchDungeonType", DUNGEON, DifficultySlider.Value)
								task.wait(1)
								
								if AutoStartToggle.Enabled then
									UIAction:FireServer("DungeonGroupAction", "Start")
									notif('Auto Join', 'Starting dungeon...', 2)
								end
							end
						end
					end)
				end)
				
				if not success then
					notif('Auto Join', 'Error: '..tostring(err), 5, 'error')
					AutoJoinDungeon:Toggle()
				end
			else
				-- Disable
				isRunning = false
				if dungeonLoop then
					task.cancel(dungeonLoop)
					dungeonLoop = nil
				end
				notif('Auto Join', 'Stopped', 2)
			end
		end,
		Tooltip = 'Automatically joins and starts dungeons in the lobby'
	})
	
	DifficultySlider = AutoJoinDungeon:CreateSlider({
		Name = 'Difficulty',
		Min = 1,
		Max = 4,
		Default = 4,
		Function = function(val)
			if AutoJoinDungeon.Enabled then
				notif('Auto Join', 'Difficulty set to: '..val, 2)
			end
		end,
		Tooltip = 'Select dungeon difficulty (1-4)'
	})
	
	AutoStartToggle = AutoJoinDungeon:CreateToggle({
		Name = 'Auto Start',
		Default = true,
		Function = function(callback) end,
		Tooltip = 'Automatically start the dungeon when ready'
	})
end)

-- Auto Farm Dungeon Module (Inside Dungeons Only)
run(function()
	local AutoFarmDungeon
	local FloatHeightBot
	local FloatHeightBoss
	local farmLoop, promptLoop, teleportLoop
	local isRunning = false
	local currentTarget
	
	AutoFarmDungeon = vape.Categories.AutoFarm:CreateModule({
		Name = 'AutoFarmDungeon',
		Function = function(callback)
			if callback then
				isRunning = true
				
				local Players = game:GetService("Players")
				local RunService = game:GetService("RunService")
				local LocalPlayer = Players.LocalPlayer
				local lastFireTime = 0
				local PROMPT_NAMES = {"Rainbow", "Shiny", "Void", "Gold"}
				
				-- Helper functions
				local function getCharacterParts()
					local char = LocalPlayer.Character
					if not char then return nil, nil, nil end
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local hum = char:FindFirstChildOfClass("Humanoid")
					local animator = char:FindFirstChildOfClass("Animator")
					return hrp, hum, animator
				end
				
				local function safeEnlargeHitbox(part)
					if not part or not part:IsA("BasePart") then return end
					if part:GetAttribute("AutoFarmScaled") then return end
					pcall(function()
						part.Size = part.Size * 3
						part:SetAttribute("AutoFarmScaled", true)
					end)
				end
				
				local function getActiveDungeon()
					local storage = workspace:FindFirstChild("DungeonStorage")
					if not storage then return nil end
					
					for _, folder in ipairs(storage:GetChildren()) do
						if folder:IsA("Folder") and folder:FindFirstChild("Important") then
							return folder
						end
					end
					return nil
				end
				
				local function isBoss(botPart)
					if not botPart or not botPart.Parent then return false end
					local name = botPart.Parent.Name:lower()
					return name:find("boss") ~= nil
				end
				
				local function getNextAliveBot()
					local dungeon = getActiveDungeon()
					if not dungeon then return nil end
					
					local important = dungeon:FindFirstChild("Important")
					if not important then return nil end
					
					for _, spawner in ipairs(important:GetChildren()) do
						if spawner:IsA("Part") or spawner:IsA("Model") then
							for _, botModel in ipairs(spawner:GetChildren()) do
								if botModel:IsA("Model") then
									local hrp = botModel:FindFirstChild("HumanoidRootPart")
									if hrp then
										safeEnlargeHitbox(hrp)
										return hrp
									end
								end
							end
						end
					end
					return nil
				end
				
				-- Farming loop
				AutoFarmDungeon:Clean(RunService.Heartbeat:Connect(function(deltaTime)
					if not isRunning or not AutoFarmDungeon.Enabled then return end
					
					local hrp, humanoid, animator = getCharacterParts()
					if not hrp or not humanoid then return end
					
					-- Stop animations
					if animator then
						pcall(function()
							for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
								track:Stop(0)
							end
						end)
					end
					
					-- Refresh target
					if not currentTarget or not currentTarget.Parent then
						currentTarget = getNextAliveBot()
					end
					
					if currentTarget then
						pcall(function()
							local targetPos = currentTarget.Position
							local height = isBoss(currentTarget) and FloatHeightBoss.Value or FloatHeightBot.Value
							local abovePos = targetPos + Vector3.new(0, height, 0)
							hrp.AssemblyLinearVelocity = Vector3.zero
							hrp.Velocity = Vector3.zero
							-- Look straight down at target
							hrp.CFrame = CFrame.new(abovePos) * CFrame.Angles(-math.pi/2, 0, 0)
						end)
					end
					
					-- Fire remotes
					lastFireTime = lastFireTime + deltaTime
					if lastFireTime >= 0.1 then
						lastFireTime = 0
						pcall(function()
							local char = LocalPlayer.Character
							if char then
								for _, tool in ipairs(char:GetChildren()) do
									if tool:IsA("Tool") and tool:FindFirstChild("RemoteClick") then
										tool.RemoteClick:FireServer({})
									end
								end
							end
							local ReplicatedStorage = game:GetService("ReplicatedStorage")
							if ReplicatedStorage:FindFirstChild("Events") and 
							   ReplicatedStorage.Events:FindFirstChild("SwingSaber") then
								ReplicatedStorage.Events.SwingSaber:FireServer()
							end
						end)
					end
				end))
				
				-- ProximityPrompt auto-collect
				promptLoop = task.spawn(function()
					while isRunning and AutoFarmDungeon.Enabled do
						task.wait(1)
						local dungeon = getActiveDungeon()
						if dungeon then
							for _, promptName in ipairs(PROMPT_NAMES) do
								local promptParent = dungeon:FindFirstChild(promptName)
								if promptParent then
									local proximityPrompt = promptParent:FindFirstChild("ProximityPrompt")
									if proximityPrompt and proximityPrompt:IsA("ProximityPrompt") then
										pcall(function()
											fireproximityprompt(proximityPrompt)
										end)
									end
								end
							end
						end
					end
				end)
				
				-- Auto teleport to prompts when no mobs
				teleportLoop = task.spawn(function()
					while isRunning and AutoFarmDungeon.Enabled do
						task.wait(10)
						local dungeon = getActiveDungeon()
						if dungeon then
							local aliveBot = getNextAliveBot()
							if not aliveBot then
								local hrp = getCharacterParts()
								if hrp then
									for _, promptName in ipairs(PROMPT_NAMES) do
										local promptParent = dungeon:FindFirstChild(promptName)
										if promptParent then
											pcall(function()
												hrp.CFrame = promptParent:GetPivot() + Vector3.new(0, 5, 0)
											end)
											break
										end
									end
								end
							end
						end
					end
				end)
				
				notif('Auto Farm', 'Started farming dungeon!', 3)
			else
				-- Disable
				isRunning = false
				currentTarget = nil
				if promptLoop then task.cancel(promptLoop) end
				if teleportLoop then task.cancel(teleportLoop) end
				notif('Auto Farm', 'Stopped', 2)
			end
		end,
		Tooltip = 'Automatically farms dungeons and collects items'
	})
	
	FloatHeightBot = AutoFarmDungeon:CreateSlider({
		Name = 'Bot Height',
		Min = 5,
		Max = 20,
		Default = 9,
		Function = function(val) end,
		Tooltip = 'Float height above regular bots'
	})
	
	FloatHeightBoss = AutoFarmDungeon:CreateSlider({
		Name = 'Boss Height',
		Min = 10,
		Max = 30,
		Default = 17,
		Function = function(val) end,
		Tooltip = 'Float height above boss enemies'
	})
end)

-- Fully Auto Dungeon (Combined: Join + Farm)
run(function()
	local FullyAutoDungeon
	local DifficultySlider
	local FloatHeightBot
	local FloatHeightBoss
	local AutoStartToggle
	
	local joinLoop, promptLoop, teleportLoop
	local isRunning = false
	local currentTarget
	
	FullyAutoDungeon = vape.Categories.AutoFarm:CreateModule({
		Name = 'FullyAutoDungeon',
		Function = function(callback)
			if callback then
				isRunning = true
				notif('Fully Auto', 'Started! Will auto-join and auto-farm', 3)
				
				local Players = game:GetService("Players")
				local RunService = game:GetService("RunService")
				local LocalPlayer = Players.LocalPlayer
				local PROMPT_NAMES = {"Rainbow", "Shiny", "Void", "Gold"}
				
				-- Helper functions
				local function getCharacterParts()
					local char = LocalPlayer.Character
					if not char then return nil, nil, nil end
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local hum = char:FindFirstChildOfClass("Humanoid")
					local animator = char:FindFirstChildOfClass("Animator")
					return hrp, hum, animator
				end
				
				local function safeEnlargeHitbox(part)
					if not part or not part:IsA("BasePart") then return end
					if part:GetAttribute("AutoFarmScaled") then return end
					pcall(function()
						part.Size = part.Size * 3
						part:SetAttribute("AutoFarmScaled", true)
					end)
				end
				
				local function getActiveDungeon()
					local storage = workspace:FindFirstChild("DungeonStorage")
					if not storage then return nil end
					
					for _, folder in ipairs(storage:GetChildren()) do
						if folder:IsA("Folder") and folder:FindFirstChild("Important") then
							return folder
						end
					end
					return nil
				end
				
				local function isBoss(botPart)
					if not botPart or not botPart.Parent then return false end
					local name = botPart.Parent.Name:lower()
					return name:find("boss") ~= nil
				end
				
				local function getNextAliveBot()
					local dungeon = getActiveDungeon()
					if not dungeon then return nil end
					
					local important = dungeon:FindFirstChild("Important")
					if not important then return nil end
					
					for _, spawner in ipairs(important:GetChildren()) do
						if spawner:IsA("Part") or spawner:IsA("Model") then
							for _, botModel in ipairs(spawner:GetChildren()) do
								if botModel:IsA("Model") then
									local hrp = botModel:FindFirstChild("HumanoidRootPart")
									if hrp then
										safeEnlargeHitbox(hrp)
										return hrp
									end
								end
							end
						end
					end
					return nil
				end
				
				-- Function to handle lobby (auto join)
				local function handleLobby()
					if game.PlaceId ~= 3823781113 then return end
					
					pcall(function()
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local DungeonInfo = require(ReplicatedStorage.Modules.DungeonInfo)
						local DungeonGroupModule = require(ReplicatedStorage.Modules.DungeonGroupModule)
						local ClientDataManager = require(LocalPlayer.PlayerScripts.MainClient.ClientDataManager)
						local DateTimeManager = require(LocalPlayer.PlayerScripts.MainClient.DateTimeManager)
						local UIAction = ReplicatedStorage.Events.UIAction
						
						local DUNGEON = next(DungeonInfo.Dungeons)
						
						joinLoop = task.spawn(function()
							while isRunning and FullyAutoDungeon.Enabled and game.PlaceId == 3823781113 do
								task.wait(5)
								
								if not DUNGEON then continue end
								
								local cooldown = math.max(0, ClientDataManager.Data.DungeonCooldownEndDT - DateTimeManager:Now())
								if cooldown > 0 then continue end
								
								local group = DungeonGroupModule.GetPlayersGroup(LocalPlayer)
								
								if not group then
									UIAction:FireServer("DungeonGroupAction", "Create", "Public", DUNGEON, DifficultySlider.Value)
									task.wait(1)
									group = DungeonGroupModule.GetPlayersGroup(LocalPlayer)
								end
								
								if group and DungeonGroupModule.CheckIsOwner(LocalPlayer, group) then
									UIAction:FireServer("DungeonGroupAction", "SwitchDungeonType", DUNGEON, DifficultySlider.Value)
									task.wait(1)
									
									if AutoStartToggle.Enabled then
										UIAction:FireServer("DungeonGroupAction", "Start")
									end
								end
							end
						end)
					end)
				end
				
				-- Function to handle dungeon farming
				local function handleDungeon()
					local lastFireTime = 0
					
					-- Heartbeat farming
					FullyAutoDungeon:Clean(RunService.Heartbeat:Connect(function(deltaTime)
						if not isRunning or not FullyAutoDungeon.Enabled then return end
						
						local hrp, humanoid, animator = getCharacterParts()
						if not hrp or not humanoid then return end
						
						if animator then
							pcall(function()
								for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
									track:Stop(0)
								end
							end)
						end
						
						-- Refresh target
						if not currentTarget or not currentTarget.Parent then
							currentTarget = getNextAliveBot()
						end
						
						if currentTarget then
							pcall(function()
								local targetPos = currentTarget.Position
								local height = isBoss(currentTarget) and FloatHeightBoss.Value or FloatHeightBot.Value
								local abovePos = targetPos + Vector3.new(0, height, 0)
								hrp.AssemblyLinearVelocity = Vector3.zero
								hrp.Velocity = Vector3.zero
								-- Look straight down at target
								hrp.CFrame = CFrame.new(abovePos) * CFrame.Angles(-math.pi/2, 0, 0)
							end)
						end
						
						lastFireTime = lastFireTime + deltaTime
						if lastFireTime >= 0.1 then
							lastFireTime = 0
							pcall(function()
								local char = LocalPlayer.Character
								if char then
									for _, tool in ipairs(char:GetChildren()) do
										if tool:IsA("Tool") and tool:FindFirstChild("RemoteClick") then
											tool.RemoteClick:FireServer({})
										end
									end
								end
								local ReplicatedStorage = game:GetService("ReplicatedStorage")
								if ReplicatedStorage:FindFirstChild("Events") and 
								   ReplicatedStorage.Events:FindFirstChild("SwingSaber") then
									ReplicatedStorage.Events.SwingSaber:FireServer()
								end
							end)
						end
					end))
					
					-- Auto-collect items
					promptLoop = task.spawn(function()
						while isRunning and FullyAutoDungeon.Enabled do
							task.wait(1)
							local dungeon = getActiveDungeon()
							if dungeon then
								for _, promptName in ipairs(PROMPT_NAMES) do
									local promptParent = dungeon:FindFirstChild(promptName)
									if promptParent then
										local proximityPrompt = promptParent:FindFirstChild("ProximityPrompt")
										if proximityPrompt and proximityPrompt:IsA("ProximityPrompt") then
											pcall(function()
												fireproximityprompt(proximityPrompt)
											end)
										end
									end
								end
							end
						end
					end)
					
					-- Auto teleport to prompts when no mobs
					teleportLoop = task.spawn(function()
						while isRunning and FullyAutoDungeon.Enabled do
							task.wait(1)
							local dungeon = getActiveDungeon()
							if dungeon then
								local aliveBot = getNextAliveBot()
								if not aliveBot then
									local hrp = getCharacterParts()
									if hrp then
										for _, promptName in ipairs(PROMPT_NAMES) do
											local promptParent = dungeon:FindFirstChild(promptName)
											if promptParent then
												pcall(function()
													hrp.CFrame = promptParent:GetPivot() + Vector3.new(0, 5, 0)
												end)
												break
											end
										end
									end
								end
							end
						end
					end)
				end
				
				-- Initial check and setup
				if game.PlaceId == 3823781113 then
					handleLobby()
				else
					handleDungeon()
				end
				
			else
				isRunning = false
				currentTarget = nil
				if joinLoop then task.cancel(joinLoop) end
				if promptLoop then task.cancel(promptLoop) end
				if teleportLoop then task.cancel(teleportLoop) end
				notif('Fully Auto', 'Stopped', 2)
			end
		end,
		Tooltip = 'Fully automatic: Joins dungeons in lobby, farms when inside'
	})
	
	DifficultySlider = FullyAutoDungeon:CreateSlider({
		Name = 'Difficulty',
		Min = 1,
		Max = 4,
		Default = 4,
		Function = function(val) end,
		Tooltip = 'Dungeon difficulty (1-4)'
	})
	
	FloatHeightBot = FullyAutoDungeon:CreateSlider({
		Name = 'Bot Height',
		Min = 5,
		Max = 20,
		Default = 9,
		Function = function(val) end,
		Tooltip = 'Float height above regular bots'
	})
	
	FloatHeightBoss = FullyAutoDungeon:CreateSlider({
		Name = 'Boss Height',
		Min = 10,
		Max = 30,
		Default = 17,
		Function = function(val) end,
		Tooltip = 'Float height above boss enemies'
	})
	
	AutoStartToggle = FullyAutoDungeon:CreateToggle({
		Name = 'Auto Start',
		Default = true,
		Function = function(callback) end,
		Tooltip = 'Auto start dungeons in lobby'
	})
end)
