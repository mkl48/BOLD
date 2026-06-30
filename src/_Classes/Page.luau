local InsertService = game:GetService("InsertService")

local _Classes = script.Parent
local _Packages = _Classes.Parent._Packages

local Promise = require(_Packages.Promise)

local function Inq(prompt: string, pg: number)
	local PagePromise = Promise.new(function(resolve, reject)
		local success, result = pcall(function()
			return unpack(InsertService:GetFreeDecalsAsync(prompt, pg))
		end)

		if success then
			resolve(result)
			return
		end

		reject(result)
	end)

	return PagePromise:awaitValue()
end

local function applyCurrent(page: {any})
	return {
		TotalContents = page.TotalCount or 0,
		Contents = page.Results or {},
		CurrentPage = page.CurrentStartIndex or 0,
	}
end

local Page = {}
Page.__index = Page

function Page.new(prompt: string)
	local self = setmetatable({}, Page)

	self._prompt = prompt
	self._current = {
		PageNumber = 0,
		TotalContents = 0,
		Contents = {},
	}

	local PageData = Inq(self._prompt, 0)
	self._current = applyCurrent(PageData)

	return self
end

function Page:Next()
	local PageData = Inq(self._prompt, self._current.CurrentPage + 1)
	self._current = applyCurrent(PageData)
	return self._current
end

function Page:Previous()
	local targetPage = math.max(0, self._current.CurrentPage - 1)
	local PageData = Inq(self._prompt, targetPage)
	self._current = applyCurrent(PageData)
	return self._current
end

function Page:GetCurrent()
	return self._current
end

return Page