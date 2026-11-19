--!strict
-- A 30-second Mini Room for a first visit. The server owns the clock.
-- The practice stars stay on this state. They are not a ballot.

local function parent(name: string): any
	local ok, loaded = pcall(function()
		local child = script.Parent.Parent:WaitForChild(name)
		return (require :: any)(child)
	end)
	if ok then
		return loaded
	end
	return (require :: any)("../" .. name)
end

local Config = parent("Config")

local Tutorial = {}

export type State = {
	active: boolean,
	startedAt: number,
	placed: boolean,
	placedAt: number,
	skipped: boolean,
	finished: boolean,
	line: string,
	stars: number,
}

function Tutorial.needed(profile: { [string]: any }?): boolean
	if type(profile) ~= "table" then
		return false
	end
	return profile.tutorialDone ~= true
end

function Tutorial.start(now: number): State
	return {
		active = true,
		startedAt = now,
		placed = false,
		placedAt = 0,
		skipped = false,
		finished = false,
		line = "",
		stars = 0,
	}
end

function Tutorial.pace(): { duration: number, placeBy: number, reactionBy: number }
	return {
		duration = Config.Tutorial.Duration,
		placeBy = Config.Tutorial.PlaceBy,
		reactionBy = Config.Tutorial.ReactionAt,
	}
end

function Tutorial.place(state: State, now: number): (boolean, string?)
	if state.finished or not state.active then
		return false, "The tutorial is over."
	end
	if state.placed then
		return true, "Already placed."
	end
	state.placed = true
	state.placedAt = now
	return true, "Placed."
end

function Tutorial.skip(state: State): (boolean, string?)
	if state.finished then
		return true, "Skipped."
	end
	state.skipped = true
	state.finished = true
	state.active = false
	state.line = ""
	state.stars = 0
	return true, "Skipped."
end

function Tutorial.tick(state: State, now: number)
	if not state.active or state.finished then
		return
	end
	local elapsed = now - state.startedAt
	if elapsed >= Config.Tutorial.ReactionAt then
		state.line = Config.Tutorial.Line
		state.stars = Config.Tutorial.Stars
	end
	if elapsed >= Config.Tutorial.Duration then
		state.finished = true
		state.active = false
	end
end

-- Read-only. `record` stays false so a caller cannot file this as a vote.
function Tutorial.view(state: State, now: number): { [string]: any }
	local elapsed = now - state.startedAt
	local show = state.skipped ~= true and state.finished ~= true and elapsed >= Config.Tutorial.ReactionAt
	local line = ""
	local stars = 0
	if show then
		line = Config.Tutorial.Line
		stars = Config.Tutorial.Stars
	end
	return {
		hint = if state.placed then "Nice. Auntie Roch is looking." else "Tap the big rug.",
		line = line,
		stars = stars,
		record = false,
		canPlace = state.active and not state.placed and not state.finished,
		canSkip = state.active and not state.finished,
		done = state.finished or not state.active,
		itemId = Config.Tutorial.ItemId,
	}
end

-- Marks the profile done. Leaves the ballot and the stat bag alone.
-- A client-sent star count is ignored.
function Tutorial.complete(
	profile: { [string]: any },
	state: State,
	_ballot: any,
	_stats: any,
	_clientStars: any
): { [string]: any }
	state.finished = true
	state.active = false
	if type(profile) == "table" then
		profile.tutorialDone = true
	end
	return {
		recorded = false,
		stars = 0,
	}
end

return Tutorial
