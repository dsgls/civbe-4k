------------------------------------------------------------------------------
--	Utilizites to help during loadout / pregame setup
------------------------------------------------------------------------------


-- Keep all utilizies encapsulated:
LoadoutUtils = {};


------------------------------------------------------------------------------
------------------------------------------------------------------------------
function LoadoutUtils.GetPlayerID()
	--WRM: TODO - Fix this up for multiplayer.
	return 0;
end



------------------------------------------------------------------------------
------------------------------------------------------------------------------
function LoadoutUtils.IsWBMap(file)
	return Path.UsesExtension(file,".CivBEMap"); 
end
