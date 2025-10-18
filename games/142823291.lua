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
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local runService = cloneref(game:GetService('RunService'))
local lplr = playersService.LocalPlayer

local vape = shared.vape
local entitylib = loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()

local function notif(...)
	return vape:CreateNotification(...)
end

entitylib.start()

-- Shoot Murderer Module with External Button
run(function()
	local ShootMurderer
	local shootOffset = 2.8
	local offsetToPingMult = 1
	local shootBtn
	
	local function getHRP(plr)
		return plr.Character and (plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("UpperTorso"))
	end
	
	local function getHumanoid(plr)
		return plr.Character and plr.Character:FindFirstChild("Humanoid")
	end
	
	local function getMurderer()
		for _, plr in ipairs(playersService:GetPlayers()) do
			if plr ~= lplr and (plr.Backpack:FindFirstChild("Knife") or (plr.Character and plr.Character:FindFirstChild("Knife"))) then
				return plr
			end
		end
	end
	
	local function getPredictedPosition(target)
		local hrp = getHRP(target)
		local hum = getHumanoid(target)
		if not hrp or not hum then return Vector3.zero end
		
		local velocity = hrp.AssemblyLinearVelocity
		local moveDir = hum.MoveDirection
		local predicted = hrp.Position + (velocity * Vector3.new(0, 0.5, 0)) * (shootOffset / 15) + moveDir * shootOffset
		predicted *= (((lplr:GetNetworkPing() * 1000) * ((offsetToPingMult - 1) * 0.01)) + 1)
		return predicted
	end
	
	local function shootMurderer()
		local hasGun = lplr.Backpack:FindFirstChild("Gun") or (lplr.Character and lplr.Character:FindFirstChild("Gun"))
		if not hasGun then
			notif('Shoot Murderer', 'You are not the sheriff/hero or don\'t have a gun.', 3, 'warning')
			return false
		end
		
		local murderer = getMurderer()
		if not murderer then
			notif('Shoot Murderer', 'No murderer found.', 3, 'warning')
			return false
		end
		
		-- Equip Gun
		if lplr.Backpack:FindFirstChild("Gun") then
			local hum = getHumanoid(lplr)
			if hum then hum:EquipTool(lplr.Backpack:FindFirstChild("Gun")) end
		end
		
		local predicted = getPredictedPosition(murderer)
		
		local args = {
			[1] = 1,
			[2] = predicted,
			[3] = "AH2"
		}
		
		local gunScript = lplr.Character and lplr.Character:FindFirstChild("Gun") and lplr.Character.Gun:FindFirstChild("KnifeLocal")
		if gunScript and gunScript:FindFirstChild("CreateBeam") then
			gunScript.CreateBeam.RemoteFunction:InvokeServer(unpack(args))
			notif('Shoot Murderer', 'Shot at murderer!', 2)
			return true
		else
			notif('Shoot Murderer', 'Gun script missing CreateBeam.', 3, 'error')
			return false
		end
	end
	
	local function createShootButton()
		local coreGui = cloneref(game:GetService("CoreGui"))
		local gui = Instance.new("ScreenGui", coreGui)
		gui.Name = "MM2ShootButton"
		gui.ResetOnSpawn = false
		
		shootBtn = Instance.new("TextButton")
		shootBtn.Name = "ShootMurderer"
		shootBtn.Size = UDim2.new(0, 160, 0, 40)
		shootBtn.Position = UDim2.new(1, -170, 0, 60)
		shootBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		shootBtn.TextColor3 = Color3.new(1, 1, 1)
		shootBtn.Font = Enum.Font.GothamBold
		shootBtn.TextScaled = true
		shootBtn.Text = "Shoot Murderer"
		shootBtn.Parent = gui
		
		local corner = Instance.new("UICorner", shootBtn)
		
		shootBtn.MouseButton1Click:Connect(function()
			shootMurderer()
		end)
		
		return gui
	end
	
	ShootMurderer = vape.Categories.Misc:CreateModule({
		Name = 'ShootMurderer',
		Function = function(callback)
			if callback then
				local gui = createShootButton()
				notif('Shoot Murderer', 'Button enabled! Click the button to shoot.', 3)
				
				ShootMurderer:Clean(function()
					if gui then
						gui:Destroy()
					end
				end)
			else
				notif('Shoot Murderer', 'Button disabled.', 2)
			end
		end,
		Tooltip = 'Shows a button to shoot the murderer when clicked (Sheriff/Hero only)'
	})
end)
