local Hooks = { _Registry = {} }

function Hooks:On(eventName: string, callback: (...any) -> ())
	if not self._Registry[eventName] then
		self._Registry[eventName] = {}
	end
	table.insert(self._Registry[eventName], callback)
end

function Hooks:Fire(eventName: string, ...)
	if self._Registry[eventName] then
		for _, callback in pairs(self._Registry[eventName]) do
			task.spawn(callback, ...)
		end
	end
end

return Hooks