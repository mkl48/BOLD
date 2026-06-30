local ImageWrap = {}
ImageWrap.Wrap = {
	Start = "rbxthumb://type=Asset&id=",
	End = "&w=420&h=420"
}

function ImageWrap.WrapId(id: string)
	return ImageWrap.Wrap.Start .. id .. ImageWrap.Wrap.End
end

return ImageWrap