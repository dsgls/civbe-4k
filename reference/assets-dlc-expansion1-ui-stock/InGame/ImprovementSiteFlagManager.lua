-- Improvement Site Flag Manager
-------------------------------------------------
include( "SupportFunctions" );
include( "IconSupport" );
include( "InstanceManager" );

local g_SelectableSiteFlagInstanceManager = InstanceManager:new( "ImprovementSiteFlag", "Anchor", Controls.ImprovementSiteFlags );
local g_SettlementFlagInstanceManager = InstanceManager:new( "SettlementFlag", "Anchor", Controls.SettlementFlags );

local g_MasterListByPlayer = {};
local g_MasterListByPlot = {};

local g_DimAlpha = 0.45;
local g_DimAirAlpha = 0.6;

local ALPHA_BANNER_IDLE	= 0.6;
local ALPHA_BANNER_OVER	= 0.95;

local FLAGTYPE_SELECTABLE_SITE = 0;
local FLAGTYPE_SETTLEMENT = 2;

------------------------------------------------------
-- Convert an Engine FOW state to the Game's
function EngineFOWStateToGame(eState : number)
	if (eState == 1) then
		return FogOfWarModeTypes.FOGOFWARMODE_NOVIS;
	else
		if (eState == 2) then
			return FogOfWarModeTypes.FOGOFWARMODE_OFF;
		end
	end
	
	return FogOfWarModeTypes.FOGOFWARMODE_UNEXPLORED;
end

hstructure ImprovementSiteFlagMeta
	-- Pointer back to itself.  Required.
	__index : ImprovementSiteFlagMeta

	new								: ifunction;
	destroy							: ifunction;
	Initialize						: ifunction;
	SetColor						: ifunction;
	SetType							: ifunction;
	SetFogState						: ifunction;
	SetHide							: ifunction;
	UpdateVisibility				: ifunction;
	UpdateHealth					: ifunction;
	UpdateSelected					: ifunction;
	UpdateName						: ifunction;
	SetFlash						: ifunction;
	SetDim							: ifunction;
	OverrideDim						: ifunction;
	UpdateDimmedState				: ifunction;
	SetPosition						: ifunction;
	UpdateOffset					: ifunction;
end

hstructure ImprovementSiteFlag
	meta							: ImprovementSiteFlagMeta;

	m_InstanceManager				: table;
    m_Instance						: table;
    
    m_FlagType						: number;
    m_IsSelected					: boolean;
    m_IsCurrentlyVisible			: boolean;
	m_IsForceHide					: boolean;
    m_IsDimmed						: boolean;
	m_OverrideDim					: boolean;
	m_FogState						: number;
    m_Health						: number;
    
    m_Player						: table;
    m_Plot							: table;
end

-- Create one instance of the meta object
-- And bind it as Vector2 global variable.
ImprovementSiteFlag = hmake ImprovementSiteFlagMeta{};

-- Link its __index to itself
ImprovementSiteFlag.__index = ImprovementSiteFlag;

    ------------------------------------------------------------------
    -- constructor
    ------------------------------------------------------------------
function ImprovementSiteFlag.new( self : ImprovementSiteFlagMeta, pPlot : table, flagType: number, fogState : number )
    local o = hmake ImprovementSiteFlag { };
    setmetatable( o, self );
        
    if( playerID ~= -1 and pPlot ~= nil )
    then		
		if (flagType == FLAGTYPE_SELECTABLE_SITE) then
			o.m_InstanceManager = g_SelectableSiteFlagInstanceManager;
		elseif (flagType == FLAGTYPE_SETTLEMENT) then
			o.m_InstanceManager = g_SettlementFlagInstanceManager;				
		end
		if (o.m_InstanceManager ~= nil) then
			o.m_Instance = o.m_InstanceManager:GetInstance();
			local bSucess = o:Initialize( pPlot, flagType, fogState );
			if (bSucess == true) then
				---------------------------------------------------------
				-- build the table for the owner and store the flag
				local eOwnerID = pPlot:GetOwner();
				local playerTable = g_MasterListByPlayer[ eOwnerID ];
				if playerTable == nil 
				then
					playerTable = {};
					g_MasterListByPlayer[ eOwnerID ] = playerTable
				end
				g_MasterListByPlayer[ eOwnerID ][ pPlot:GetPlotIndex() ] = o;
				g_MasterListByPlot[ pPlot:GetPlotIndex() ] = o;
				ResizeBanner(o);
			else
				o:destroy();
			end
		end
				            
    end
        
    return o;
end
     
            
------------------------------------------------------------------
-- constructor
------------------------------------------------------------------
function ImprovementSiteFlag.Initialize( o : ImprovementSiteFlag, pPlot : table, flagType: number, fogState : number )
    o.m_Plot = pPlot;
                
    o.m_IsSelected = false;
    o.m_IsCurrentlyVisible = false;
	o.m_IsForceHide = false;
    o.m_IsDimmed = false;
	o.m_OverrideDim = false;
	o.m_FogState = FogOfWarModeTypes.FOGOFWARMODE_UNEXPLORED;
    o.m_Health = 0;
	o.m_FlagType = flagType;

    if( pPlot == nil )
    then
        print( "No valid plot for flag" );
        return false;
    end
           
	local ePlayer = pPlot:GetOwner()
	if (ePlayer < 0) then
        print( "Plot is not owned" );
        return false;
	end
    o.m_Player = Players[ ePlayer ];
    ---------------------------------------------------------
    -- Hook up the button
    local pActivePlayer = Players[Game.GetActivePlayer()];
    local eActiveTeam = pActivePlayer:GetTeam();
    local eFlagTeam = o.m_Player:GetTeam();
        			
	local controlTable = o.m_Instance;
	if (o.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		if (o.m_Player:IsHuman()) then
			controlTable.NormalButton:SetVoid1( pPlot:GetPlotIndex() );
			controlTable.NormalButton:SetVoid2( 0 );
			controlTable.NormalButton:RegisterCallback( Mouse.eLClick, FlagClicked );
			controlTable.NormalButton:RegisterCallback( Mouse.eMouseEnter, FlagEnter );
			controlTable.NormalButton:RegisterCallback( Mouse.eMouseExit, FlagExit );
            
			controlTable.HealthBarButton:SetVoid1( pPlot:GetPlotIndex() );
			controlTable.HealthBarButton:SetVoid2( 0 );
			controlTable.HealthBarButton:RegisterCallback( Mouse.eLClick, FlagClicked );
			controlTable.HealthBarButton:RegisterCallback( Mouse.eMouseEnter, FlagEnter );
			controlTable.HealthBarButton:RegisterCallback( Mouse.eMouseExit, FlagExit );
		end            		
		
		if( eActiveTeam == eFlagTeam ) then
			controlTable.NormalButton:SetDisabled( false );
			controlTable.NormalButton:SetConsumeMouseOver( true );

			controlTable.HealthBarButton:SetDisabled( false );
			controlTable.HealthBarButton:SetConsumeMouseOver( true );
		            
		else
			controlTable.NormalButton:SetDisabled( true );
			controlTable.NormalButton:SetConsumeMouseOver( false );
			controlTable.HealthBarButton:SetDisabled( true );
			controlTable.HealthBarButton:SetConsumeMouseOver( false );
		end
	else
		if (o.m_FlagType== FLAGTYPE_SETTLEMENT) then
			if (o.m_Player:IsHuman()) then
				controlTable.SettlementButton:RegisterMouseEnterCallback( function() OnMouseEnterSettlementBanner(controlTable.Anchor, 0); end );
				controlTable.SettlementButton:RegisterMouseExitCallback( function()	OnMouseExitSettlementBanner(controlTable.Anchor, 0); end  );
			end

			if( eActiveTeam == eFlagTeam ) then
				controlTable.SettlementButton:SetDisabled( false );
				controlTable.SettlementButton:SetConsumeMouseOver( true );		            
			else
				controlTable.SettlementButton:SetDisabled( true );
				controlTable.SettlementButton:SetConsumeMouseOver( false );
			end
		end
	end

    ---------------------------------------------------------
    -- update all the info
    o:UpdateName();
    o:SetColor();
    o:SetType();
    o:UpdateHealth();
    o:UpdateSelected();
    o:SetFogState( fogState );
    o:UpdateVisibility();
        
	RefreshBanner(o);

    ---------------------------------------------------------
    -- Set the world position
    local worldPosX, worldPosY, worldPosZ = GridToWorld( pPlot:GetX(), pPlot:GetY() );
	if (o.m_FlagType == FLAGTYPE_SETTLEMENT) then
	    worldPosZ = worldPosZ + 55;
	else
	    worldPosZ = worldPosZ + 35;
	end
        
    o:SetPosition( worldPosX, worldPosY, worldPosZ );        
	return true;
end
        
           
    ------------------------------------------------------------------
    ------------------------------------------------------------------
function ImprovementSiteFlag.destroy( self : ImprovementSiteFlag )
    if( self.m_InstanceManager ~= nil )
    then           
        self:UpdateSelected( false );
                        		    
		if (self.m_Instance ~= nil) then
			self.m_InstanceManager:ReleaseInstance( self.m_Instance );
		end
		if (self.m_Player ~= nil and self.m_Plot ~= nil) then
			g_MasterListByPlayer[ self.m_Player:GetID() ][ self.m_Plot:GetPlotIndex() ] = nil;
			g_MasterListByPlot[ self.m_Plot:GetPlotIndex() ] = nil;
		end
    end
end
    
    -----------------------------------------------------------------
    ------------------------------------------------------------------
function ImprovementSiteFlag.SetPosition( self : ImprovementSiteFlag, posX : number, posY : number, posZ : number )
    
	self:UpdateOffset();
           
	self.m_Instance.Anchor:SetWorldPositionVal( posX, posY, posZ );
                
end



------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.UpdateOffset( self : ImprovementSiteFlag )
	        
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
	    local offset = Vector2( 0, 0 );	        

	    self.m_Instance.FlagShadow:SetOffset( offset );
	end
end

------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.SetColor( self : ImprovementSiteFlag )
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		local pSite = self.m_Plot:GetPlotStrategicSite();
		if (pSite ~= nil) then
			local iconColor, flagColor = self.m_Player:GetPlayerColors();
        
			self.m_Instance.FlagBase:SetColor( RGBAObjectToABGRHex(iconColor) );
			self.m_Instance.FlagBaseOutline:SetColor( RGBAObjectToABGRHex(flagColor) );
			self.m_Instance.FlagIcon:SetColor( RGBAObjectToABGRHex(iconColor) );
			self.m_Instance.NormalSelect:SetColor( RGBAObjectToABGRHex(iconColor) );
			self.m_Instance.HealthBarSelect:SetColor( RGBAObjectToABGRHex(iconColor) );
		end		
	else
		if (self.m_FlagType == FLAGTYPE_SETTLEMENT) then
			local primaryColorRaw, secondaryColorRaw = self.m_Player:GetPlayerColors();
        			
			local controls = self.m_Instance;
			local primaryColorAlphaedRaw	= { x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 0.5 };
			local primaryColor 	 		= RGBAObjectToABGRHex( primaryColorRaw );
			local secondaryColor 		= RGBAObjectToABGRHex( secondaryColorRaw );	
			local primaryColorAlphaed 	= RGBAObjectToABGRHex( primaryColorAlphaedRaw );

			controls.SettlementBannerBackground:SetColor(primaryColor);
			controls.SettlementBannerLeftBackground:SetColor(primaryColor);
			-- controls.SettlementBannerBackgroundIcon:SetColor(secondaryColor);

			controls.SettlementBannerButtonBase:SetColor( secondaryColor );
			controls.SettlementBannerButtonBaseLeft:SetColor( secondaryColor );
			
			-- controls.SettlementBannerBGLeftHL:SetColor( secondaryColor );

			local textColorRaw 		= {x = primaryColorRaw.x, y = primaryColorRaw.y, z = primaryColorRaw.z, w = 1  };
			local textColor 		= RGBAObjectToABGRHex( textColorRaw );
	
			controls.Name:SetColor( textColor, 0);
			controls.Population:SetColor( primaryColor, 0 );

		end		
	end
end



------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.SetType( self : ImprovementSiteFlag )
            
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		local pSite = self.m_Plot:GetPlotStrategicSite();
		if (pSite ~= nil) then

			if (self.m_Plot:HasImprovement()) then
				local iImprovementID = self.m_Plot:GetImprovementType();
				local pImprovementInfo = GameInfo.Improvements[iImprovementID];
				if (pImprovementInfo ~= nil) then		 
 					local textureOffset, textureSheet = IconLookup( pImprovementInfo.FlagIconIndex, 45, pImprovementInfo.FlagIconAtlas );
					self.m_Instance.FlagIcon:SetTexture( textureSheet );
					self.m_Instance.FlagIconShadow:SetTexture( textureSheet );
					self.m_Instance.FlagIcon:SetTextureOffset( textureOffset );
					self.m_Instance.FlagIconShadow:SetTextureOffset( textureOffset );
				end
			end
		end
	end

end

------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.SetFogState( self : ImprovementSiteFlag, fogState : number )
    if( fogState ~= FogOfWarModeTypes.FOGOFWARMODE_OFF ) then
        self:SetHide( true );
    else
        self:SetHide( false );
    end
        
    self.m_FogState = fogState;
end
    
------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.SetHide( self : ImprovementSiteFlag, bHide : boolean )
	self.m_IsCurrentlyVisible = not bHide;
	self:UpdateVisibility();
end
    
------------------------------------------------------------
------------------------------------------------------------
function ImprovementSiteFlag.UpdateVisibility( self : ImprovementSiteFlag )

	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		local pSite = self.m_Plot:GetPlotStrategicSite();
		if (pSite ~= nil) then
			local bVisible = self.m_IsCurrentlyVisible and not self.m_IsForceHide;
    		self.m_Instance.Anchor:SetHide(not bVisible);
		end
	else
		if (self.m_FlagType == FLAGTYPE_SETTLEMENT) then
			local bVisible = self.m_IsCurrentlyVisible and not self.m_IsForceHide;
    		self.m_Instance.Anchor:SetHide(not bVisible);
		end
	end

end
     
------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.UpdateHealth( self : ImprovementSiteFlag )
    
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		local pSite = self.m_Plot:GetPlotStrategicSite();
		if (pSite == nil) then
			return;
		end	
			
		local healthPercent = math.max( math.min( (pSite:GetMaxHitPoints() - pSite:GetDamage()) / pSite:GetMaxHitPoints(), 1 ), 0 );
    
		-- going to damaged state
		if( healthPercent < 1 )
		then
			-- show the bar and the button anim
			self.m_Instance.HealthBarBG:SetHide( false );
			self.m_Instance.HealthBar:SetHide( false );
			self.m_Instance.HealthBarButton:SetHide( false );
                    
			-- hide the normal button
			self.m_Instance.NormalButton:SetHide( true );
            
			-- handle the selection indicator    
			if( self.m_IsSelected )
			then
				self.m_Instance.NormalSelect:SetHide( true );
				self.m_Instance.HealthBarSelect:SetHide( false );
			end
                    
			if( healthPercent > 0.66 )
			then
				self.m_Instance.HealthBar:SetFGColor( 0xff00ff00 );
			elseif( healthPercent > 0.33 )
			then
				self.m_Instance.HealthBar:SetFGColor( 0xff00ffff );
			else
				self.m_Instance.HealthBar:SetFGColor( 0xff0000ff );
			end
            
		--------------------------------------------------------------------    
		-- going to full health
		else
			self.m_Instance.HealthBar:SetFGColor( 0xff00ff00 );
            
			-- hide the bar and the button anim
			self.m_Instance.HealthBarBG:SetHide( true );
			self.m_Instance.HealthBar:SetHide( true );
			self.m_Instance.HealthBarButton:SetHide( true );
        
			-- show the normal button
			self.m_Instance.NormalButton:SetHide( false );
        
			-- handle the selection indicator    
			if( self.m_IsSelected )
			then
				self.m_Instance.NormalSelect:SetHide( false );
				self.m_Instance.HealthBarSelect:SetHide( true );
			end
		end
        
		self.m_Instance.HealthBar:SetPercent( healthPercent );
		self.m_Health = healthPercent;
	end
end
   
------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.UpdateSelected( self : ImprovementSiteFlag, isSelected : boolean )
    self.m_IsSelected = isSelected; 
        
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		if( self.m_Health >= 1 )
		then
			self.m_Instance.NormalSelect:SetHide( not self.m_IsSelected );
			self.m_Instance.HealthBarSelect:SetHide( true );
		else
			self.m_Instance.HealthBarSelect:SetHide( not self.m_IsSelected );
			self.m_Instance.NormalSelect:SetHide( true );
		end
	end
	                
    self:OverrideDim( self.m_IsSelected );
        
end
    
-------------------------------------------------
-- Change the width of the banner so it looks good with the length of the name
-------------------------------------------------
function ResizeBanner(self : ImprovementSiteFlag)

	if (self.m_FlagType == FLAGTYPE_SETTLEMENT) then
		local controls : table = self.m_Instance;
		controls.NameStack:CalculateSize();
		controls.NameStack:ReprocessAnchoring();

		local isStation = false;
		local iWidth = controls.NameStack:GetSizeX();	

		-- If this control doesn't exist, then we're using the active player banner as opposed to the other player.
		-- NOTE:	There are rare instances when the active player will change (hotseat, autoplay) so just checking
		--			the active player is not good enough.
		if (controls.SettlementBannerButtonGlow ~= nil) then
			iWidth = iWidth + 10;	-- Offset for human player's banners
			if(iWidth < 130) then
				iWidth = 130		-- Set minimum witdth for banner so it looks correct with the life bar
			end
			-- controls.SettlementBannerBackgroundIcon:SetSizeX(iWidth);
			controls.SettlementBannerButtonGlow:SetSizeX(iWidth);
			controls.SettlementBannerButtonBase:SetSizeX(iWidth);
		
		else

			iWidth = iWidth + 10
		
			if(iWidth < 130) then
				iWidth = 130		-- Set minimum witdth for banner so it looks correct with the life bar
			end
		
			controls.SettlementBannerButtonBase:SetSizeX(iWidth);
		end

		if ( controls.SettlementBannerShadow ~= nil ) then
			controls.SettlementBannerShadow:SetSizeX( iWidth + 40 );
		end

		controls.SettlementButton:SetSizeX(iWidth);
		controls.SettlementBannerBackground:SetSizeX(iWidth);
		-- controls.SettlementBannerBackgroundHL:SetSizeX(iWidth);
	
		controls.SettlementButton:ReprocessAnchoring();
		controls.NameStack:ReprocessAnchoring();
	end
end

------------------------------------------------------------------
------------------------------------------------------------------
function RefreshBanner(self : ImprovementSiteFlag)
	if (self.m_FlagType == FLAGTYPE_SETTLEMENT) then
		local population = math.floor( Game.GetEarthlingSettlementPopulation(self.m_Plot) );
		self.m_Instance.Population:SetText(population);
	end
end

------------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.UpdateName( self : ImprovementSiteFlag )
            
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		local pSite = self.m_Plot:GetPlotStrategicSite();
		if (pSite == nil) then
			return;
		end	

		-- The type of site is the Improvement type
		if (self.m_Plot:HasImprovement()) then
			local iImprovementID = self.m_Plot:GetImprovementType();
			local pImprovementInfo = GameInfo.Improvements[iImprovementID];
			if (pImprovementInfo ~= nil) then
				local name = Locale.ConvertTextKey( pImprovementInfo.Description );
				self.m_Instance.FlagIcon:SetToolTipString( name );
			end
		end
	end
			
end

-----------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.SetFlash( self : ImprovementSiteFlag, bFlashOn : boolean )
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		self.m_Instance.FlagIconAnim:SetToBeginning();
        
		if( bFlashOn ) then
			self.m_Instance.FlagIconAnim:Play();
		end
	end
	        
end
    
    
-----------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.SetDim( self : ImprovementSiteFlag, bDim : boolean )
	self.m_IsDimmed = bDim;
    self:UpdateDimmedState();
end
   
-----------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.OverrideDim( self : ImprovementSiteFlag, bOverride : boolean )
	self.m_OverrideDim = bOverride;
    self:UpdateDimmedState();
end
    
    
-----------------------------------------------------------------
------------------------------------------------------------------
function ImprovementSiteFlag.UpdateDimmedState( self : ImprovementSiteFlag )
	if (self.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
		if( self.m_IsDimmed and not self.m_OverrideDim ) then
			self.m_Instance.Anchor:SetAlpha( g_DimAlpha );
			self.m_Instance.HealthBar:SetAlpha( 1.0 / g_DimAlpha ); -- Health bar doesn't get dimmed (Hacky I know)            
		else
			self.m_Instance.Anchor:SetAlpha( 1.0 );
			self.m_Instance.HealthBar:SetAlpha( 1.0 );            
		end
	end
end


-------------------------------------------------
-- Do Improvement Created
-------------------------------------------------

function DoImprovementCreated( gridPosX, gridPosY )
	
	local pPlot : table = Map.GetPlot(gridPosX, gridPosY);
	if (pPlot ~= nil) then
		-- Now we have to figure out if the improvement is a 'site' and if it needs a flag (it will be marked as selectable)
		local iImprovementType = pPlot:GetImprovementType();
		if (iImprovementType ~= -1) then
			local pImprovementInfo = GameInfo.Improvements[iImprovementType];		-- We may want to cache the known 'selectable' improvement types, rather than looking them up each time.
			if (pImprovementInfo ~= nil) then		 
				if (pImprovementInfo.Selectable == true) then
					-- Create a Selectable Site Flag for it.
					local playerID : number = pPlot:GetOwner();		        
					local fogState : number = pPlot:GetActiveFogOfWarMode();
					ImprovementSiteFlag:new( pPlot, FLAGTYPE_SELECTABLE_SITE, fogState );	
				elseif (pImprovementInfo.Type == "IMPROVEMENT_EARTHLING_SETTLEMENT") then
					-- Create Settlement Site Flag for it.
					local playerID : number = pPlot:GetOwner();		        
					local fogState : number = pPlot:GetActiveFogOfWarMode();
					ImprovementSiteFlag:new( pPlot, FLAGTYPE_SETTLEMENT, fogState );
				end
			end
		end
	end
end
    
-------------------------------------------------
-- On Improvement Created
-------------------------------------------------

function OnImprovementCreated( hexI, hexJ, eCultureType, eContinentType, ePlayerType, iImprovementArtType, iRawResourceArtType, eEra, eState, eLayer )
	
	local gridPosX, gridPosY = ToGridFromHex( hexI, hexJ );
	DoImprovementCreated( gridPosX, gridPosY );
end
Events.SerialEventImprovementCreated.Add( OnImprovementCreated );

-------------------------------------------------
-- On Unit Destroyed
-------------------------------------------------
function OHexFOWStateChanged( hexVec, eState, bSetAll )
	-- The input is the 'engine' FOW state, change it to the Game's version
	local eFOWState = EngineFOWStateToGame(eState);
	if (bSetAll == true) then
		for i, flag in ipairs( g_MasterListByPlot ) do
			if (flag ~= nil) then
				flat:SetFogState( eFOWState );
			end				
		end
	else		
		local gridPosX, gridPosY = ToGridFromHex( hexVec.x, hexVec.y );
		local pPlot = Map.GetPlot(gridPosX, gridPosY);
		if (pPlot ~= nil) then		
			local flag = g_MasterListByPlot[ pPlot:GetPlotIndex() ];
			if (flag ~= nil) then
				flag:SetFogState( eFOWState );
			end
		end
	end
end
Events.HexFOWStateChanged.Add( OHexFOWStateChanged );


-------------------------------------------------
-- On Improvement Destroyed
-------------------------------------------------
function OnSerialEventImprovementDestroyed( hexI, hexJ )
	local gridPosX, gridPosY = ToGridFromHex( hexI, hexJ );
	local pPlot = Map.GetPlot(gridPosX, gridPosY);
	if (pPlot ~= nil) then
		if (pPlot:GetPlotStrategicSite() == nil) then
			local flag = g_MasterListByPlot[ pPlot:GetPlotIndex() ];
			if (flag ~= nil) then
				flag:destroy();
			end
		end
	end
end
Events.SerialEventImprovementDestroyed.Add( OnSerialEventImprovementDestroyed );


-------------------------------------------------
-- On Flag Clicked
-------------------------------------------------
function FlagClicked( plotIndex )
	local pPlot = Map.GetPlotByIndex(plotIndex);
	if (pPlot ~= nil) then
		Events.ImprovementSiteFlagSelected(pPlot:GetX(), pPlot:GetY());
	end
end


-------------------------------------------------
function FlagEnter( plotIndex )
	local flag = g_MasterListByPlot[ plotIndex ];
	if( flag ~= nil ) then        
		flag:OverrideDim( true );
	end
end

-------------------------------------------------
function FlagExit( plotIndex )
	local flag = g_MasterListByPlot[ plotIndex ];
	if( flag ~= nil ) then                
		flag:OverrideDim( flag.m_IsSelected );
	end
end

-------------------------------------------------
-------------------------------------------------
function OnInfoPaneDirty()

	local eImprovement = UI.GetSelectedImprovementType();
	if (eImprovement ~= nil and eImprovement ~= -1) then

		local x = UI.GetSelectedImprovementPlotX();
		local y = UI.GetSelectedImprovementPlotY();

		local pPlot = Map.GetPlot(x, y);
		if (pPlot ~= nil) then    
			local flag = g_MasterListByPlot[ pPlot:GetPlotIndex() ];
			if (flag  ~= nil) then
				
			end
		end
	end
end
Events.SerialEventUnitInfoDirty.Add(OnInfoPaneDirty);


--------------------------------------------------------------------------------
-- Damage has changed
--------------------------------------------------------------------------------
function OnSetDamage( playerID, plotIndex, iDamage, iPreviousDamage )
	if (g_MasterListByPlot ~= nil) then
		local flag = g_MasterListByPlot[ plotIndex ];
		if (flag ~= nil) then
			flag:UpdateHealth();
		end
	end
end
Events.SerialEventSiteSetDamage.Add( OnSetDamage );

------------------------------------------------------------
function OnMouseEnterSettlementBanner( control, id )

	control:SetAlpha( ALPHA_BANNER_OVER );

end

------------------------------------------------------------
function OnMouseExitSettlementBanner( control, id )

	control:SetAlpha( ALPHA_BANNER_IDLE );

end

------------------------------------------------------------
function OnCustomPlotEvent(x, y, type, data1, data2 )
	local pPlot : table = Map.GetPlot(x, y);
	if (pPlot ~= nil) then
		local flag = g_MasterListByPlot[ pPlot:GetPlotIndex() ];
		if (flag  ~= nil) then
			RefreshBanner(flag);
		end		
	end
end
Events.CustomPlotEvent.Add( OnCustomPlotEvent );

------------------------------------------------------------
-- Rebuild on hotload
------------------------------------------------------------
if( ContextPtr:IsHotLoad() ) then

	local width, height = Map.GetGridSize();
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			DoImprovementCreated( x, y );
		end
	end
end

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
function OnActivePlayerChanged( iActivePlayer, iPrevActivePlayer )

	local iActivePlayerID = Game.GetActivePlayer();
		
	-- Rebuild all the tool tip strings.
	for playerID,playerTable in pairs( g_MasterListByPlayer ) 
	do
		local pPlayer = Players[ playerID ];
		
		local bIsActivePlayer = ( playerID == iActivePlayer );
				
		-- Only need to do this for human players
		if (pPlayer:IsHuman()) then	
			for plotIndex, pFlag in pairs( playerTable ) 
			do
				if (pFlag.m_FlagType == FLAGTYPE_SELECTABLE_SITE) then
					local pSite = pFlag.m_Plot:GetPlotStrategicSite();
					if ( pSite ~= nil ) then        	

						if ( bIsActivePlayer ) then
							pFlag.m_Instance.NormalButton:SetDisabled( false );
							pFlag.m_Instance.NormalButton:SetConsumeMouseOver( true );
							pFlag.m_Instance.HealthBarButton:SetDisabled( false );
							pFlag.m_Instance.HealthBarButton:SetConsumeMouseOver( true );
						else
							pFlag.m_Instance.NormalButton:SetDisabled( true );
							pFlag.m_Instance.NormalButton:SetConsumeMouseOver( false );
							pFlag.m_Instance.HealthBarButton:SetDisabled( true );
							pFlag.m_Instance.HealthBarButton:SetConsumeMouseOver( false );					
						end
					
					end
				end
			end
		end
	end
end
Events.GameplaySetActivePlayer.Add(OnActivePlayerChanged);
