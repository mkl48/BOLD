-- Bold
-- _Utility/Id
-- Plinko Labs

local HttpService = game:GetService("HttpService")

local Id = {}

function Id.Generate(): string
	return HttpService:GenerateGUID(false)
end

return Id