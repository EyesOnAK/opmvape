if table.find({'Solara', 'Xeno'}, ({identifyexecutor()})[1]) then return false end
local buildclock = os.clock()
local buildbudget = 0.004
local run = function(func)
	xpcall(func, function(err)
		warn('[opmvape] ' .. tostring(err) .. '\\n' .. tostring(debug.traceback(nil, 2)))
		if shared.vape then
			shared.vape:CreateNotification('Vape', 'A module failed to load : ' .. tostring(err), 15, 'alert')
		end
	end)

	if os.clock() - buildclock > buildbudget then
		buildbudget = math.clamp(task.wait() * 0.75, 0.004, 0.02)
		buildclock = os.clock()
	end
end
local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local sessioninfo = vape.Libraries.sessioninfo
local bedwars = {}

local function notif(...)
	return vape:CreateNotification(...)
end

run(function()
	local function dumpRemote(tab)
		local ind = table.find(tab, 'Client')
		return ind and tab[ind + 1] or ''
	end

	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function() return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9) end)
		if KnitInit then break end
		task.wait()
	until KnitInit
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end
	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local Client = require(replicatedStorage.TS.remotes).default.Client

	bedwars = setmetatable({
		Client = Client,
		CrateItemMeta = debug.getupvalue(Flamework.resolveDependency('client/controllers/global/reward-crate/crate-controller@CrateController').onStart, 3),
		EmoteDisplayMeta = require(replicatedStorage.TS.locker.emote['emote-display-meta']).EmoteDisplayMeta,
		EmoteMeta = require(replicatedStorage.TS.locker.emote['emote-meta']).EmoteMeta,
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		GamePlayerUtil = require(replicatedStorage.TS.player['player-util']).GamePlayerUtil,
		AchievementUtil = require(replicatedStorage.TS.achievement['achievement-util']).AchievementUtil,
		ModerationApp = require(lplr.PlayerScripts.TS.controllers.global['match-history'].ui['match-history-moderation-app']).MatchHistoryModerationApp,
		MilestoneRewards = require(replicatedStorage.TS.milestones.milestones).MilestoneRewards,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	vape:Clean(function()
		table.clear(bedwars)
	end)
end)

for i, v in vape.Modules do
	if v.Category == 'Combat' then
		vape:Remove(i)
	end
end

run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() bedwars.SprintController:stopSprinting() end))
				bedwars.SprintController:stopSprinting()
			else
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)

run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.Utility:CreateModule({
		Name = 'AutoGamble',
		Function = function(callback)
			if callback then
				AutoGamble:Clean(bedwars.Client:GetNamespace('RewardCrate'):Get('CrateOpened'):Connect(function(data)
					if data.openingPlayer == lplr then
						local tab = bedwars.CrateItemMeta[data.reward.itemType] or {displayName = data.reward.itemType or 'unknown'}
						notif('AutoGamble', 'Won '..tab.displayName, 5)
					end
				end))
	
				repeat
					if not bedwars.CrateAltarController.activeCrates[1] then
						for _, v in bedwars.Store:getState().Consumable.inventory do
							if v.consumable:find('crate') then
								bedwars.CrateAltarController:pickCrate(v.consumable, 1)
								task.wait(1.2)
								if bedwars.CrateAltarController.activeCrates[1] and bedwars.CrateAltarController.activeCrates[1][2] then
									bedwars.Client:GetNamespace('RewardCrate'):Get('OpenRewardCrate'):SendToServer({
										crateId = bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
									})
								end
								break
							end
						end
					end
					task.wait(1)
				until not AutoGamble.Enabled
			end
		end,
		Tooltip = 'Automatically opens lucky crates, piston inspired!'
	})
end)

run(function()
	local AutoQueue
	local QueueType
	local Leave
	
	local Categories = {}
	
	AutoQueue = vape.Categories.Utility:CreateModule({
	    Name = 'AutoQueue',
	    Function = function(call)
	        if call then
	            repeat
	                local partyData = bedwars.Store:getState().Party
	                if partyData.leader.userId == lplr.UserId then
	                    if partyData.queueState == 3 and partyData.queueState ~= Categories[QueueType.Value] then
	                        replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveQueue:FireServer()
	                    elseif partyData.queueState < 2 then
							bedwars.QueueController:joinQueue(Categories[QueueType.Value])
	                        task.wait(1)
	                    end
	                elseif Leave.Enabled then
	                    replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveParty:FireServer()
	                end
	                task.wait(0.1)
	            until not AutoQueue.Enabled
	
	        else
	            replicatedStorage['events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events'].leaveQueue:FireServer()
	        end
	    end
	})
	
	local list = {}
	for i,v in bedwars.QueueMeta do
	    if not v.disabled and v.title and not Categories[v.title] then
	        Categories[v.title] = i
	        table.insert(list, v.title)
	    end
	end
	table.sort(list)
	QueueType = AutoQueue:CreateDropdown({
	    Name = 'Queue Type',
	    List = list,
	    Default = 'Duels (2v2)'
	})
	Leave = AutoQueue:CreateToggle({
	    Name = 'Leave Party',
	    Default = true
	})
end)

run(function()
	local ClaimRewards
	local CratesOnly
	local Notify
	
	ClaimRewards = vape.Categories.Utility:CreateModule({
		Name = 'ClaimRewards',
		Function = function(callback)
			if callback then
				repeat
					local level = bedwars.Store:getState().Bedwars.playerLevel or 0
					local claimed = bedwars.MilestonesController.milestoneRewardsClaimed
				if not claimed then
					local state = bedwars.Store:getState().Bedwars
					claimed = state and state.milestoneRewardsClaimed or {}
				end
	
					for _, v in bedwars.MilestoneRewards do
						if v.levelRequirement <= level and not table.find(claimed, v.id) and (not CratesOnly.Enabled or v.instantClaim) then
							if bedwars.Client:Get('ClaimMilestoneReward'):CallServer(v.id) then
								table.insert(claimed, v.id)
								if Notify.Enabled then
									notif('ClaimRewards', 'Claimed ' .. tostring(v.description or v.id), 5)
								end
							end
							task.wait(1)
							if not ClaimRewards.Enabled then break end
						end
					end
	
					task.wait(5)
				until not ClaimRewards.Enabled
			end
		end,
		Tooltip = 'Automatically claims every level milestone reward as soon as you unlock it'
	})
	
	CratesOnly = ClaimRewards:CreateToggle({
		Name = 'Crates only',
		Tooltip = 'Only claims the instant rewards like the lucky and diamond crates, leaves kits and cosmetics alone'
	})
	Notify = ClaimRewards:CreateToggle({
		Name = 'Notify',
		Default = true,
		Tooltip = 'Tells you what got claimed'
	})
end)

run(function()
	local DeviceSpoofer
	local Device
	local oldDevice, old
	
	DeviceSpoofer = vape.Categories.Utility:CreateModule({
		Name = 'DeviceSpoofer',
		Function = function(callback)
			if callback then
				oldDevice, old = bedwars.UserInputController:getUserInputType(), bedwars.UserInputController.getUserInputType
				bedwars.UserInputController.getUserInputType = function()
					return Device.Value:upper()
				end
				bedwars.Client:Get('SendUserInputType'):SendToServer({userInputType = Device.Value:upper()})
			else
				bedwars.UserInputController.getUserInputType = old
				bedwars.Client:Get('SendUserInputType'):SendToServer({userInputType = oldDevice})
				old = nil
			end
		end,
		Tooltip = 'Spoofs the device you show up as to the server',
		ExtraText = function()
			return Device.Value
		end
	})
	
	Device = DeviceSpoofer:CreateDropdown({
		Name = 'Device',
		List = {'Mobile', 'PC', 'Gamepad'},
		Function = function(val)
			if DeviceSpoofer.Enabled then
				bedwars.Client:Get('SendUserInputType'):SendToServer({userInputType = val:upper()})
			end
		end
	})
end)

run(function()
	local MatchDodge
	local AutoUndodge
	local UndodgeMode
	local Blacklist
	local Ping
	local Timeout
	local VetoAt
	local MaxWait
	local Advanced
	local RankAdvantage
	local DeviceCheck
	local Device
	local LowRank
	local LowRankAt
	local Guaranteed
	local tiers = {'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Emerald', 'Nightmare'}
	
	MatchDodge = vape.Categories.Utility:CreateModule({
		Name = 'AutoMatchDodge',
		Function = function(callback)
			writefile('opmsix/profiles/matchdodge.txt', tostring(callback))
			getgenv().matchDodgeActive = callback
		end,
		Tooltip = 'Sets the dodge checks for your next match; settings carry over from the lobby'
	})
	
	MatchDodge:CreateButton({
		Name = 'Load',
		Function = function()
			bedwars.Handler:Get('PlayerConnect'):Fire(nil, teleportService:GetLocalPlayerTeleportData())
		end
	})
	MatchDodge:CreateToggle({
		Name = 'Rank only',
		Tooltip = 'Loads straight away when the match is not ranked'
	})
	AutoUndodge = MatchDodge:CreateToggle({
		Name = 'Auto Undodge',
		Function = function(callback)
			if UndodgeMode then
				UndodgeMode.Object.Visible = callback
			end
			if Blacklist then
				Blacklist.Object.Visible = callback and UndodgeMode.Value == 'Rank'
			end
			if Ping then
				Ping.Object.Visible = callback and UndodgeMode.Value == 'Latency'
			end
		end,
		Tooltip = 'Automatically loads when the selected checks pass'
	})
	UndodgeMode = MatchDodge:CreateDropdown({
		Name = 'Mode',
		List = {'Rank', 'Latency'},
		Function = function(value)
			if Blacklist then
				Blacklist.Object.Visible = AutoUndodge.Enabled and value == 'Rank'
			end
			if Ping then
				Ping.Object.Visible = AutoUndodge.Enabled and value == 'Latency'
			end
		end,
		Darker = true,
		Visible = false,
		Tooltip = 'Rank waits for opponents to load, Latency waits for your ping to reach the threshold'
	})
	Blacklist = MatchDodge:CreateTextList({
		Name = 'Rank Blacklist',
		Placeholder = 'bronze / silver / gold / platinum / diamond / emerald / nightmare',
		Darker = true,
		Visible = false,
		Function = function()
			for i, v in Blacklist.List do
				Blacklist.List[i] = v:lower()
			end
			for i, v in Blacklist.ListEnabled do
				Blacklist.ListEnabled[i] = v:lower()
			end
		end
	})
	Ping = MatchDodge:CreateSlider({
		Name = 'Ping',
		Min = 50,
		Max = 1000,
		Default = 200,
		Darker = true,
		Visible = false,
		Suffix = 'ms',
		Tooltip = 'How high your ping has to be before loading'
	})
	MatchDodge:CreateToggle({
		Name = 'Rank Veto',
		Function = function(callback)
			if VetoAt then
				VetoAt.Object.Visible = callback
			end
		end,
		Tooltip = 'Keeps dodging opponents at or above the selected rank, even after Max Wait'
	})
	VetoAt = MatchDodge:CreateDropdown({
		Name = 'Veto At',
		List = tiers,
		Default = 'Diamond',
		Darker = true,
		Visible = false,
		Tooltip = 'The lowest enemy rank that blocks automatic loading'
	})
	MatchDodge:CreateToggle({
		Name = '4v5 Check',
		Tooltip = 'In 5v5 queues, waits if fewer teammates than opponents are loaded, counting you'
	})
	MaxWait = MatchDodge:CreateSlider({
		Name = 'Max Wait',
		Min = 0,
		Max = 120,
		Function = function(value)
			if Timeout then
				Timeout.Value = value
			end
		end,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end,
		Tooltip = 'Skips the mode wait after this long. Rank vetoes, blacklist, team and Advanced checks still apply. 0 waits forever'
	})
	Timeout = MatchDodge:CreateSlider({
		Name = 'Timeout',
		Min = 0,
		Max = 120,
		Function = function(value)
			MaxWait:SetValue(value)
		end,
		Default = 20,
		Visible = false
	})
	Advanced = MatchDodge:CreateToggle({
		Name = 'Advanced',
		Function = function(callback)
			for _, v in {RankAdvantage, DeviceCheck, LowRank, Guaranteed} do
				v.Object.Visible = callback
			end
			if Device then
				Device.Object.Visible = callback and DeviceCheck.Enabled
			end
			if LowRankAt then
				LowRankAt.Object.Visible = callback and LowRank.Enabled
			end
		end,
		Tooltip = 'Enables extra conditions for automatic loading'
	})
	RankAdvantage = MatchDodge:CreateToggle({
		Name = 'Rank Advantage',
		Darker = true,
		Visible = false,
		Tooltip = 'Requires your team, including you, to have a higher average rank division'
	})
	DeviceCheck = MatchDodge:CreateToggle({
		Name = 'Device Check',
		Function = function(callback)
			if Device then
				Device.Object.Visible = Advanced.Enabled and callback
			end
		end,
		Darker = true,
		Visible = false,
		Tooltip = 'Requires every opponent to use one of the selected devices'
	})
	Device = MatchDodge:CreateDropdown({
		Name = 'Device',
		List = {'Mobile / Gamepad', 'Mobile', 'Gamepad', 'PC'},
		Darker = true,
		Visible = false
	})
	LowRank = MatchDodge:CreateToggle({
		Name = 'Low Rank',
		Function = function(callback)
			if LowRankAt then
				LowRankAt.Object.Visible = Advanced.Enabled and callback
			end
		end,
		Darker = true,
		Visible = false,
		Tooltip = 'Requires every opponent to be at or below the selected rank'
	})
	LowRankAt = MatchDodge:CreateDropdown({
		Name = 'Low Rank At',
		List = tiers,
		Default = 'Gold',
		Darker = true,
		Visible = false
	})
	Guaranteed = MatchDodge:CreateToggle({
		Name = 'Guaranteed 5v4',
		Darker = true,
		Visible = false,
		Tooltip = 'Waits for the match to start with 5 on your side and 4 opponents, with nobody still loading. Later reconnects can change the teams'
	})
	task.spawn(function()
		repeat task.wait() until vape.Loaded or vape.Loaded == nil
		local last = isfile('opmsix/profiles/matchdodge.json') and readfile('opmsix/profiles/matchdodge.json')
		if vape.Loaded and last then
			local suc, res = pcall(httpService.JSONDecode, httpService, last)
			if suc and type(res) == 'table' then
				if res.Options and res.Options['Max Wait'] then
					res.Options.Timeout = res.Options['Max Wait']
				end
				MatchDodge:Load(res)
			end
		end
	
		repeat
			if vape.Loaded then
				local data = {}
				MatchDodge:Save(data)
				data.AutoMatchDodge.Favorited = nil
				local encoded = httpService:JSONEncode(data.AutoMatchDodge)
				if encoded ~= last then
					last = encoded
					writefile('opmsix/profiles/matchdodge.json', encoded)
				end
			end
			task.wait(1)
		until vape.Loaded == nil
	end)
end)

run(function()
	local MatchHistory
	
	MatchHistory = vape.Categories.Utility:CreateModule({
	    Name = 'ViewMatchHistory',
	    Function = function(callback)
	        if callback then
	            bedwars.Flamework.resolveDependency('easy-games/game-core:client/controllers/app-controller@AppController'):openApp({
	                appId = 'MatchHistoryApp',
	                app = bedwars.ModerationApp
	            }, {
	                player = lplr,
	                matchHistory = {}
	            })
	            MatchHistory:Toggle()
	        end
	    end
	})
end)

run(function()
	local NameHider
	local Replacement
	local ChatTags
	local Level
	local HideOthers
	local swapped = setmetatable({}, {__mode = 'k'})
	local watched = setmetatable({}, {__mode = 'k'})
	local patterns = {}
	local plain = {}
	local shortest = math.huge
	local textclasses = {TextLabel = true, TextButton = true, TextBox = true}
	local fake = 'hidden'
	local writing
	local oldUsername, oldDisplayName, oldClanTag, oldLevel
	
	local refreshing = false
	
	local function queueRefresh()
		if refreshing or not NameHider or not NameHider.Enabled then return end
		refreshing = true
	
		task.delay(0.35, function()
			refreshing = false
			if NameHider.Enabled then
				NameHider:Toggle()
				NameHider:Toggle()
			end
		end)
	end
	
	local function shouldHidePlayer(player)
		return player and (player.UserId == lplr.UserId or HideOthers.Enabled)
	end
	
	local function addPlayerNames(player)
		for _, v in {player.Name, player.DisplayName} do
			if v ~= '' then
				local low = v:lower()
				if not table.find(plain, low) then
					table.insert(plain, low)
					shortest = math.min(shortest, #low)
				end
			end
			for _, v2 in {v, v:lower(), v:upper()} do
				local pattern = (v2:gsub('%W', '%%%0'))
				if v2 ~= '' and not table.find(patterns, pattern) then
					table.insert(patterns, pattern)
				end
			end
		end
	end
	
	local function isLocal(gameplayer)
		local player = gameplayer:getPlayer()
		return player ~= nil and player.UserId == lplr.UserId
	end
	
	local function getGamePlayerClass()
		local gameplayer = bedwars.GamePlayerUtil and bedwars.GamePlayerUtil.getGamePlayer(lplr)
		local meta = gameplayer and getmetatable(gameplayer)
		return meta and meta.__index
	end
	
	local function hasPlayerName(object)
		local parent = object.Parent
		for _ = 1, 3 do
			if not parent then return nil end
			local label = parent:FindFirstChild('PlayerName', true)
			if label then return label end
			parent = parent.Parent
		end
		return nil
	end
	
	local function hideLevelObject(object)
		if not (Level.Enabled or HideOthers.Enabled) or not textclasses[object.ClassName] then return end
		if not object.Name:lower():find('level', 1, true) then return end
		local playerName = hasPlayerName(object)
		if not playerName or (not HideOthers.Enabled and not playerName.Text:find(fake, 1, true)) then return end
	
		local function apply()
			if writing == object or not object.Parent then return end
			local text = object.Text
			if type(text) ~= 'string' or text == '' then return end
	
			swapped[object] = swapped[object] or text
			writing = object
			object.Text = ''
			writing = nil
		end
	
		apply()
		if not watched[object] then
			watched[object] = object:GetPropertyChangedSignal('Text'):Connect(apply)
		end
	end
	
	local function hideLevelSiblings(object)
		if not object then return end
		for _, child in object:GetDescendants() do
			hideLevelObject(child)
		end
	end
	
	local function hideObject(object)
		if not textclasses[object.ClassName] then return end
	
		local function apply()
			if writing == object then return end
	
			local text = object.Text
			if type(text) ~= 'string' or #text < shortest then return end
	
			local hit = false
			for _, v in plain do
				if text:find(v, 1, true) then
					hit = true
					break
				end
			end
			if not hit then
				local lower = text:lower()
				for _, v in plain do
					if lower:find(v, 1, true) then
						hit = true
						break
					end
				end
			end
			if not hit then return end
	
			local new = text
			for _, v in patterns do
				if new:find(v) then
					new = new:gsub(v, fake)
				end
			end
			if new == text then return end
	
			swapped[object] = text
			writing = object
			object.Text = new
			writing = nil
			hideLevelSiblings(object.Parent)
	
			if not watched[object] then
				watched[object] = object:GetPropertyChangedSignal('Text'):Connect(apply)
			end
		end
	
		apply()
	end
	
	local function watch(root)
		if not root then return end
	
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		NameHider:Clean(root.DescendantAdded:Connect(function(object)
			if NameHider.Enabled then
				hideObject(object)
				hideLevelObject(object)
			end
		end))
	
		local clock = os.clock()
		for _, v in root:GetDescendants() do
			hideObject(v)
			hideLevelObject(v)
	
			if os.clock() - clock > 0.002 then
				task.wait()
				if not NameHider.Enabled then return end
				clock = os.clock()
	
				if vape.ThreadFix then
					setthreadidentity(8)
				end
			end
		end
	end
	
	NameHider = vape.Categories.Utility:CreateModule({
		Name = 'NameHider',
		Function = function(callback)
			if callback then
				table.clear(patterns)
				table.clear(plain)
				shortest = math.huge
				for _, player in playersService:GetPlayers() do
					if player == lplr or HideOthers.Enabled then
						addPlayerNames(player)
					end
				end
	
				fake = Replacement.Value ~= '' and Replacement.Value or 'hidden'
				for _, v in patterns do
					if fake:find(v) then
						fake = 'hidden'
						break
					end
				end
	
				local gameplayer = getGamePlayerClass()
				if gameplayer and not oldUsername then
					oldUsername, oldDisplayName = gameplayer.getUsername, gameplayer.getDisplayName
					oldClanTag, oldLevel = gameplayer.getClanTag, gameplayer.getLevel
					gameplayer.getUsername = function(self, ...)
						local player = self:getPlayer()
						return shouldHidePlayer(player) and fake or oldUsername(self, ...)
					end
					gameplayer.getDisplayName = function(self, ...)
						local player = self:getPlayer()
						return shouldHidePlayer(player) and fake or oldDisplayName(self, ...)
					end
					gameplayer.getClanTag = function(self, ...)
						return isLocal(self) and ChatTags.Enabled and '' or oldClanTag(self, ...)
					end
					gameplayer.getLevel = function(self, ...)
						local player = self:getPlayer()
						if player and (HideOthers.Enabled or (player.UserId == lplr.UserId and Level.Enabled)) then
							return -1
						end
						return oldLevel(self, ...)
					end
				end
	
				for _, v in {lplr:FindFirstChildOfClass('PlayerGui'), coreGui, gethui and gethui() or nil, lplr.Character} do
					watch(v)
				end
	
				NameHider:Clean(lplr.CharacterAdded:Connect(function(char)
					if NameHider.Enabled then
						watch(char)
					end
				end))
				NameHider:Clean(playersService.PlayerAdded:Connect(function()
					if HideOthers.Enabled then
						queueRefresh()
					end
				end))
				NameHider:Clean(playersService.PlayerRemoving:Connect(function()
					if HideOthers.Enabled then
						queueRefresh()
					end
				end))
			else
				local gameplayer = getGamePlayerClass()
				if oldUsername and gameplayer then
					gameplayer.getUsername, gameplayer.getDisplayName = oldUsername, oldDisplayName
					gameplayer.getClanTag, gameplayer.getLevel = oldClanTag, oldLevel
					oldUsername, oldDisplayName, oldClanTag, oldLevel = nil, nil, nil, nil
				end
				if vape.ThreadFix then
					setthreadidentity(8)
				end
	
				for i, v in watched do
					v:Disconnect()
				end
				table.clear(watched)
	
				for i, v in swapped do
					if i.Parent then
						writing = i
						i.Text = v
					end
				end
				writing = nil
				table.clear(swapped)
			end
		end,
		Tooltip = 'Replaces your username and display name everywhere it shows up on your screen',
		ExtraText = function()
			return Replacement.Value ~= '' and Replacement.Value or 'hidden'
		end
	})
	
	Replacement = NameHider:CreateTextBox({
		Name = 'Name',
		Function = queueRefresh,
		Default = 'hidden'
	})
	HideOthers = NameHider:CreateToggle({
		Name = 'Hide others',
		Function = queueRefresh,
		Tooltip = 'Hides every player\'s username and level'
	})
	ChatTags = NameHider:CreateToggle({
		Name = 'Hide chat tags',
		Tooltip = 'Hides your clan tag wherever it renders'
	})
	Level = NameHider:CreateToggle({
		Name = 'Hide level',
		Function = queueRefresh,
		Tooltip = 'Hides your level wherever it renders'
	})
	
end)

run(function()
	local RegionLock
	local Regions
	
	RegionLock = vape.Categories.Utility:CreateModule({
		Name = 'RegionLock',
		Function = function(callback)
			writefile('opmsix/profiles/regionlock.txt', tostring(callback))
			getgenv().regionLockActive = callback
		end,
		Tooltip = 'Only loads matches hosted in one of your selected server regions; settings carry over from the lobby'
	})
	
	Regions = RegionLock:CreateTextList({
		Name = 'Regions',
		Placeholder = 'SG / US / EU / SG-03',
		Function = function()
			for i, v in Regions.List do
				Regions.List[i] = v:gsub('%s+', ''):upper()
			end
			for i, v in Regions.ListEnabled do
				Regions.ListEnabled[i] = v:gsub('%s+', ''):upper()
			end
		end,
		Tooltip = 'Region code prefixes to accept, such as SG or SG-03'
	})
	
	task.spawn(function()
		repeat task.wait() until vape.Loaded or vape.Loaded == nil
		local last = isfile('opmsix/profiles/regionlock.json') and readfile('opmsix/profiles/regionlock.json')
		if vape.Loaded and last then
			local suc, res = pcall(httpService.JSONDecode, httpService, last)
			if suc and type(res) == 'table' then
				RegionLock:Load(res)
			end
		end
	
		repeat
			if vape.Loaded then
				local data = {}
				RegionLock:Save(data)
				data.RegionLock.Favorited = nil
				local encoded = httpService:JSONEncode(data.RegionLock)
				if encoded ~= last then
					last = encoded
					writefile('opmsix/profiles/regionlock.json', encoded)
				end
			end
			task.wait(1)
		until vape.Loaded == nil
	end)
end)

run(function()
	local SetEmote
	local Emote
	local track
	local billboard
	local moved
	
	local list, old = {}, {}
	for i, v in bedwars.EmoteMeta do
		if i ~= bedwars.EmoteType.NONE and v.name and not old[v.name] then
			old[v.name] = i
			table.insert(list, v.name)
		end
	end
	table.sort(list)
	
	local function cancelEmote()
		if moved then
			moved:Disconnect()
			moved = nil
		end
		if track then
			track:Stop()
			track:Destroy()
			track = nil
		end
		if billboard then
			billboard:Destroy()
			billboard = nil
		end
	
		local maid = bedwars.EmoteController and bedwars.EmoteController.emoteAudioMaids and bedwars.EmoteController.emoteAudioMaids[lplr.UserId]
		if maid then
			maid:DoCleaning()
		end
	
		if entitylib.isAlive and lplr.Character:GetAttribute('PlayingEmote') then
			lplr.Character:SetAttribute('PlayingEmote', nil)
		end
	end
	
	SetEmote = vape.Categories.Utility:CreateModule({
		Name = 'SetEmote',
		Function = function(callback)
			if callback then
				SetEmote:Toggle()
				if entitylib.isAlive then
					local emoteType = old[Emote.Value]
					local meta = bedwars.EmoteMeta[emoteType]
					if meta then
						lplr.Character:SetAttribute('PlayingEmote', emoteType)
						local playBeginSounds = bedwars.EmoteController and (bedwars.EmoteController.createEmoteBeginAudioPlayers or bedwars.EmoteController.playEmoteBeginSounds)
						if playBeginSounds then
							playBeginSounds(bedwars.EmoteController, emoteType, lplr)
						end
						local animation = meta.animation
						if not animation and meta.emoteDisplayType then
							local display = bedwars.EmoteDisplayMeta[meta.emoteDisplayType]
							animation = display and display.animation
						end
						if animation then
							track = lplr.Character.Humanoid:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(animation.type))
							track.Looped = animation.looped or false
							track:Play(nil, nil, animation.speed or 1)
						end
						if not meta.animation then
							local gui = Instance.new('BillboardGui')
							billboard = gui
							gui.Size = UDim2.fromScale(6, 2.5)
							gui.StudsOffset = Vector3.new(0, 2, 0)
							gui.AlwaysOnTop = true
							gui.Adornee = lplr.Character.Head
	
							local image = Instance.new('ImageLabel')
							image.AnchorPoint = Vector2.new(0.5, 1)
							image.Position = UDim2.fromScale(0.5, 1)
							image.Size = UDim2.fromScale(0, 0)
							image.Image = meta.image
							image.BackgroundTransparency = 1
							image.ImageTransparency = 1
							image.ScaleType = Enum.ScaleType.Fit
							image.Parent = gui
	
							gui.Parent = lplr.Character.Head
							tweenService:Create(image, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ImageTransparency = 0
							}):Play()
						end
						if meta.allowMovement then
							task.delay(6, cancelEmote)
						else
							moved = lplr.Character.Humanoid:GetPropertyChangedSignal('MoveDirection'):Connect(cancelEmote)
						end
					end
				end
			end
		end,
		Tooltip = 'Plays the selected emote on your character, other players can see it too'
	})
	
	Emote = SetEmote:CreateDropdown({
		Name = 'Emote',
		List = list,
		Default = 'nightmare'
	})
end)