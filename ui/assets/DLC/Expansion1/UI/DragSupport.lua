-- ===========================================================================
--	Drag and Drop support, common functions
-- ===========================================================================

-- LUA based struct
hstructure DropAreaStruct
	x		: number
	y		: number
	width	: number
	height	: number
	control	: table
	id		: number	-- (optional, extra info/ID)
end

-- ForgeUI defined structure (not used, as this is passed back from ForgeUI as type "table").
hstructure DragStruct
	GetFlags		: cfunction
	GetControl		: cfunction
	IsDown			: cfunction
	IsDrag			: cfunction
	IsDrop			: cfunction
	GetStartX		: cfunction
	GetStartY		: cfunction
	GetCoordX		: cfunction
	GetCoordY		: cfunction
	GetDeltaX		: cfunction
	GetDeltaY		: cfunction
	GetNormalX		: cfunction
	GetNormalY		: cfunction
	GetNormalDeltaX	: cfunction
	GetNormalDeltaY	: cfunction
end

m_dropAreas	= {};
m_dropOverlapRequired = 0.5;
DragSupport_defaultDropAreaTable = nil;

-- ===========================================================================
--
-- ===========================================================================
function SetDropOverlap( percent:number )
	m_dropOverlapRequired = percent;
end

-- ===========================================================================
--	Scan through droppable areas and return the one that was hit.
-- ===========================================================================
function GetDropArea( x:number, y:number, width:number, height:number )	
	local dropperArea:number = width * height;
	for i,dropArea in pairs(m_dropAreas) do
		local intersectArea:number = math.max(0, math.min(x+width, dropArea.x+dropArea.width) - math.max(x, dropArea.x)) * math.max(0, math.min(y+height, dropArea.y+dropArea.height) - math.max(y, dropArea.y));
		if (intersectArea/dropperArea) >= m_dropOverlapRequired then
			return dropArea;
		end
	end
	return nil;
end

-- ===========================================================================
--	Add a drop site for drag-n-drop.
--	control			ForgeUI control that can accept the drop
--	num				(optional) ID of the drop site
--	dropAreaTable	(optional) Groups of drop areas each use their own table, 
--					to track droppable locations.  If no table is specified, 
--					a single, default, table is used.
-- ===========================================================================
function AddDropArea( control:table, num:number, dropAreaTable:table )
	if num == nil then num = -1; end
	if control==nil then
		error("Attempted to add a NIL drop area to #"..tostring(num));
		return;
	end
	-- Create a default table if one isn't defined.
	if dropAreaTable == nil then
		if DragSupport_defaultDropAreaTable == nil then DragSupport_defaultDropAreaTable = {}; end
		dropAreaTable = DragSupport_defaultDropAreaTable;
	end

	local x,y = control:GetScreenOffset();
	dropAreaTable[num] = hmake DropAreaStruct {
		x		= x,
		y		= y,
		width	= control:GetSizeX(),
		height	= control:GetSizeY(),
		control	= control,
		id		= num
	};
end

print("DragSupport loaded!");