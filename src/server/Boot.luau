--!strict
-- Starts services so one failure cannot stop the others from loading.
local Boot = {}

function Boot.step(label: string, fn: () -> ())
	local ok, err = xpcall(function(): string?
		fn()
		return nil
	end, debug.traceback)
	if not ok then
		warn("[Boot] " .. label .. " failed:\n" .. tostring(err))
	end
end

function Boot.run(services: { [string]: any }, initOrder: { string }, startOrder: { string })
	for _, name in ipairs(initOrder) do
		local svc = services[name]
		if type(svc) == "table" and type(svc.init) == "function" then
			Boot.step(name .. ".init", function()
				svc.init(services)
			end)
		end
	end
	for _, name in ipairs(startOrder) do
		local svc = services[name]
		if type(svc) == "table" and type(svc.start) == "function" then
			Boot.step(name .. ".start", function()
				svc.start()
			end)
		end
	end
end

return Boot
