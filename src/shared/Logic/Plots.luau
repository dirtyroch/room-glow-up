--!strict
-- Assigns one plot per player and frees it when they leave.
-- The lowest free index is reused so a full server of 10 never fragments.

local Plots = {}

export type State = {
	count: number,
	owner: { [number]: string },
	plotOf: { [string]: number },
}

function Plots.create(count: number): State
	return {
		count = count,
		owner = {},
		plotOf = {},
	}
end

function Plots.plotOf(state: State, id: string): number?
	return state.plotOf[id]
end

function Plots.owner(state: State, index: number): string?
	return state.owner[index]
end

function Plots.assign(state: State, id: string): number?
	local held = state.plotOf[id]
	if held then
		return held
	end
	for index = 1, state.count do
		if state.owner[index] == nil then
			state.owner[index] = id
			state.plotOf[id] = index
			return index
		end
	end
	return nil
end

function Plots.release(state: State, id: string): number?
	local index = state.plotOf[id]
	if not index then
		return nil
	end
	state.plotOf[id] = nil
	state.owner[index] = nil
	return index
end

return Plots
