--!strict
-- Owns the round clock, joins, and the attributes the HUD reads.
-- Time left is stored as an absolute server time so clients can count down
-- between updates. GetServerTimeNow is the shared clock; os.clock stays with
-- the rate limiter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logic = Shared:WaitForChild("Logic")
local Replica = require(Shared:WaitForChild("Replica"))
local Round = require(Logic:WaitForChild("Round"))
local Themes = require(Shared:WaitForChild("Themes"))

local RoundService = {}

local state = Round.new(0)
local folder: Folder? = nil
local actionApi: any = nil
local lastKey = ""
local lastStamp = -1

local function stampDate()
	local raw = os.date("!*t")
	if type(raw) ~= "table" then
		return
	end
	local date = raw :: { year: number, month: number, day: number }
	Round.setDate(state, date.year, date.month, date.day)
end

local function apply(force: boolean)
	local roundFolder = folder
	if not roundFolder then
		return
	end
	local now = workspace:GetServerTimeNow()
	local view = Round.view(state, now)
	local key = table.concat({
		view.phase,
		tostring(view.timeLeft),
		view.themeId,
		tostring(view.tourIndex),
		tostring(view.tourCount),
		tostring(view.holding),
		view.seasonLabel,
		tostring(view.roundNumber),
	}, "|")
	if not force and key == lastKey then
		return
	end
	lastKey = key
	roundFolder:SetAttribute(Replica.Phase, view.phase)
	roundFolder:SetAttribute(Replica.TimeLeft, view.timeLeft)
	roundFolder:SetAttribute(Replica.EndsAt, view.endsAt)
	roundFolder:SetAttribute(Replica.Holding, view.holding)
	roundFolder:SetAttribute(Replica.ThemeName, view.themeName)
	roundFolder:SetAttribute(Replica.ThemeId, view.themeId)
	roundFolder:SetAttribute(Replica.RoundType, view.roundType)
	roundFolder:SetAttribute(Replica.TypeLabel, view.typeLabel)
	roundFolder:SetAttribute(Replica.TourIndex, view.tourIndex)
	roundFolder:SetAttribute(Replica.TourCount, view.tourCount)
	roundFolder:SetAttribute(Replica.SeasonLabel, view.seasonLabel)
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute(Replica.Role, Round.role(state, tostring(player.UserId)))
	end
end

local function onPlayer(player: Player)
	local now = workspace:GetServerTimeNow()
	local ok, msg = Round.join(state, tostring(player.UserId), now)
	if not ok then
		if msg == "This server is full." then
			player:Kick(msg)
		end
		return
	end
	apply(true)
end

local function onLeave(player: Player)
	local id = tostring(player.UserId)
	Round.leave(state, id, workspace:GetServerTimeNow())
	if actionApi and actionApi.forget then
		actionApi.forget(id)
	end
	apply(true)
end

function RoundService.state(): any
	return state
end

function RoundService.sync()
	apply(true)
end

function RoundService.init(services: any)
	folder = services.RoundFolder
	actionApi = services.Action
	local problems = Themes.audit()
	for _, problem in ipairs(problems) do
		warn("[Room Glow Up] " .. problem)
	end
	stampDate()
end

function RoundService.start()
	stampDate()
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	apply(true)
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(onLeave)
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		local second = math.floor(now)
		if second ~= lastStamp then
			lastStamp = second
			stampDate()
		end
		Round.tick(state, now)
		apply(false)
	end)
end

return RoundService
