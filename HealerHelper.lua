--
htHealerHelper = {}
htHealerHelper.name = "HealerHelper"
htHealerHelper.version = 0.1
htHealerHelper.unitTags = {}
htHealerHelper.inCombat = false
htHealerHelper.playerName = ""
htHealerHelper.LOW_HEALTH = 0.85

-- Initialize our addon
function htHealerHelper.OnAddOnLoaded(eventCode, addOnName)
	if (addOnName == htHealerHelper.name) then 
		htHealerHelper:Initialize()
	end
end


--integer eventCode, string unitTag, integer powerIndex, integer powerType, integer powerValue, integer powerMax, integer powerEffectiveMax
function htHealerHelper.OnPowerUpdate(eventCode, unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax)
	
	htHealerHelper.UpdateVolatileUnitInfo(unitTag)

	if unitTag == "player" and powerType == POWERTYPE_MAGICKA then
		if (powerValue / powerMax) > .5 then
			PD_MagPlenty()
		else
			PD_MagNotPlenty()
		end
	end

end


function htHealerHelper:Initialize()
	self.inCombat = IsUnitInCombat("player")
	self.playerName = GetUnitName("player")
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, self.OnPlayerCombatState);
	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_POWER_UPDATE, htHealerHelper.OnPowerUpdate);


	--self.savedVariables = ZO_SavedVars:New("HealerHelperSavedVariables", 1, nil, {})
	self.savedVariables = ZO_SavedVars:NewAccountWide("HealerHelperSavedVariables", 1, nil, {})

	self:RestorePosition()

    htHealerHelperIndicatorBG:SetAlpha(0)
    
	htHealerHelperIndicator:SetWidth( 600 )
	htHealerHelperIndicator:SetHeight( 50 )

    htHealerHelperIndicatorT:ClearAnchors();
    htHealerHelperIndicatorT:SetAnchor(CENTER, htHealerHelperIndicator, CENTER, 0, 0)

    htHealerHelperIndicatorT:SetWidth( 600 )
	htHealerHelperIndicatorT:SetHeight( 50 )
	htHealerHelperIndicatorT:SetHorizontalAlignment(1)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GAME_CAMERA_UI_MODE_CHANGED, htHealerHelper.UIModeChanged)

	EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_ACTIVATED, htHealerHelper.LateInitialize);
	EVENT_MANAGER:UnregisterForEvent(self.name, EVENT_ADD_ON_LOADED);

    EVENT_MANAGER:RegisterForEvent(self.name,  EVENT_ACTION_LAYER_POPPED , htHealerHelper.ShowInterface)
    EVENT_MANAGER:RegisterForEvent(self.name,  EVENT_ACTION_LAYER_PUSHED , htHealerHelper.HideInterface)

end

-- Fancy loaded message
function htHealerHelper.LateInitialize(eventCode, addOnName)
	d("Healer Helper loaded...")

	EVENT_MANAGER:UnregisterForEvent(htHealerHelper.name, EVENT_PLAYER_ACTIVATED);
end


function htHealerHelper.OnPlayerCombatState(event, inCombat)
	-- The ~= operator is "not equal to" in Lua.
	if inCombat ~= htHealerHelper.inCombat then
		-- The player's state has changed. Update the stored state...
		htHealerHelper.inCombat = inCombat
		if inCombat then
			PD_InCombat()
			-- entering combat - clear unitTags
			htHealerHelper.unitTags = {}		
		else
			-- exiting combat - clear indicator
			htHealerHelperIndicatorT:SetColor(255, 255, 255, 255)
			htHealerHelperIndicatorT:SetText("")
			PD_NotInCombat()
		end
	end
end

function htHealerHelper.UpdateIndicator()

	--unit.Name = GetUnitName(unitTag)
	--unit.Dead = IsUnitDead(unitTag)
	--unit.Online = IsUnitOnline(unitTag)
	--unit.HealthPercent = currentHp / maxHp
	--unit.LowHealth = unit.HealthPercent <= htHealerHelper.LOW_HEALTH
	--unit.InSupportRange = IsUnitInGroupSupportRange(unitTag)
	--unit.UnitTag = unitTag

	local priorityUnit = nil;

	
	

	--do we have a low health ally nearby
	for i, unit in pairs(htHealerHelper.unitTags) do
		if unit.Online and (not unit.Dead) and unit.InSupportRange and unit.LowHealth then
			if not priorityUnit then
				priorityUnit = unit
			else
				if unit.HealthPercent < priorityUnit.HealthPercent then
					priorityUnit = unit
				end
			end 
		end
	end
	--if we dont have a low health ally nearby select a low health out of range ally.
	if not priorityUnit then
		for i, unit in pairs(htHealerHelper.unitTags) do
			if unit.Online and (not unit.Dead) and (not unit.InSupportRange) and unit.LowHealth then
				if not priorityUnit then
					priorityUnit = unit
				else
					if unit.HealthPercent < priorityUnit.HealthPercent then
						priorityUnit = unit
					end
				end 
			end
		end
	end 

	if priorityUnit then
		if priorityUnit.InSupportRange then
			htHealerHelperIndicatorT:SetColor(255, 0, 0, 255)
			PD_HealingNeeded()
			if htHealerHelper.playerName == priorityUnit.Name then
				htHealerHelperIndicatorT:SetText("Heal yourself!")
			else
				htHealerHelperIndicatorT:SetText("Heal " .. priorityUnit.Name .. ".")
			end
		else
			htHealerHelperIndicatorT:SetColor(255, 255, 0, 255)
			htHealerHelperIndicatorT:SetText(priorityUnit.Name .. " is out of range.")
			PD_HealingNotNeeded()
		end
	else
		htHealerHelperIndicatorT:SetText("")
		PD_HealingNotNeeded()
	end
	
end

function htHealerHelper.UpdateVolatileUnitInfo(unitTag)

	if not unitTag then
		return
	end

	local currentHp, maxHp, effectiveMaxHp
	local currentMp, maxMp, effectiveMaxMp
	local unit = {}



	if (string.sub(unitTag,1,string.len("group"))=="group" or string.sub(unitTag,1,string.len("player"))=="player" or (IsUnitPlayer(unitTag) and IsUnitInGroupSupportRange(unitTag))) then

		currentHp, maxHp, effectiveMaxHp = GetUnitPower(unitTag, POWERTYPE_HEALTH)
		currentMp, maxMp, effectiveMaxMp = GetUnitPower(unitTag, POWERTYPE_MAGICKA)

		unit.Name = GetUnitName(unitTag)
		unit.Dead = IsUnitDead(unitTag)
		unit.Online = IsUnitOnline(unitTag)
		unit.HealthPercent = currentHp / maxHp
		unit.MagickaPercent = currentMp / maxMp
		unit.LowHealth = unit.HealthPercent <= htHealerHelper.LOW_HEALTH 
		unit.InSupportRange = IsUnitInGroupSupportRange(unitTag)
		unit.UnitTag = unitTag

		htHealerHelper.unitTags[unitTag] = unit

		htHealerHelper.UpdateIndicator()
	end

	
end


function htHealerHelper.OnIndicatorMoveStop()
	htHealerHelper.savedVariables.left = htHealerHelperIndicator:GetLeft()
	htHealerHelper.savedVariables.top = htHealerHelperIndicator:GetTop()
end

function htHealerHelper:RestorePosition()
	local left = self.savedVariables.left
	local top = self.savedVariables.top
 
	htHealerHelperIndicator:ClearAnchors()
	htHealerHelperIndicator:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

function htHealerHelper.UIModeChanged()

	-- zo_callLater(function () d(IsMenuVisisble()) end, 1000)
	
	if (IsReticleHidden()) then
		htHealerHelperIndicatorBG:SetAlpha(0)
		htHealerHelperIndicatorT:SetText("")
		PD_InputNotReady()
	else
		htHealerHelperIndicatorBG:SetAlpha(0)
		htHealerHelperIndicatorT:SetText("")
		PD_InputReady()
	end
end

-- Hide or show the add-on when other panels are open, like inventory.
-- There's probably a better way to hook this into the scene manager.
function htHealerHelper.HideInterface(eventCode,layerIndex,activeLayerIndex)
    --d(layerIndex .. ":" .. activeLayerIndex)
    -- We don't want to hide the interface if this is the user pressing the "." key, only if there's an interface displayed
    if (activeLayerIndex == 3) then
		htHealerHelperIndicator:SetHidden(true)
		PD_InputNotReady()
    end
end

function htHealerHelper.ShowInterface(...)
    htHealerHelperIndicator:SetHidden(false)
end

EVENT_MANAGER:RegisterForEvent(htHealerHelper.name, EVENT_ADD_ON_LOADED, htHealerHelper.OnAddOnLoaded);