local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PlayerDataHandler = {}

local ProfileTemplate = require(script.Parent.ProfileTemplate)

local ProfileService = require(script.Parent.ProfileService)
local PROD_PLAYERPROFILE = "PROD-PlayerProfile"
local BETA_PLAYERPROFILE = "PlayerProfile"

local isProd = not RunService:IsStudio()

local PlayerStore = ProfileService.GetProfileStore(
	if isProd then PROD_PLAYERPROFILE else BETA_PLAYERPROFILE,
	ProfileTemplate
)

local Profiles = {}

local function PlayerAdded(player: Player)
	if script:GetAttribute("mock") and RunService:IsStudio() then
		PlayerStore = PlayerStore.Mock
	end
	
	local profile = PlayerStore:LoadProfileAsync(`{player.UserId}`)
	
	if profile ~= nil then
		profile:AddUserId(player.UserId) 
		profile:Reconcile()

		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick(`Profile session end - Please rejoin`)
		end)
		
		if player.Parent == Players then
			Profiles[player] = profile
		else
			profile:Release()
		end
	else
		player:Kick("Profile load fail - Please rejoin")
	end
end

function PlayerDataHandler:GetProfileTemplate()
	return ProfileTemplate
end

local function getProfile(player: Player)
	return Profiles[player]
end

local WAIT_DURATION = 10000

function PlayerDataHandler:GetAsync(player: Player, key: string)
	local now = DateTime.now().UnixTimestampMillis
	while DateTime.now().UnixTimestampMillis - now < WAIT_DURATION do
		if getProfile(player) ~= nil then
			break
		end
		task.wait()
	end

	local profile = getProfile(player)
	assert(profile.Data, `Data does not exist for player {player}`)
	assert(profile.Data[key] ~= nil, `Data does not exist for key {key}`)

	return profile.Data[key]
end

function PlayerDataHandler:Set(player: Player, key: string, value: any)
	local profile = getProfile(player)
	assert(profile.Data[key] ~= nil, `Data does not exist for key {key}`)
	
	assert(type(profile.Data[key]) == type(value), `Value {value} of type {type(value)} is not of expected type {type(profile.Data[key])}`)

	profile.Data[key] = value
end

for _, player in Players:GetPlayers() do
	task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:Release()
	end
end)

return PlayerDataHandler
