local InsertService = game:GetService("InsertService")

local _Patterns = script.Parent
local _Classes = _Patterns.Parent._Classes

local PageClass = require(_Classes.Page)
local Types = require(_Patterns.Parent.Types)

local ImageSearch = {}
ImageSearch.__index = ImageSearch

function ImageSearch.InquireTopic(topic: string)
	local self = setmetatable({}, ImageSearch) 

	self._topic = topic
	self._page = PageClass.new(topic)

	return self
end

function ImageSearch:Next()
	return self._page:Next()
end

function ImageSearch:Previous()
	return self._page:Previous()
end

function ImageSearch:GetCurrent()
	return self._page:GetCurrent()
end

function ImageSearch:ForContentsInPage(index: number, callback: (Types.ImageAsset) -> ()): ()
	local Current = self._page._current

	for i = index, #Current.Contents do
		if Current.Contents[i] then
			callback(Current.Contents[i])
		end
	end

	return self
end

return ImageSearch