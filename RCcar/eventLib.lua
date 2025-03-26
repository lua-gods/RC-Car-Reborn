---@class EventLib
local EventLib = {}
EventLib.__index = EventLib

function EventLib.new() return setmetatable({}, EventLib) end

EventLib.newEvent = EventLib.new

function EventLib:register(func, name) self[#self + 1] = {name or func, func} end

function EventLib:clear() for key in pairs(self) do self[key] = nil end end

function EventLib:remove(name) for id, value in pairs(self) do if value[1] == name then self[id] = nil end end end

function EventLib:getRegisteredCount(name)
	local c = 0
	if not name then return #self end
	for id, value in pairs(self) do if value[1] == name then c = c + 1 end end
	return c
end

function EventLib:__len() return #self end

function EventLib:__call(...)
	local flush = {}
	for _, func in pairs(self) do flush[#flush + 1] = {func(...)} end
	return flush
end

---@type fun(self: EventLib, ...: any): any[]
EventLib.invoke = EventLib.__call

function EventLib.__index(t, i) return rawget(t, i) or rawget(t, i:upper()) or EventLib[i] end

function EventLib.__newindex(t, i, v) rawset(t, type(i) == "string" and t[i:upper()] or i, v) end

return EventLib
