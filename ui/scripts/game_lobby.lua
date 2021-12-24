----------------------------------------------------------
--	Name: 		Game Lobby Script	            		--
--  Copyright 2015 Frostburn Studios					--
----------------------------------------------------------

----- Filter configs
-- Category Bar Maxes
-- This is a number between 0 and 25, 25 being the bar will be full only if all 5 team members pick heroes with 5 in that category
local FILTER_CATEGORY_MAX =
	{
		["solo"] 		= 7,
		["jungle"] 		= 7,
		["carry"]		= 13,
		["support"]		= 13,
		["initiator"]	= 13,
		["ganker"] 		= 13,
		["ranged"]		= 13,
		["melee"]		= 13,
		["pusher"]		= 13,
	}

-- some (possibly temp) filter options
--local FILTER_SINGLE_BAR_COMPOSITION = false  -- now a cvar 'ui_filterMultiBarComposition'

----------------------------------------------------------

local _G = getfenv(0)
local ipairs, pairs, select, string, table, next, type, unpack, tinsert, tconcat, tremove, format, tostring, tonumber, tsort, ceil, floor, sub, find, gfind = _G.ipairs, _G.pairs, _G.select, _G.string, _G.table, _G.next, _G.type, _G.unpack, _G.table.insert, _G.table.concat, _G.table.remove, _G.string.format, _G.tostring, _G.tonumber, _G.table.sort, _G.math.ceil, _G.math.floor, _G.string.sub, _G.string.find, _G.string.gfind
local interface, interfaceName = object, object:GetName()
RegisterScript2('Lobby', '33')
Game_Lobby = Game_Lobby or {}
Game_Lobby.resetGamePhase = true
Game_Lobby.MAX_HERO_LIST_SIZE =  162
Game_Lobby.lastSelectedHeroEntity = nil
Game_Lobby.requestingStoreData = false
Game_Lobby.selectedEAPBundle = 1
Game_Lobby.avatarDataTable = {}
Game_Lobby.doubleClickType = 0
Game_Lobby.botPickTable = nil
Game_Lobby.repickingSlot = nil
Game_Lobby.multibotPickOffset = nil
Game_Lobby.botPickScrollOffsets =0
Game_Lobby.multibotPickScrollOffsets = 0
Game_Lobby.ignoreHeroSelectedDefaultAvatar = false
local altCardTable = {}
local ALLOW_DUPE_BOTS = false

local rap2Enable = GetCvarBool('cl_Rap2Enable')

---- filter stuff
Game_Lobby.filterInfoList = {}
Game_Lobby.activeFilters = {}
Game_Lobby.favoriteHeroes = GetDBEntry("picker_favorite_heroes", nil, nil) or {}
Game_Lobby.filterString = ""
Game_Lobby.playerPicks = {}
Game_Lobby.filterThreshold = 3.0 -- this should never be changed since the slider is gone (for) now
Game_Lobby.nextPickBar = 1
Game_Lobby.filterButtons = {}
Game_Lobby.emptySlotCounter = 0
---- end filter stuff

Game_Lobby.walkthroughStorage = {}
Game_Lobby.GCardsTable = {}
Game_Lobby.CardLastSelect = -1

local function HideMenuButtonsForWalkthrough(hide)
	local enabled = not hide
	local isSuspended = false
	if rap2Enable then
		isSuspended = AtoB(interface:UICmd("IsAccountSuspended()"))
	end

	-- mid bar
	GetWidget('midbar_button_publicgames'):SetEnabled(enabled)
	GetWidget('midbar_button_matchmaking'):SetEnabled(enabled)
	GetWidget('midbar_button_matchstats_2'):SetEnabled(enabled)
	GetWidget('midbar_button_compendium'):SetEnabled(enabled)
	GetWidget('midbar_button_plinko'):SetEnabled(enabled)
	GetWidget('midbar_button_store'):SetEnabled(enabled)
	
	if (GetWidget('midbar_button_ladder', nil, true)) then
		if (HoN_Region.regionTable[HoN_Region.activeRegion].ladder) then
			GetWidget('midbar_button_ladder'):SetEnabled(enabled)
		else
			GetWidget('midbar_button_ladder'):SetEnabled(false)
		end
	end
	
	if (GetWidget('midbar_button_hontour')) then
		GetWidget('midbar_button_hontour'):SetEnabled(enabled)
	end
	-- Strictly disable HoN Live in NAEU
	if not GetCvarBool('cl_GarenaEnable') then
		GetWidget('midbar_button_hontour'):SetEnabled(false)
	end
	
	-- top bar
	GetWidget('sysbar_options_button'):SetEnabled(enabled)
	if not isNewUI() then
		GetWidget('sysbar_replays_button'):SetEnabled(enabled)
	end
	GetWidget('sysbar_changelog_button'):SetEnabled(enabled)
	GetWidget('sysbar_coins_gold'):SetEnabled(enabled)
	GetWidget('sysbar_coins_silver'):SetEnabled(enabled)
	if not isNewUI() then
		GetWidget('sysbar_stats_button'):SetEnabled(enabled)
	end
end

local function UpdateHeroIcon(sourceWidget, team, param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16, param17, param18, param19, param20, param21, param22, param23, param24, param25, param26, param27, param28, param29, param30, param31, param32, param33, param34, param35, param36, param37, param38, param39, param40, param41, param42, param43, param44, param45, param46, param47, param48, param49, param50, param51, param52, param53, param54, param55, param56)
	local param2 = tonumber(param2)
	if AtoB(param3) then
		if param2 ~= -2 then
			sourceWidget:SetTexture(param1)
		else
			if (param30 == 'legion') or (param30 == 'dev_legion') then
				sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_legion.tga')
			elseif (param30 == 'hellbourne') or (param30 == 'dev_hellbourne') then
				sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_hellbourne.tga')
			else
				sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_legion.tga')
			end
		end
	else
		if (team == -1) then
			sourceWidget:SetTexture('/ui/elements/hero_picker_icon.tga')
		elseif (team == 0) then
			sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_legion.tga')
		elseif (team == 1) then
			sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_hellbourne.tga')
		end
	end

	if (not AtoB(param56)) and ((not AtoB(param3)) or (param2 == -5) or (AtoB(param4) and ((param2 ~= -1 and param2 ~= 0) or AtoB(param43) or (AtoB(param42) and AtoB(param37))))) then
		sourceWidget:SetRenderMode('normal')
	else
		sourceWidget:SetRenderMode('grayscale')
	end

	-- Set pyro for tut here
	if(Main_Walkthrough.pregameLobbyStep == 1) then
		if(param0 ~= 'Hero_Pyromancer') then
			sourceWidget:SetRenderMode('grayscale')
			sourceWidget:ClearCallback('onmouseover')
			sourceWidget:RefreshCallbacks()
		else

			Main_Walkthrough.ShowWalkthroughTextPanel(true, '0h', '37.5h', false, Translate('lobby_walkthrough_title1'), Translate('lobby_walkthrough_text1'), '', Translate('lobby_walkthrough_sound1'))
			-- Play voiceover sound here
			Game_Lobby.walkthroughStorage.popupsNotHidden = true

			sourceWidget:Sleep(1, function() Main_Walkthrough.pregameLobbyStep = 2 end)

			-- Disable menu buttons
			HideMenuButtonsForWalkthrough(true)
		end
	end

end

function Game_Lobby.TimerCheck(self, timeLeft, phaseDuration, isFinalHeroSelect, secondElapsed)

	if(Game_Lobby.walkthroughStorage.popupsNotHidden and AtoB(isFinalHeroSelect) and AtoN(timeLeft) < 6000) then

		-- select the hero if pyro isn't picked
		interface:UICmd("SpawnHero('Hero_Pyromancer')")

		Game_Lobby.WalkthroughHideThePopups()

		-- Set this value so the quest window can show in game
		Main_Walkthrough.pregameLobbyStep = 3

	end

end
interface:RegisterWatch('HeroSelectTimer', Game_Lobby.TimerCheck)

function Game_Lobby.WalkthroughHideThePopups()

	Main_Walkthrough.ShowWalkthroughTextPanel(false)
	Main_Walkthrough.PointAtWidget(nil, false)
	Game_Lobby.walkthroughStorage.popupsNotHidden = false

	-- Reset this value so the next game doesn't show walkthrough stuff
	Main_Walkthrough.pregameLobbyStep = 0

	-- Reset menu buttons
	HideMenuButtonsForWalkthrough(false)

end
interface:RegisterWatch('Disconnected', Game_Lobby.WalkthroughHideThePopups)
interface:RegisterWatch('HostErrorMessage', Game_Lobby.WalkthroughHideThePopups)

function Game_Lobby.TellUserToReady()

	Main_Walkthrough.ShowWalkthroughTextPanel(true, '0', '37.5h', false, Translate('lobby_walkthrough_title2'), Translate('lobby_walkthrough_text2'), '', '')
	-- Play voiceover sound here
	Main_Walkthrough.PointAtWidget(nil, false)
	Trigger('WalkthroughHighlightReady')
	--Echo('told user to ready')
end

local function UnregisterHeroIcon(sourceWidget, watch, watchIndex)
	sourceWidget:UnregisterWatch(watch..watchIndex)
end

function Game_Lobby.RegisterHeroIcon(sourceWidget, watch, index, team, team_offset, group, group_size, row, row_size)
	local index, team, team_offset, group, group_size, row, row_size = tonumber(index) or 0, tonumber(team) or 0, tonumber(team_offset) or 0, tonumber(group) or 0, tonumber(group_size) or 0, tonumber(row) or 0, tonumber(row_size) or 0

	local watchIndex =  math.floor(index + (team * team_offset) + (group * group_size) + (row * row_size))

	sourceWidget:RegisterWatch(watch..watchIndex, function(_, ...) UpdateHeroIcon(sourceWidget, team, ...) end)
	sourceWidget:SetCallback('onhide', function() UnregisterHeroIcon(sourceWidget, watch, watchIndex) end)
	sourceWidget:RefreshCallbacks()
end

local function UpdateHeroIconSD(sourceWidget, param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16, param17, param18, param19, param20, param21, param22, param23, param24, param25, param26, param27, param28, param29, param30, param31, param32, param33, param34, param35, param36, param37, param38, param39, param40, param41, param42, param43, param44, param45, param46, param47, param48, param49, param50, param51, param52, param53, param54, param55, param56)
	local param2 = tonumber(param2)
	if AtoB(param3) and (param2 ~= -2 )then
		sourceWidget:SetTexture(param1)
	else
		if (param30 == 'legion') or (param30 == 'dev_legion') then
			sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_legion.tga')
		elseif (param30 == 'hellbourne') or (param30 == 'dev_hellbourne') then
			sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_hellbourne.tga')
		else
			sourceWidget:SetTexture('/ui/fe2/lobby/empty_hero_slot_legion.tga')
		end
	end

	if (not AtoB(param56)) and ((not AtoB(param3)) or (AtoB(param4) and ((param2 ~= -1 and param2 ~= 0) or AtoB(param43) or (AtoB(param42) and AtoB(param37))))) then
		sourceWidget:SetRenderMode('normal')
	else
		sourceWidget:SetRenderMode('grayscale')
	end
end

local function UnregisterHeroIconSD(sourceWidget, watch, watchIndex)
	sourceWidget:UnregisterWatch(watch..watchIndex)
end

function Game_Lobby.RegisterHeroIconSD(sourceWidget, watch, param13, slot, offset)
	local param13, slot, offset = tonumber(param13) or 0, tonumber(slot) or 0, tonumber(offset) or 0

	local watchIndex =  math.floor(((param13 - 1) * 15) + (slot * 3) + offset)

	sourceWidget:RegisterWatch(watch..watchIndex, function(_, ...) UpdateHeroIconSD(sourceWidget, ...) end)
	sourceWidget:SetCallback('onhide', function() UnregisterHeroIconSD(sourceWidget, watch, watchIndex) end)
	sourceWidget:RefreshCallbacks()
end

function SetPotentialHero2(heroEntity, avatarCode)
	if (avatarCode) and (heroEntity) and NotEmpty(heroEntity) and NotEmpty(avatarCode) then
		printdb('SetPotentialHero')
		printdb('heroEntity = ' .. tostring(heroEntity))
		printdb('avatarCode = ' .. tostring(avatarCode))
		SetPotentialHero(heroEntity, avatarCode)
	end
end

function Game_Lobby.SetDefaultHeroAvatar(heroEntity, avatarCode)
	if (avatarCode) and (heroEntity) and NotEmpty(heroEntity) then
		printdb('Game_Lobby.SetDefaultHeroAvatar(heroEntity, avatarCode)')
		printdb('heroEntity = ' .. tostring(heroEntity))
		printdb('avatarCode = ' .. tostring(avatarCode))
		GetDBEntry('def_av_'..heroEntity, avatarCode, true, false, true)
		--SetPotentialHero2(heroEntity, avatarCode)
		SetDefaultAvatar(heroEntity, avatarCode)
		groupfcall('game_lobby_default_av_btns', function(index, widget, groupName) widget:DoEvent() 	end)
	end
end

local function LoadDefaultAvatar(heroEntity)
	if (heroEntity) and NotEmpty(heroEntity) then
		--printdb('LoadDefaultAvatar')
		--printdb('heroEntity = ' .. tostring(heroEntity))
		local avatarCode = GetDBEntry('def_av_'..heroEntity, 'Base', false, false, false)
		--printdb('avatarCode = ' .. tostring(avatarCode))
		--SetPotentialHero2(heroEntity, avatarCode)
		SetDefaultAvatar(heroEntity, avatarCode)
	end
end

local function HeroSelectHeroList(index, param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16, param17, param18, param19, param20, param21, param22, param23, param24, param25, param26, param27, param28, param29, param30, param31, param32, param33, param34, param35, param36, param37, param38, param39, param40, param41, param42, param43)
	 --printdb('HeroSelectHeroList ' .. index .. ' | ' .. param0)
	 LoadDefaultAvatar(param0)
end
for i = 1, Game_Lobby.MAX_HERO_LIST_SIZE, 1 do
	interface:RegisterWatch('HeroSelectHeroList'..i, function(_, ...) HeroSelectHeroList(i, ...) end)
end

local function DisplayHeroPicker(param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15, param16)
	-- Clear all watches
	Trigger('ClearHeroSelectInfo')
	Trigger('StoreAvatarIsNewRequest')
	
	if ((param2 == 'lp') or (param2 == 'cm')) then
		Set('ui_lobby_localPlayerCaptain', AtoB(param9), 'bool')
	else
		Set('ui_lobby_localPlayerCaptain', 'false', 'bool')
	end

	local heroPickVis = {
		rd_list						= false,
		hero_picker_outline			= false,
		hero_picker_outline_filter	= false,
		normal_list					= false,
		banning_draft_list			= false,
		banning_draft_list_bg		= false,
		sd_list						= false,
		sd_list_bg					= false,
		ap_list						= false,
		bp_list						= false,
		lp_list						= false,
		gated_list					= false,
		gated_list					= false,
		ar_list						= false,
		fp_list						= false,
		sp_list						= false,
		sm_list						= false,
		sm_list_bg					= false,
		hero_picker_filters			= false,
	}

	local pickMode = param2

	local heroPickVisPerMode	= {
		rd				= {
			rd_list					= true,
			hero_picker_outline		= true,
			primaryContainer		= 'rd_list',
			announcer				= '/shared/sounds/announcer/lobby/random_draft.wav',
			trigger					= 'HeroSelectInford',
		},
		normal				= {
			normal_list				= true,
			hero_picker_outline		= true,
			primaryContainer		= 'normal_list',
			trigger					= 'HeroSelectInfonormal',
		},
		bd					= {
			banning_draft_list		= true,
			banning_draft_list_bg	= true,
			hero_picker_outline		= true,
			primaryContainer		= 'banning_draft_list',
			announcer				= '/shared/sounds/announcer/lobby/banning_draft.wav',
			trigger					= 'HeroSelectInfobd',
		},
		sd					= {
			sd_list					= true,
			sd_list_bg				= true,
			hero_picker_outline		= true,
			primaryContainer		= 'sd_list',
			announcer				= '/shared/sounds/announcer/lobby/single_draft.wav',
			trigger					= 'HeroSelectInfosd',
		},
		ap					= {			-- (param2 == 'ap') or (param2 == 'bm') or (param2 == 'km')
			ap_list						= true,
			hero_picker_outline_filter	= true,
			primaryContainer			= 'ap_list',
			announcer					= '/shared/sounds/announcer/lobby/all_pick.wav',
			trigger						= 'HeroSelectInfoap',
			hero_picker_filters			= true,
		},
		cm					= {
			ap_list						= true,
			hero_picker_outline_filter	= true,
			primaryContainer			= 'ap_list',
			announcer					= '/shared/sounds/announcer/lobby/captains_pick.wav',
			trigger						= 'HeroSelectInfoap',
			hero_picker_filters			= true,
		},
		gt					= {			-- (param2 == 'gt') or (param2 == 'apg') or (param2 == 'bbg')
			gated_list					= true,
			hero_picker_outline			= true,
			primaryContainer			= 'gated_list',
			announcer					= '/shared/sounds/announcer/lobby/all_pick.wav',
			trigger						= 'HeroSelectInfogt',
		},
		ar					= {
			ar_list						= true,
			hero_picker_outline			= true,
			primaryContainer			= 'ar_list',
			announcer					= '/shared/sounds/announcer/lobby/all_random.wav',
			trigger						= 'HeroSelectInfoar',
		},
		bb					= {
			ap_list						= true,
			hero_picker_outline_filter	= true,
			primaryContainer			= 'ap_list',
			announcer					= '/shared/sounds/announcer/lobby/blind_ban.wav',
			trigger						= 'HeroSelectInfoap',
			hero_picker_filters			= true,
		},
		bp					= {
			bp_list						= true,
			hero_picker_outline			= true,
			primaryContainer			= 'bp_list',
			announcer					= '/shared/sounds/announcer/lobby/banning_pick.wav',
			trigger						= 'HeroSelectInfobp',
		},
		lp					= {
			lp_list						= true,
			hero_picker_outline			= true,
			primaryContainer			= 'lp_list',
			announcer					= '/shared/sounds/announcer/lobby/lockpick.wav',
			trigger						= 'HeroSelectInfolp',
		},
		fp				= {
			ap_list						= true,
			hero_picker_outline			= true,
			primaryContainer			= 'ap_list',
			announcer					= '/shared/sounds/announcer/lobby/all_pick.wav',
			trigger						= 'HeroSelectInfoap',
			hero_picker_filters			= true,
		},
		sp				= {
			sp_list						= true,
			hero_picker_outline			= true,
			primaryContainer			= 'sp_list',
			announcer					= '/shared/sounds/announcer/lobby/all_pick.wav',
			trigger						= 'HeroSelectInfosp',
		},
		sm 				= {
			sm_list						= true,
			hero_picker_outline_filter	= true,
			primaryContainer			= 'sm_list',
			announcer					= '/shared/sounds/announcer/lobby/all_pick.wav',
			trigger						= 'HeroSelectInfosm',
			hero_picker_filters			= true,
		},
		hb					= {
			ap_list						= true,
			hero_picker_outline_filter	= true,
			primaryContainer			= 'ap_list',
			announcer					= '/shared/sounds/announcer/lobby/ban_hero.wav',
			trigger						= 'HeroSelectInfoap',
			hero_picker_filters			= true,
		},
		mwb					= {
			ap_list						= true,
			hero_picker_outline_filter	= true,
			primaryContainer			= 'ap_list',
			announcer					= '/shared/sounds/announcer/lobby/blind_ban.wav',
			trigger						= 'HeroSelectInfoap',
			hero_picker_filters			= true,
		},		
		rb					= {
			ap_list						= true,
			hero_picker_outline_filter	= true,
			primaryContainer			= 'ap_list',
			announcer					= '/shared/sounds/announcer/lobby/blind_ban.wav',
			trigger						= 'HeroSelectInfoap',
			hero_picker_filters			= true,
		},
	}

	if pickMode == 'bm' or pickMode == 'km' then
		pickMode = 'ap'
	elseif pickMode == 'apg' or pickMode == 'bbg' or pickMode == 'rbg' then
		pickMode = 'gt'
	end

	local mapSounds	= {
		prophets		= {
			sound			= '/shared/sounds/announcer/lobby/prophets.wav',
			announceMode	= false,
		},
		midwars			= {
			sound			= '/shared/sounds/announcer/lobby/mid_wars.wav',
			announceMode	= true,
		},
		capturetheflag	= {
			sound			= '/shared/sounds/announcer/lobby/capture_the_flag_merrick.wav',
			announceMode	= true,
		},
		devowars	= {
			sound			= '/shared/sounds/announcer/lobby/devo_wars.wav',
			announceMode	= true,
		}
	}

	if pickMode == 'ap' and IsCoNGame() then 
		heroPickVisPerMode['ap'].announcer = '/shared/sounds/announcer/lobby/counter_pick.wav'
	end

	
	if heroPickVisPerMode[pickMode] then
		if (not (GetWidgetNoMem(heroPickVisPerMode[pickMode].primaryContainer):IsVisible())) or Game_Lobby.resetGamePhase then

			if mapSounds[param16] and mapSounds[param16].sound then
				PlaySound(mapSounds[param16].sound)
				if mapSounds[param16].announceMode and not ViewingStreaming() then
					GetWidgetNoMem(heroPickVisPerMode[pickMode].primaryContainer):Sleep(GetSoundLength(mapSounds[param16].sound), function()	-- get sound length
						PlaySound(heroPickVisPerMode[pickMode].announcer)
					end)
				end
			else
				if heroPickVisPerMode[pickMode].announcer and not ViewingStreaming() then
					PlaySound(heroPickVisPerMode[pickMode].announcer)
				end
			end
		end

		for k,v in pairs(heroPickVis) do
			GetWidgetNoMem(k):SetVisible(heroPickVisPerMode[pickMode][k] or heroPickVis[k])
		end
		
		Trigger(heroPickVisPerMode[pickMode].trigger, param0, param1, param2, param3, param4, param5, param6, param7, param8, param9, param10, param11, param12, param13, param14, param15)
	end

	Game_Lobby.resetGamePhase = false

end
interface:RegisterWatch('HeroSelectInfo', function(_, ...) DisplayHeroPicker(...) end)

local function StoreAvatarIsNewRequest()
	Game_Lobby.avatarDataTable = {}
end
interface:RegisterWatch('StoreAvatarIsNewRequest', function(_, ...) StoreAvatarIsNewRequest(...) end)

local function StoreAvatarIsNewResult(productID, isNew, ultimateAvatar)
	productID = AtoN(productID)
	isNew = AtoB(isNew)
	ultimateAvatar = AtoB(ultimateAvatar)

	Game_Lobby.avatarDataTable[productID] = {isNew, ultimateAvatar}

	--printTable(Game_Lobby.avatarDataTable)
end
interface:RegisterWatch('StoreAvatarIsNewResult', function(_, ...) StoreAvatarIsNewResult(...) end)


local function AdjustGoldSiverPrice(gold, silver)
	if gold == 0 then gold = 9006 end
	if silver == 0 then silver = 9002 end
	if gold == 9006 and silver == 9002 then
		gold = 0
		silver = 0
	end
	return gold, silver
end

function Game_Lobby.ClickedViewAvatars(heroEntity, purchasedIndex, goldCost)
	if (heroEntity) and NotEmpty(heroEntity) and (GetAltAvatars) then
		Game_Lobby.lastSelectedHeroEntity = heroEntity
		altCardTable = {}

		if IsEarlyAccessHero(heroEntity) and (not CanAccessEarlyAccessProduct(heroEntity)) then
			Game_Lobby.requestingStoreData = true
			Set('ui_game_lobby_store_active', 'true', 'bool')

			local altInfoTable = GetAltAvatars(heroEntity)

			local angleString, posString = '', ''
			local avatarCode, db_av
			local targetCardIndex
			local isNew, collectorsEditionSet

			for i,v in ipairs(altInfoTable) do
				v.Cost, v.PremiumCost = AdjustGoldSiverPrice(v.Cost, v.PremiumCost)

				avatarCode = v.Name
				heroEntity = v.TypeName

				if (Game_Lobby.avatarDataTable) and (v.ProductID) and (Game_Lobby.avatarDataTable[v.ProductID]) then
					isNew = (Game_Lobby.avatarDataTable[v.ProductID])[1]
					collectorsEditionSet = (Game_Lobby.avatarDataTable[v.ProductID])[2]
				else
					isNew = false
					collectorsEditionSet = 0
				end
				v.isNew = isNew
				v.collectorsEditionSet = collectorsEditionSet

				posString 		= (v.Pos['x'] or '0') 	.. ' ' .. (v.Pos['y'] or '0') 	.. ' ' .. (v.Pos['z'] or '0')
				angleString 	= (v.Angles['x'] or '0') .. ' ' .. (v.Angles['y'] or '0') .. ' ' .. (v.Angles['z'] or '0')

				v.Pos 			= posString
				v.Angles 		= angleString
				v.Available 	= CanAccessEarlyAccessProduct(heroEntity)	-- Override incorrect avatar data
				v.Cost			= goldCost or v.Cost
				v.TEMPLATE 		= 'altavatar_card_template_2'
				v.DEFAULTS 		= {x=0, lastx=0, xMod=0.40, y=0, width='30h', height='44.4h', lastwidth='44.4h', lastheight='30h', valign='center', align='center', TEMPLATE='altavatar_card_template_2', reducePerTier = 0.85, hideSideCards=true}

				db_av = GetDBEntry('def_av_'..heroEntity, 'nil', false, false, false)

				if (db_av == avatarCode) and (not purchasedIndex) then
					targetCardIndex = i
				end

				tinsert(altCardTable, v)
			end

			Game_Lobby.selectedEAPBundle = 1

			GetWidgetNoMem('gl_eap_selected_bundle_label'):SetText(Translate('mstore_eap_bundle_1'))
			if (tonumber(goldCost)) and (tonumber(goldCost) > 0) and (tonumber(goldCost) ~= 9006) then
				GetWidgetNoMem('gl_eap_purchase_cost_label'):SetText(goldCost or '-')
			else
				GetWidgetNoMem('gl_eap_purchase_cost_label'):SetText('-')
			end

			Game_Lobby:DisplayCardception(altCardTable, purchasedIndex or targetCardIndex, true)

			GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):SetVisible(0)
			GetWidgetNoMem('game_lobby_eap_footer'):SetVisible(1)

			interface:UICmd([[
				SubmitForm('MicroStore',
					'account_id', GetAccountID(),
					'category_id', 58,
					'request_code', 1,
					'page', 1,
					'cookie', GetCookie(),
					'hostTime', HostTime,
					'displayAll', false,
					'notPurchasable', false
				)
			]])

		else
			local altInfoTable = GetAltAvatars(heroEntity)

			local altInfoTableResort = {}
			local angleString, posString = '', ''
			local avatarCode, db_av
			local targetCardIndex
			local isNew, collectorsEditionSet

			for i,v in ipairs(altInfoTable) do
				local avatarName = v.AvatarDisplayName or ''
				Echo(tostring(i)..'altInfoTable:'..v.Name..' / '..avatarName..' / '..tostring(v.Available))
			end

			tinsert(altInfoTableResort, altInfoTable[1])
			if (altInfoTable) and (#altInfoTable >= 2) then
				for i = #altInfoTable, Min(2, #altInfoTable), -1 do
					tinsert(altInfoTableResort, altInfoTable[i])
				end
			end

			for i,v in ipairs(altInfoTableResort) do
				v.Cost, v.PremiumCost = AdjustGoldSiverPrice(v.Cost, v.PremiumCost)

				if (Game_Lobby.avatarDataTable) and (v.ProductID) and (Game_Lobby.avatarDataTable[v.ProductID]) then
					isNew = (Game_Lobby.avatarDataTable[v.ProductID])[1]
					collectorsEditionSet = (Game_Lobby.avatarDataTable[v.ProductID])[2]
				else
					isNew = false
					collectorsEditionSet = 0
				end
				v.isNew = isNew
				v.collectorsEditionSet = collectorsEditionSet

				posString 		= (v.Pos['x'] or '0') 	.. ' ' .. (v.Pos['y'] or '0') 	.. ' ' .. (v.Pos['z'] or '0')
				angleString 	= (v.Angles['x'] or '0') .. ' ' .. (v.Angles['y'] or '0') .. ' ' .. (v.Angles['z'] or '0')

				v.Pos 			= posString
				v.Angles 		= angleString

				v.TEMPLATE 		= 'altavatar_card_template_1'
				v.DEFAULTS 		= {x=0, lastx=0, xMod=0.40, y=0, width='30h', height='44.4h', lastwidth='44.4h', lastheight='30h', valign='center', align='center', TEMPLATE='altavatar_card_template_1', reducePerTier = 0.85, hideSideCards=true}

				avatarCode = v.Name
				heroEntity = v.TypeName

				db_av = GetDBEntry('def_av_'..heroEntity, 'nil', false, false, false)

				if (db_av == avatarCode) and (not purchasedIndex) then
					targetCardIndex = i
				elseif (purchasedIndex) and (purchasedIndex == i) then
					v.NewPurchase = true
				end

				tinsert(altCardTable, v)
			end

			for i,v in ipairs(altCardTable) do
				local avatarName = v.AvatarDisplayName or ''
				Echo(tostring(i)..'altCardTable:'..v.Name..' / '..avatarName..' / '..tostring(v.Available))
			end

			Game_Lobby:DisplayCardception(altCardTable, purchasedIndex or targetCardIndex, false)

			GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):SetVisible(1)
			GetWidgetNoMem('game_lobby_eap_footer'):SetVisible(0)

		end

		GetWidgetNoMem('game_lobby_card_spawn_target'):SetY('-1.5h')
		GetWidgetNoMem('game_lobby_card_spawn_target'):SetX('0')

	end
end

function Game_Lobby.UpdateAvatars(heroEntity)
	if (heroEntity) and NotEmpty(heroEntity) then
		local altInfoTable = GetAltAvatars(heroEntity)

		if (altInfoTable) and (altInfoTable[2]) and (altInfoTable[2].Icon) and NotEmpty(altInfoTable[2].Icon) then
			groupfcall('compendium_tab_button_icon_altavatars', function(index, widget, groupName) widget:SetTexture(altInfoTable[2].Icon) end)
		elseif (altInfoTable) and (altInfoTable[1]) and (altInfoTable[1].Icon) and NotEmpty(altInfoTable[1].Icon) then
			groupfcall('compendium_tab_button_icon_altavatars', function(index, widget, groupName) widget:SetTexture(altInfoTable[1].Icon) end)
		end
	end
end

local CARDS_MAX_INSTANTIATED = 30
local CARDS_MAX_DISPLAYED = 9
local CARDS_REDUCTION_PER_TIER = 0.90
local ANIM_TIME = 150

local c = {}
c.userViewingCard = 1
c.totalActiveCards = 0

local function SetCardOrder()
	if (c.ActiveTemplate) then
		for i = #c.cards, (c.userViewingCard+1), -1 do
			if GetWidgetNoMem(c.ActiveTemplate..'_parent_'..i, nil, true) then
				GetWidgetNoMem(c.ActiveTemplate..'_parent_'..i):BringToFront()
			end
		end
		for i = 1, c.userViewingCard, 1 do
			if GetWidgetNoMem(c.ActiveTemplate..'_parent_'..i, nil, true) then
				GetWidgetNoMem(c.ActiveTemplate..'_parent_'..i):BringToFront()
			end
		end
		GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):BringToFront()
		GetWidgetNoMem('game_lobby_card_avatar_top_parent'):BringToFront()
		GetWidgetNoMem('game_lobby_eap_footer'):BringToFront()
		GetWidgetNoMem('game_lobby_card_avatar_hint'):BringToFront()
		GetWidgetNoMem('game_lobby_avatar_splash_close'):BringToFront()
	end
end

local function ResizeAndAnimateCards()
	if (c.ActiveTemplate) then
		for index, cardTable in ipairs(c.cards) do
			if GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true) then
				if GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index..'_bg', nil, true) then
					GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index..'_bg', nil, true):SetColor(cardTable.color)
				end
				--GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true):SetColor(cardTable.color)

				GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true):ScaleWidth(cardTable.width, ANIM_TIME)

				if GetWidgetNoMem(c.ActiveTemplate..'_model_'..index, nil, true) then
					--GetWidgetNoMem(c.ActiveTemplate..'_model_'..index, nil, true):ScaleHeight(cardTable.height, ANIM_TIME)
					GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true):ScaleHeight(cardTable.height, ANIM_TIME)
					if (cardTable.doEvent) then
						GetWidgetNoMem(c.ActiveTemplate..'_model_'..index, nil, true):DoEventN(cardTable.doEvent)
					end
				else
					GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true):ScaleHeight(cardTable.height, ANIM_TIME)
				end

				GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true):SetX(cardTable.lastx)

				GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true):Sleep(ANIM_TIME, function()
					GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index, nil, true):SlideX(cardTable.x, ANIM_TIME, true)
					if (not cardTable.hide) then
						GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index):FadeIn(250)
					end
				end)

				if (cardTable.hide) then
					GetWidgetNoMem(c.ActiveTemplate..'_parent_'..index):FadeOut(250)
				end
			end
		end
	end
end

local function UpdateSelectedAvatar(newTarget, isEAP)
	if (altCardTable[newTarget]) then

		if (isEAP) then
			GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):SetVisible(0)
			GetWidgetNoMem('game_lobby_eap_footer'):SetVisible(1)
			GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):SetVisible(0)
			GetWidgetNoMem('game_lobby_card_avatar_ea_label'):SetVisible(1)
		else
			GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):SetVisible(1)
			GetWidgetNoMem('game_lobby_eap_footer'):SetVisible(0)
			GetWidgetNoMem('game_lobby_card_avatar_name_container'):SetVisible(0)
			GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):SetVisible(1)
			GetWidgetNoMem('game_lobby_card_avatar_ea_label'):SetVisible(0)
		end

		if not isEAP then 
			GetWidgetNoMem('game_lobby_card_avatar_name'):SetText(altCardTable[newTarget].AvatarDisplayName or altCardTable[newTarget].DisplayName  or '')
		end

		if isEAP then
			GetWidgetNoMem('game_lobby_card_avatar_icon'):SetTexture(GetHeroIconPathFromProduct(altCardTable[newTarget].TypeName))
		else
			GetWidgetNoMem('game_lobby_card_avatar_icon'):SetTexture(altCardTable[newTarget].Icon or '$invis')
		end

		if (altCardTable[newTarget].collectorsEditionSet) and (altCardTable[newTarget].collectorsEditionSet == 2) then
			-- Ultimate indicator
			GetWidgetNoMem('game_lobby_card_avatar_name'):SetColor('1 1 1 1')
			GetWidgetNoMem('game_lobby_card_avatar_top_border_2'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_3'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_4'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_5'):SetVisible(true)
		elseif (altCardTable[newTarget].isNew) then
			-- New indicator
			GetWidgetNoMem('game_lobby_card_avatar_name'):SetColor('1 1 1 1')
			GetWidgetNoMem('game_lobby_card_avatar_top_border_2'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_3'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_4'):SetVisible(true)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_5'):SetVisible(false)
		elseif (altCardTable[newTarget].Premium) then
			-- Premium indicator
			GetWidgetNoMem('game_lobby_card_avatar_name'):SetColor('#FFCC00')
			GetWidgetNoMem('game_lobby_card_avatar_top_border_2'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_3'):SetVisible(true)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_4'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_5'):SetVisible(false)
		else
			GetWidgetNoMem('game_lobby_card_avatar_name'):SetColor('1 1 1 1')
			GetWidgetNoMem('game_lobby_card_avatar_top_border_2'):SetVisible(true)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_3'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_4'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_avatar_top_border_5'):SetVisible(false)
		end

		local costVisible = false
		local isSpecialGoldValue = altCardTable[newTarget].Cost and altCardTable[newTarget].Cost > 9000 and altCardTable[newTarget].Cost ~= 9006
		if (altCardTable[newTarget].Cost) and (not (altCardTable[newTarget].Available)) then
			if ((altCardTable[newTarget].Cost) > 0) and ((altCardTable[newTarget].Cost) < 9001) then
				GetWidgetNoMem('game_lobby_avatar_splash_purchase_label_1'):SetText(altCardTable[newTarget].Cost or '')
				GetWidgetNoMem('game_lobby_avatar_splash_purchase_1'):FadeIn(250)
				costVisible = true
			else
				GetWidgetNoMem('game_lobby_avatar_splash_purchase_1'):FadeOut(250)
			end
		else
			GetWidgetNoMem('game_lobby_avatar_splash_purchase_1'):FadeOut(250)
		end

		if (altCardTable[newTarget].PremiumCost) and (not (altCardTable[newTarget].Available)) then
			if ((altCardTable[newTarget].PremiumCost) > 0) and ((altCardTable[newTarget].PremiumCost) < 9001) and not isSpecialGoldValue then
				GetWidgetNoMem('game_lobby_avatar_splash_purchase_label_2'):SetText(altCardTable[newTarget].PremiumCost or '')
				GetWidgetNoMem('game_lobby_avatar_splash_purchase_2'):FadeIn(250)
				costVisible = true
			else
				GetWidgetNoMem('game_lobby_avatar_splash_purchase_2'):FadeOut(250)
			end
		else
			GetWidgetNoMem('game_lobby_avatar_splash_purchase_2'):FadeOut(250)
		end

		if (costVisible) then
			GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):ScaleWidth('48.0h', 250)
			--GetWidgetNoMem('game_lobby_avatar_splash_purchase'):SetVisible(1)
		else
			GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):ScaleWidth('32.0h', 250)
			--GetWidgetNoMem('game_lobby_avatar_splash_purchase'):FadeOut(250)
		end

		GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):SetEnabled(altCardTable[newTarget].Available or false)

		GetWidgetNoMem('game_lobby_card_avatar_top_parent'):ScaleWidth(GetWidgetNoMem('game_lobby_card_avatar_name_container'):GetWidth(), 150)

		GetWidgetNoMem('game_lobby_card_avatar_name_container'):FadeIn(300)

		if (altCardTable[newTarget].Name) and (altCardTable[newTarget].TypeName) and NotEmpty(altCardTable[newTarget].Name) and NotEmpty(altCardTable[newTarget].TypeName) then

			local avatarCode = sub(altCardTable[newTarget].Name, 2)
			local heroEntity = altCardTable[newTarget].TypeName

			-- Default Checkbox
			GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):SetCallback('onevent', function()
				local db_av = GetDBEntry('def_av_'..heroEntity, 'nil', false, false, false)
				if (db_av == avatarCode) then
					GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):SetButtonState(1)
				else
					GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):SetButtonState(0)
				end
			end)

			GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):SetCallback('onclick', function()
				Game_Lobby.SetDefaultHeroAvatar(heroEntity, avatarCode)
			end)

			GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):RefreshCallbacks()

			GetWidgetNoMem('game_lobby_card_avatar_default_checkbox'):DoEvent()

			-- Purchase Button
			if (altCardTable[newTarget].Available == false) and (not CanAccessAltAvatar(heroEntity..altCardTable[newTarget].Name)) then
				local gold = altCardTable[newTarget].Cost
				local silver = altCardTable[newTarget].PremiumCost
				if gold and gold >= 9001 and gold ~= 9006 then	-- xx only cases
					Game_Lobby.doubleClickType = -1
					GetWidgetNoMem('game_lobby_card_purchase_btn'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_coins_btn'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_coins_btn_2'):SetVisible(0)
				elseif (silver) and (silver > 0) and (silver < 9001) and (GetCvarInt('_gLobbyLastTotalSilverCoins') >= silver) then
					Game_Lobby.doubleClickType = 1
					GetWidgetNoMem('game_lobby_card_purchase_btn'):SetVisible(1)
					GetWidgetNoMem('game_lobby_card_coins_btn'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetVisible(1)
					GetWidgetNoMem('game_lobby_card_coins_btn_2'):SetVisible(0)
				elseif (gold) and (gold > 0) and (gold < 9001) and (GetCvarInt('_gLobbyLastTotalCoins') >= gold) then
					Game_Lobby.doubleClickType = 1
					GetWidgetNoMem('game_lobby_card_purchase_btn'):SetVisible(1)
					GetWidgetNoMem('game_lobby_card_coins_btn'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetVisible(1)
					GetWidgetNoMem('game_lobby_card_coins_btn_2'):SetVisible(0)
				elseif ((gold) and (gold > 0) and (gold < 9001)) or ((silver) and (silver > 0) and (silver < 9001)) then
					Game_Lobby.doubleClickType = -1
					GetWidgetNoMem('game_lobby_card_purchase_btn'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_coins_btn'):SetVisible(1)
					GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_coins_btn_2'):SetVisible(1)
				else
					Game_Lobby.doubleClickType = -1
					GetWidgetNoMem('game_lobby_card_purchase_btn'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_coins_btn'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetVisible(0)
					GetWidgetNoMem('game_lobby_card_coins_btn_2'):SetVisible(0)
				end
			else
				Game_Lobby.doubleClickType = -1
				GetWidgetNoMem('game_lobby_card_purchase_btn'):SetVisible(0)
				GetWidgetNoMem('game_lobby_card_coins_btn'):SetVisible(0)
				GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetVisible(0)
				GetWidgetNoMem('game_lobby_card_coins_btn_2'):SetVisible(0)
			end


			local gold = altCardTable[newTarget].Cost
			if gold then
				GetWidgetNoMem('game_lobby_card_plinko_btn_2'):SetVisible(gold == 9003)
				GetWidgetNoMem('game_lobby_card_plinko_btn'):SetVisible(gold == 9003)
				GetWidgetNoMem('game_lobby_card_esports_btn_2'):SetVisible(gold == 9004)
				GetWidgetNoMem('game_lobby_card_esports_btn'):SetVisible(gold == 9004)
				GetWidgetNoMem('game_lobby_card_quests_btn_2'):SetVisible(gold == 9005)
				GetWidgetNoMem('game_lobby_card_quests_btn'):SetVisible(gold == 9005)
			end

			GetWidgetNoMem('game_lobby_card_purchase_btn'):SetCallback('onevent', function()
				PlaySound('shared/sounds/ui/button_click_02.wav')

				c.lastUserViewingCard = c.userViewingCard

				Set('_globby_buyavatar_heroname', heroEntity, 'string')
				Set('_globby_buyavatar_avatarcode', avatarCode, 'string')
				Set('_globby_buyavatar_avatarname', altCardTable[newTarget].AvatarDisplayName or altCardTable[newTarget].DisplayName  or '', 'string')
				Set('_globby_buyavatar_SilverCost', altCardTable[newTarget].PremiumCost or 0, 'int')
				Set('_globby_buyavatar_cost', altCardTable[newTarget].Cost or 0, 'int')
				Set('_globby_buyavatar_premium', altCardTable[newTarget].Premium or 'false', 'bool')

				if (altCardTable[newTarget].Cost) --[[and (altCardTable[newTarget].Cost > 0)]] then -- now case GC=0 dealt same as GC=9006
					GetWidgetNoMem('globby_buyavatar_confirmationPrem'):DoEventN(0)
					GetWidgetNoMem('globby_buyavatar_confPrem_heroname'):DoEventN(0)
					GetWidgetNoMem('globby_buyavatar_confPrem_goldcost'):DoEventN(0)
					GetWidgetNoMem('globby_buyavatar_confPrem_silvercost'):DoEventN(0)
					GetWidgetNoMem('globby_buyavatar_confPrem_goldbtn'):DoEvent()
					GetWidgetNoMem('globby_buyavatar_confPrem_silverbtn'):DoEvent()
				else
					GetWidgetNoMem('globby_buyavatar_confirmation'):DoEventN(0)
					GetWidgetNoMem('globby_buyavatar_conf_heroname'):DoEventN(0)
					GetWidgetNoMem('globby_buyavatar_conf_goldcost'):DoEventN(0)
					GetWidgetNoMem('globby_buyavatar_conf_silvercost'):DoEventN(0)
				end

			end)
			GetWidgetNoMem('game_lobby_card_purchase_btn'):RefreshCallbacks()

			GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetCallback('onevent', function()
				PlaySound('shared/sounds/ui/button_click_02.wav')

				Set('_globby_buyeap_heroname', heroEntity, 'string')
				Set('_globby_buyeap_avatarcode', sub(altCardTable[Game_Lobby.selectedEAPBundle].Name, 2), 'string')
				Set('_globby_buyeap_avatarname', Translate('mstore_eap_bundle_'..Game_Lobby.selectedEAPBundle), 'string')
				Set('_globby_buyeap_SilverCost', altCardTable[Game_Lobby.selectedEAPBundle].PremiumCost or 0, 'int')
				Set('_globby_buyeap_cost', altCardTable[Game_Lobby.selectedEAPBundle].Cost or 0, 'int')
				Set('_globby_buyeap_premium', altCardTable[Game_Lobby.selectedEAPBundle].Premium or 'false', 'bool')
				Set('_globby_buyeap_productID', altCardTable[Game_Lobby.selectedEAPBundle].ProductID or '-1', 'string')

				c.userViewingCard = 1
				c.lastUserViewingCard = c.userViewingCard
				local tempHeroEntity = altCardTable[Game_Lobby.selectedEAPBundle].TypeName	or altCardTable[Game_Lobby.selectedEAPBundle].Name or ''
				Set('_gLobbyHeroPurchaseEntity', tempHeroEntity, 'string')

				GetWidgetNoMem('globby_buyeap_confirmation'):DoEventN(0)
				GetWidgetNoMem('globby_buyeap_conf_heroname'):DoEventN(0)
				GetWidgetNoMem('globby_buyeap_conf_goldcost'):DoEventN(0)

			end)
			GetWidgetNoMem('game_lobby_card_purchase_btn_2'):RefreshCallbacks()

			local trialInfo = GetTrialInfo(heroEntity, avatarCode)
			if (NotEmpty(trialInfo)) then
				local cardLabel = Translate('compendium_trial_info').." "..Translate('compendium_trial_infohead')..trialInfo..Translate('compendium_trial_infotail')
				GetWidget('game_lobby_trial_label'):SetText(cardLabel)
				GetWidget('game_lobby_trial_label'):SetVisible(true)
				GetWidget('game_lobby_coupon_panel'):SetVisible(false)
				GetWidget('game_lobby_gca_panel'):SetVisible(false)
			else
				local couponTable = GetCardsInfo(heroEntity, avatarCode)
				local bIsGCABenifit = IsGCABenifitAltAvatar(heroEntity, avatarCode)
				if bIsGCABenifit then
					GetWidget('game_lobby_trial_label'):SetVisible(false)
					GetWidget('game_lobby_coupon_panel'):SetVisible(false)
					GetWidget('game_lobby_gca_panel'):SetVisible(true)
				elseif couponTable and (#couponTable > 0) then
					local cardLabel = Translate('compendium_coupon')
					GetWidget('game_lobby_trial_label'):SetVisible(false)
					GetWidget('game_lobby_coupon_panel'):SetVisible(true)
					GetWidget('game_lobby_gca_panel'):SetVisible(false)
				else
					GetWidget('game_lobby_trial_label'):SetVisible(false)
					GetWidget('game_lobby_coupon_panel'):SetVisible(false)
					GetWidget('game_lobby_gca_panel'):SetVisible(false)
				end
			end

			-- Select Button
			if (altCardTable[newTarget].Available) and ((CanAccessHeroProduct(heroEntity)) or (IsEarlyAccessHero(heroEntity) and CanAccessEarlyAccessProduct(heroEntity))) then
				Game_Lobby.doubleClickType = 0
				GetWidgetNoMem('game_lobby_card_select_btn'):SetVisible(true)
				GetWidgetNoMem('game_lobby_card_select_btn_2'):SetVisible(true)
			else
				GetWidgetNoMem('game_lobby_card_select_btn'):SetVisible(false)
				GetWidgetNoMem('game_lobby_card_select_btn_2'):SetVisible(false)
			end

			GetWidgetNoMem('game_lobby_card_select_btn'):SetCallback('onevent', function()
				PlaySound('shared/sounds/ui/button_click_02.wav')
				if GetCvarBool('_game_lobby_setPotentialAvatar') then
					SetPotentialHero2('' .. heroEntity .. '', '' .. avatarCode ..'')
				else
					if CanCaptainSpawnHero() then
						SpawnHero('' .. heroEntity ..'')
					end
					SelectAvatar('' .. avatarCode ..'')
				end
				GetWidgetNoMem('altav_full'):DoEventN(1, 2)
			end)

			GetWidgetNoMem('game_lobby_card_select_btn'):SetCallback('onrightclick', function()
				PlaySound('shared/sounds/ui/button_click_02.wav')
				GetWidgetNoMem('altav_full'):DoEventN(1, 2)
				SetPotentialHero2('' .. heroEntity .. '', '' .. avatarCode ..'')
			end)
			GetWidgetNoMem('game_lobby_card_select_btn'):RefreshCallbacks()

			GetWidgetNoMem('game_lobby_card_select_btn_2'):SetCallback('onevent', function()
				PlaySound('shared/sounds/ui/button_click_02.wav')
				if GetCvarBool('_game_lobby_setPotentialAvatar') then
					SetPotentialHero2('' .. heroEntity .. '', '' .. avatarCode ..'')
				else
					SpawnHero('' .. heroEntity ..'')
					SelectAvatar('' .. avatarCode ..'')
				end
				GetWidgetNoMem('altav_full'):DoEventN(1, 2)
			end)

			GetWidgetNoMem('game_lobby_card_select_btn_2'):SetCallback('onrightclick', function()
				PlaySound('shared/sounds/ui/button_click_02.wav')
				GetWidgetNoMem('altav_full'):DoEventN(1, 2)
				SetPotentialHero2('' .. heroEntity .. '', '' .. avatarCode ..'')
			end)
			GetWidgetNoMem('game_lobby_card_select_btn_2'):RefreshCallbacks()

		else
			Game_Lobby.doubleClickType = -1
			GetWidgetNoMem('game_lobby_card_select_btn'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_select_btn_2'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_purchase_btn'):SetVisible(false)
			GetWidgetNoMem('game_lobby_card_purchase_btn_2'):SetVisible(false)
		end

		-- 2d
		GetWidgetNoMem('game_lobby_card_avatar_bottom_parent'):BringToFront()
		GetWidgetNoMem('game_lobby_card_avatar_top_parent'):BringToFront()
		GetWidgetNoMem('game_lobby_eap_footer'):BringToFront()
	end
end

local function SortCardTable()
	local centerPos = (CARDS_MAX_DISPLAYED % 2) + 1
	local cardOffset = (centerPos - c.userViewingCard)
	local cardOffCenter = 0
	local flip = -1

	for index, cardTable in ipairs(c.cards) do
		cardOffCenter = ((centerPos - index) - cardOffset)
		flip = -1
		if (cardOffCenter < 0) then
			flip = 1
			cardOffCenter = cardOffCenter * -1
		end

		if (cardOffCenter == 0) then
			cardTable.doEvent = 1
		else
			cardTable.doEvent = 0
		end

		-- cards appear to move -- in a circle
		if (cardOffCenter > (centerPos + 1)) then
			cardOffCenter = centerPos + 1
			if (c.Card.default.hideSideCards) then
				cardTable.hide = true
			else
				cardTable.hide = false
			end
		else
			cardTable.hide = false
		end

		local reducePerTier = c.Card.default.reducePerTier or CARDS_REDUCTION_PER_TIER

		local width = GetWidgetNoMem('game_lobby_card_spawn_target'):GetWidthFromString(c.Card.default.width)
		cardTable.lastwidth	= cardTable.width
		cardTable.width		=		(width * (reducePerTier ^ cardOffCenter) )

		cardTable.lastx 	= 		cardTable.x
		if (cardOffCenter == 0) then
			cardTable.x			=		c.Card.default.x + ((width - (width * (reducePerTier ^ cardOffCenter) )) * flip * 1.3) + (c.Card.default.xMod * (width * (reducePerTier ^ (0.3 * cardOffCenter)) ) * flip * cardOffCenter)
		else
			cardTable.x			=		c.Card.default.x + ((width - (width * (reducePerTier ^ cardOffCenter) )) * flip * 1.3) + (c.Card.default.xMod * (width * (reducePerTier ^ (0.3 * cardOffCenter)) ) * flip * cardOffCenter) + (width * 0.1 * flip)
		end

		local height = GetWidgetNoMem('game_lobby_card_spawn_target'):GetHeightFromString(c.Card.default.height)
		cardTable.lastheight	= cardTable.height
		cardTable.height		=		(height * (reducePerTier ^ cardOffCenter) )

		local color = cardOffCenter/5 --(reducePerTier ^ cardOffCenter)
		cardTable.color		=	'0 0 0 ' .. color

	end

	if ((c.userViewingCard + 1) <= #c.cards) then
		GetWidgetNoMem('game_lobby_card_next_btn'):FadeIn(150)
	else
		GetWidgetNoMem('game_lobby_card_next_btn'):FadeOut(150)
	end
	if ((c.userViewingCard - 1) >= 1) then
		GetWidgetNoMem('game_lobby_card_prev_btn'):FadeIn(150)
	else
		GetWidgetNoMem('game_lobby_card_prev_btn'):FadeOut(150)
	end
end

local function ChangeViewedCard(newTarget)
	c.userViewingCard = newTarget
	UpdateSelectedAvatar(c.userViewingCard)
	SortCardTable()
	ResizeAndAnimateCards()
	SetCardOrder()
end

local function ShowCardInterface()
	if (Game_Lobby) then
		Game_Lobby.contextActive = Game_Lobby.contextActive or {}
		Game_Lobby.contextActive.libcards = true
	end
	GetWidgetNoMem('game_lobby_card_parent'):SetVisible(true)
end

local function HideCardInterface()
	if (GetWidgetNoMem('game_lobby_blocker', nil, true)) then
		GetWidgetNoMem('game_lobby_blocker'):SetVisible(false)
		GetWidgetNoMem('game_lobby_card_parent'):SetVisible(false)
		GetWidgetNoMem('game_lobby_card_prev_btn'):SetVisible(false)
		GetWidgetNoMem('game_lobby_card_next_btn'):SetVisible(false)
	end
end

local function DestroyCards()
	HideCardInterface()
	c.cards = {}
	c.userViewingCard = 1
	c.totalActiveCards = 0
	groupfcall('game_lobby_card_widgets', function(index, widget, groupName) widget:Destroy() end)

	-- e('Game_Lobby.contextActive.libcards', Game_Lobby.contextActive.libcards)

	if (Game_Lobby) and (Game_Lobby.contextActive) and (Game_Lobby.contextActive.libcards) then
		Game_Lobby.contextActive.libcards = false
		interface:UICmd("DeleteResourceContext('libcards')")
	end
end

-- create actual card widget
local function InstantiateCard(cardTable)
	if (c.totalActiveCards < CARDS_MAX_INSTANTIATED) then
		c.totalActiveCards = c.totalActiveCards + 1
		if (GetWidgetNoMem(cardTable.TEMPLATE..'_parent_'..c.totalActiveCards, nil, true) == nil) then
			c.ActiveTemplate = cardTable.TEMPLATE
			if (cardTable.Name) and NotEmpty(cardTable.Name) then
				cardTable.Name = '.' .. cardTable.Name
			end

			local ultimateAvatar = cardTable.collectorsEditionSet or 'false'
			local isNew = cardTable.isNew or 'false'
			local Premium = cardTable.Premium or 'false'
			local Available = cardTable.Available or 'false'
			local Status = cardTable.Status or ''
			local newPurchase = cardTable.NewPurchase or 'false'
			local useStoreEffects = true
			if (cardTable.TypeName) and ( (cardTable.TypeName == 'Hero_Empath') or (cardTable.TypeName == 'Hero_Gemini') or (cardTable.TypeName == 'Hero_ShadowBlade') or (cardTable.TypeName == 'Hero_Dampeer') ) then
				useStoreEffects = false
			end

			GetWidgetNoMem('game_lobby_card_spawn_target'):Instantiate(cardTable.TEMPLATE,
				'index'			,	c.totalActiveCards,
				'x'				,	cardTable.x or '',
				'y'				,	cardTable.y or '',
				'width'			,	cardTable.width or '',
				'height'		,	cardTable.height or '',
				'color'			,	cardTable.color or '',
				'header'		,	cardTable.HEADER or '',
				'subheader'		,	cardTable.SUBHEADER or '',
				'icon'			,	cardTable.ICON or '',
				'type'			,	cardTable.TYPE or '',
				'startdate'		,	cardTable.STARTDATE or '',
				'enddate'		,	cardTable.ENDDATE or '',
				'checkmark'		,	cardTable.CHECKMARK or '',
				'rewardinfo1'	,	cardTable.REWARDINFO1 or '',
				'rewardinfo2'	,	cardTable.REWARDINFO2 or '',
				'rewardinfo3'	,	cardTable.REWARDINFO3 or '',

				'model'			,	cardTable.Model or '',
				'heroEntity'	,	cardTable.TypeName or '',
				'altCode'		,	cardTable.Name or '',
				'scale'			,	cardTable.Scale or '',
				'pos'			,	cardTable.Pos or '',
				'angles'		,	cardTable.Angles or '',

				'available'		,	tostring(Available) or '',
				'status'		,	tostring(Status) or '',
				'displayname'	,	cardTable.DisplayName or '',
				'goldcost'		,	cardTable.PremiumCost or '',
				'silvercost'	,	cardTable.Cost or '',
				'avatarname'	,	cardTable.AvatarDisplayName or '',
				'newpurchase'	, 	tostring(newPurchase),
				'premium'		,	tostring(Premium),
				'new'			,	tostring(isNew),
				'ultimateAvatar',	tostring(ultimateAvatar),
				'usestorefx'	,	tostring(useStoreEffects)
			)
		end
	end
end

local function CreateCardTable(rewardsTable, targetCardIndex, isEAP)
	DestroyCards()
	GetWidgetNoMem('game_lobby_card_spawn_target'):Sleep(1, function()

		c.userViewingCard = targetCardIndex

		c.cards = {}
		-- Card object creation
		c.Card = {}
		c.Card.default = {x=0, lastx=0, xMod=0, y=0, width='77.6h', height='24h', lastwidth='57.6h', lastheight='18h', valign='center', align='center', TEMPLATE='generic_card_template'}
		c.Card.mt = {}

		function c.Card.new(cardParameters)
			cardParameters = cardParameters or {}
			setmetatable(cardParameters, c.Card.mt)
			return cardParameters
		end

		function c.Card.mt.__index(table, key)
			return c.Card.default[key]
		end

		-- turn rewards info into cards
		for index, rewardTable in ipairs(rewardsTable) do
			c.Card.default = rewardTable.DEFAULTS or c.Card.default
			table.insert(c.cards, c.Card.new(rewardTable))
		end
		-- sort cards with offset
		SortCardTable()

		-- instantiate card ui object
		for index, cardTable in ipairs(c.cards) do
			InstantiateCard(cardTable)
		end

		GetWidgetNoMem('game_lobby_card_spawn_target'):Sleep(1, function()
			ResizeAndAnimateCards()
			SetCardOrder()
		end)

		UpdateSelectedAvatar(targetCardIndex, isEAP)

		ShowCardInterface()

		if isEAP then Game_Lobby.SelectBundle(_, 1) end
	end)
end

function Game_Lobby:RegisterCard()
	SetCardOrder()
end

function Game_Lobby:NextViewedCard()
	if (c.userViewingCard + 1) <= #c.cards then
		ChangeViewedCard(c.userViewingCard + 1)
	end
end

function Game_Lobby:PrevViewedCard()
	if (c.userViewingCard - 1) >= 1 then
		ChangeViewedCard(c.userViewingCard - 1)
	end
end

function Game_Lobby:SetCurrentCard(value)
	if tonumber(value) and (tonumber(value) <= #c.cards) and (tonumber(value) >= 1) then
		if (c.userViewingCard == tonumber(value)) then
			ChangeViewedCard(tonumber(value))
			--GetWidgetNoMem('game_lobby_card_select_btn'):DoEvent()
		else
			ChangeViewedCard(tonumber(value))
		end
	end
end

function Game_Lobby:QuickSelectAvatar(value)
	if tonumber(value) and (tonumber(value) <= #c.cards) and (tonumber(value) >= 1) then
		 Game_Lobby:SetCurrentCard(value)
		 if (Game_Lobby.doubleClickType == 0) then
		 	GetWidgetNoMem('game_lobby_card_select_btn'):DoEvent()
		 elseif (Game_Lobby.doubleClickType == 1) then
		 	GetWidgetNoMem('game_lobby_card_purchase_btn'):DoEvent()
		 end
	end
end

local function RefreshUpgrades()
	if (GetWidgetNoMem('game_lobby_blocker', nil, true)) and not (GetWidget('globby_PurchaseHero'):IsVisible()) then
		Game_Lobby.ClickedViewAvatars(Game_Lobby.lastSelectedHeroEntity, c.lastUserViewingCard or 1, nil)
	end
end

interface:RegisterWatch('InfosRefreshed', RefreshUpgrades)
interface:RegisterWatch('UpgradesRefreshed', RefreshUpgrades)


local function GLGamePhaseExtended(self, gamePhaseExtended)
	Set('ui_gamePhaseExtended', gamePhaseExtended, 'int')
end
interface:RegisterWatch('GamePhaseExtended', GLGamePhaseExtended)

----------------------------------------------------------
--														--
----------------------------------------------------------

function Game_Lobby:DisplayCardception(rewards, targetCardIndex, isEAP)
	if (rewards) and (#rewards > 0) then
		c.userViewingCard = targetCardIndex or 1
		CreateCardTable(rewards, c.userViewingCard, isEAP)
		ShowCardInterface()
	else
		println('^r Game_Lobby Error: DisplayCardception has no table')
	end
end

function Game_Lobby:HideCardception()
	Set('ui_game_lobby_store_active', 'false', 'bool')
	DestroyCards()
end

local function UpdateEAPHeroModels(selectedBundle)
	if GetWidgetNoMem('altavatar_card_template_2_model_1', nil, true) and GetWidgetNoMem('altavatar_card_template_2_model_2', nil, true) and GetWidgetNoMem('altavatar_card_template_2_model_3', nil, true) then
		if (selectedBundle == 3) then
			GetWidgetNoMem('altavatar_card_template_2_model_1'):DoEventN(4)
			GetWidgetNoMem('altavatar_card_template_2_model_2'):DoEventN(4)
			GetWidgetNoMem('altavatar_card_template_2_model_3'):DoEventN(4)
			GetWidgetNoMem('gl_eap_selected_bundle_label'):SetText(Translate('mstore_eap_bundle_3'))
			GetWidgetNoMem('gl_eap_purchase_cost_label'):SetText(Game_Lobby.eapBundleGoldCost3)
			Set('ui_eapSelectedBundleID', Game_Lobby.eapBundleProductID3, 'string')
			Set('ui_eapSelectedBundleGold', Game_Lobby.eapBundleGoldCost3, 'string')
			Set('ui_eapSelectedBundleSilver', Game_Lobby.eapBundleSilverCost3, 'string')
			GetWidgetNoMem('gl_eap_left_star_1'):SetVisible(1)
			GetWidgetNoMem('gl_eap_right_star_1'):SetVisible(1)
			GetWidgetNoMem('gl_eap_left_star_2'):SetVisible(0)
			GetWidgetNoMem('gl_eap_right_star_2'):SetVisible(0)
		elseif (selectedBundle == 2) then
			GetWidgetNoMem('altavatar_card_template_2_model_1'):DoEventN(4)
			GetWidgetNoMem('altavatar_card_template_2_model_2'):DoEventN(4)
			GetWidgetNoMem('altavatar_card_template_2_model_3'):DoEventN(5)
			GetWidgetNoMem('gl_eap_selected_bundle_label'):SetText(Translate('mstore_eap_bundle_2'))
			GetWidgetNoMem('gl_eap_purchase_cost_label'):SetText(Game_Lobby.eapBundleGoldCost2)
			Set('ui_eapSelectedBundleID', Game_Lobby.eapBundleProductID2, 'string')
			Set('ui_eapSelectedBundleGold', Game_Lobby.eapBundleGoldCost2, 'string')
			Set('ui_eapSelectedBundleSilver', Game_Lobby.eapBundleSilverCost2, 'string')
			GetWidgetNoMem('gl_eap_left_star_1'):SetVisible(1)
			GetWidgetNoMem('gl_eap_right_star_1'):SetVisible(0)
			GetWidgetNoMem('gl_eap_left_star_2'):SetVisible(0)
			GetWidgetNoMem('gl_eap_right_star_2'):SetVisible(1)
		elseif (selectedBundle == 1) then
			GetWidgetNoMem('altavatar_card_template_2_model_1'):DoEventN(5)
			GetWidgetNoMem('altavatar_card_template_2_model_2'):DoEventN(4)
			GetWidgetNoMem('altavatar_card_template_2_model_3'):DoEventN(5)
			GetWidgetNoMem('gl_eap_selected_bundle_label'):SetText(Translate('mstore_eap_bundle_1'))
			GetWidgetNoMem('gl_eap_purchase_cost_label'):SetText(Game_Lobby.eapBundleGoldCost1)
			Set('ui_eapSelectedBundleID', Game_Lobby.eapBundleProductID1, 'string')
			Set('ui_eapSelectedBundleGold', Game_Lobby.eapBundleGoldCost1, 'string')
			Set('ui_eapSelectedBundleSilver', Game_Lobby.eapBundleSilverCost1, 'string')
			GetWidgetNoMem('gl_eap_left_star_1'):SetVisible(0)
			GetWidgetNoMem('gl_eap_right_star_1'):SetVisible(0)
			GetWidgetNoMem('gl_eap_left_star_2'):SetVisible(1)
			GetWidgetNoMem('gl_eap_right_star_2'):SetVisible(1)
		end
	end
end

local function ResetEAPScreenStatus()
	Game_Lobby.selectedEAPBundle = 1
	UpdateEAPHeroModels(Game_Lobby.selectedEAPBundle)
end

local function populateEAPItem(index, heroProductID, entityName, timestamp, goldCost, silverCost, alt1, alt2, alt1productid, alt1name, alt1goldcost, alt1silvercost, alt2productid, alt2name, alt2goldcost, alt2silvercost)

	local widget = GetWidgetNoMem('store_eap_header_left_label_1')
	if widget ~= nil then widget:SetText(alt1name) end
	widget = GetWidgetNoMem('store_eap_header_right_label_1')
	if widget ~= nil then widget:SetText(alt2name) end

	goldCost, silverCost = AdjustGoldSiverPrice(tonumber(goldCost), tonumber(silverCost))
	alt1goldcost, alt1silvercost = AdjustGoldSiverPrice(tonumber(alt1goldcost), tonumber(alt1silvercost))
	alt2goldcost, alt2silvercost = AdjustGoldSiverPrice(tonumber(alt2goldcost), tonumber(alt2silvercost))

	Game_Lobby.eapBundleGoldCost1 = goldCost
	Game_Lobby.eapBundleGoldCost2 = alt1goldcost
	Game_Lobby.eapBundleGoldCost3 = alt2goldcost
	Game_Lobby.eapBundleSilverCost1 = silverCost
	Game_Lobby.eapBundleSilverCost2 = alt1silvercost
	Game_Lobby.eapBundleSilverCost3 = alt2silvercost
	Game_Lobby.eapBundleProductID1 = heroProductID
	Game_Lobby.eapBundleProductID2 = alt1productid
	Game_Lobby.eapBundleProductID3 = alt2productid

	Set('ui_eapSelectedBundleID', heroProductID, 'string')
	Set('ui_eapSelectedBundleGold', goldCost, 'string')
	Set('ui_eapSelectedBundleSilver', silverCost, 'string')

	ResetEAPScreenStatus()
end


function Game_Lobby.MicroStoreResults(_, ...)
	if (Game_Lobby.requestingStoreData) and GetCvarBool('ui_game_lobby_store_active') then

		altCardTable = {}

		local productIDs = explode('|', arg[3])
		local productNames = explode('|', arg[4])
		local productPrices = explode('|', arg[5])
		local productAlreadyOwned = explode('|', arg[6])
		local productLocalContent = explode('|', arg[13])
		local purchasable = explode('|', arg[51])
		local premium_mmp_cost = explode('|', arg[36])
		local productCodes = explode('|', arg[21])
		local productTimes = explode('|', arg[48])
		local productTimesSplit = {}
		local productCodeSplit = {}

		local avatarCode, heroEntity, db_av
		local v
		local isNew, collectorsEditionSet

		Game_Lobby.productEligibility = {}
		if (arg[60]) and NotEmpty(arg[60]) then
			local productEligibilityTable = explode('|', arg[60])
			for index, eligibilityString in pairs(productEligibilityTable) do
				local eligibilityTable = explode('~', eligibilityString)
				local productID = eligibilityTable[1]
				Game_Lobby.productEligibility[productID]					 = {}
				Game_Lobby.productEligibility[productID].productID		 = eligibilityTable[1]
				Game_Lobby.productEligibility[productID].eligbleID		 = eligibilityTable[2]
				Game_Lobby.productEligibility[productID].eligible		 = eligibilityTable[3]
				Game_Lobby.productEligibility[productID].goldCost		 = eligibilityTable[4]
				Game_Lobby.productEligibility[productID].silverCost		 = eligibilityTable[5]
				Game_Lobby.productEligibility[productID].requiredProducts = eligibilityTable[6]
			end
		end

		local function AddAltToTable(i)
			v = {}
			productCodeSplit[i] = explode('.', productCodes[i])
			avatarCode = productCodeSplit[i][2]
			heroEntity = productCodeSplit[i][1]

			productTimesSplit[i] = explode(',', productTimes[i])

			if (productCodes[i]) then

				if (Game_Lobby.avatarDataTable) and (productIDs[i]) and (Game_Lobby.avatarDataTable[productIDs[i]]) then
					isNew = (Game_Lobby.avatarDataTable[productIDs[i]])[1]
					collectorsEditionSet = (Game_Lobby.avatarDataTable[productIDs[i]])[2]
				else
					isNew = false
					collectorsEditionSet = 0
				end
				v.isNew = isNew
				v.collectorsEditionSet = collectorsEditionSet

				if (productIDs[i] and Game_Lobby.productEligibility and Game_Lobby.productEligibility[productIDs[i]]) then
					if (AtoB(Game_Lobby.productEligibility[productIDs[i]].eligible)) then
						productPrices[i] = Game_Lobby.productEligibility[productIDs[i]].goldCost
						premium_mmp_cost[i] = Game_Lobby.productEligibility[productIDs[i]].silverCost
					end
				end

				v.Scale 		= GetHeroPreviewScaleFromProduct(productCodes[i])
				v.Pos 			= GetHeroPreviewPosFromProduct(productCodes[i])
				v.Angles 		= GetHeroPreviewAnglesFromProduct(productCodes[i])
				v.Model 		= GetHeroPreviewModelPathFromProduct(productCodes[i])
				v.Available 	= CanAccessEarlyAccessProduct(heroEntity)
				v.Name 			= productCodeSplit[i][2]
				v.TypeName		= productCodeSplit[i][1]
				v.DisplayName 	= productNames[i]
				v.ProductID 	= productIDs[i]
				v.Icon 			= productLocalContent[i]
				v.Cost 			= tonumber(productPrices[i])
				v.PremiumCost 	= tonumber(premium_mmp_cost[i])
				v.AvatarDisplayName	= productNames[i]

				v.Cost, v.PremiumCost = AdjustGoldSiverPrice(v.Cost, v.PremiumCost)

				v.TEMPLATE 		= 'altavatar_card_template_2'
				v.DEFAULTS 		= {x=0, lastx=0, xMod=0.40, y=0, width='30h', height='44.4h', lastwidth='44.4h', lastheight='30h', valign='center', align='center', TEMPLATE='altavatar_card_template_2', reducePerTier = 0.85, hideSideCards=true}

				tinsert(altCardTable, v)
			else
				println('^r:Lobby Error: EA Data Invalid: 2')
			end
		end

		productCodeSplit[1] = explode('.', productCodes[1])

		if (not productCodeSplit[1]) or (not productCodeSplit[1][1]) or (not IsEarlyAccessHero(productCodeSplit[1][1])) or (CanAccessEarlyAccessProduct(productCodeSplit[1][1])) then
			println('^r Lobby Error: Hero List EAP and Store EAP data are mismatched.')
			if GetCvarBool('releaseStage_test') or GetCvarBool('releaseStage_dev') then
				Trigger('TriggerDialogBox', 'Lobby Error', 'options_button_ok', 'general_cancel', '', '', 'Hero List EAP and Store EAP data are mismatched.', '')
			end
			return
		end

		AddAltToTable(1)
		AddAltToTable(2)
		AddAltToTable(3)

		Game_Lobby.requestingStoreData = false
		Set('ui_game_lobby_store_active', 'false', 'bool')

		if (#altCardTable == 3) then

			local resort = {}
			tinsert(resort, altCardTable[3])
			tinsert(resort, altCardTable[1])
			tinsert(resort, altCardTable[2])

			Game_Lobby:DisplayCardception(resort, 2, true)

			populateEAPItem('1', productIDs[1], productCodeSplit[1][1], -1, productPrices[1], premium_mmp_cost[1], productCodeSplit[2][2], productCodeSplit[3][2], productIDs[2], productNames[2], productPrices[2], premium_mmp_cost[2], productIDs[3], productNames[2], productPrices[3], premium_mmp_cost[3])

			Set('eapStartTime1', productTimesSplit[1][1], 'int')
			Set('eapEndTime1', productTimesSplit[1][2], 'int')

			GetWidgetNoMem('game_lobby_eap_rl_date_label_1'):DoEvent()
			GetWidgetNoMem('game_lobby_eap_rl_date_label_2'):DoEvent()

			GetWidgetNoMem('game_lobby_eap_footer'):Sleep(1, function() ResetEAPScreenStatus() end)
		else
			println('^r:Lobby Error: EA Data Invalid: 1')
		end
	end
end
--interface:RegisterWatch('MicroStoreResults', MicroStoreResultsEA)

function Game_Lobby.HoverBundle(sourceWidget, index)
	UpdateEAPHeroModels(index)
end

function Game_Lobby.RestoreHoverBundle(sourceWidget, index)
	UpdateEAPHeroModels(Game_Lobby.selectedEAPBundle)
end

function Game_Lobby.SelectBundle(sourceWidget, index)
	Game_Lobby.selectedEAPBundle = tonumber(index)
	UpdateEAPHeroModels(Game_Lobby.selectedEAPBundle)
	GetWidgetNoMem('game_lobby_card_avatar_name'):SetText(altCardTable[Game_Lobby.selectedEAPBundle].AvatarDisplayName or altCardTable[Game_Lobby.selectedEAPBundle].DisplayName  or '')
	GetWidgetNoMem('game_lobby_card_avatar_top_parent'):SetWidth(GetWidgetNoMem('game_lobby_card_avatar_name_container'):GetWidth())
	--GetWidgetNoMem('gl_eap_above_purchase_label'):SetText(Translate('mstore_eap_bundle_'..index))
end



function Game_Lobby:GetHeroPickIndexfromName(heroName)
	for i, bot in ipairs(Game_Lobby.botPickTable) do
		if (bot.hero == heroName) then
			return i
		end
	end

	return nil
end

function Game_Lobby:CreateBotPickTable(_botTable)
	if (_botTable) then 	-- a table was passed, overwrite the table we are using for bot info
		Game_Lobby.botsTable = _botTable
	elseif (GetBotDefinitions) then
		Game_Lobby.botsTable = GetBotDefinitions()
	else
		Game_Lobby.botsTable = Game_Lobby.botsTable
	end

	if (not Game_Lobby.botsTable) then
		e('Game_Lobby.botsTable', Game_Lobby.botsTable)
		return
	end

	Game_Lobby.botPickTable = {}

	local heroAlreadyExists = {}
	local nextOffset = 1
	for i, bot in ipairs(Game_Lobby.botsTable) do
		-- printTable(bot)
		if (bot.sHeroName and bot.sHeroName ~= "") then 	-- don't pick up bots without a hero (DefaultTeamBotBrain)
			if (not heroAlreadyExists[bot.sHeroName]) then
				heroAlreadyExists[bot.sHeroName] = true

				local botInfoTable ={	["name"] = bot.sName,
										["def"] = bot.sName,
										["desc"] = bot.sDescription,
										["version"] =  " ",
										["id"] = i,
										["used"] = false,
										["kickName"] = bot.sDefaultPlayerName
									}

				Game_Lobby.botPickTable[nextOffset] = {}
				Game_Lobby.botPickTable[nextOffset].hero = bot.sHeroName
				Game_Lobby.botPickTable[nextOffset].numBots = 1
				Game_Lobby.botPickTable[nextOffset].bots = {}
				table.insert(Game_Lobby.botPickTable[nextOffset].bots, botInfoTable)

				nextOffset = nextOffset + 1
			else
				-- another bot of an already existing her
				local offset = Game_Lobby:GetHeroPickIndexfromName(bot.sHeroName)
				local botInfoTable ={	["name"] = bot.sName,
										["def"] = bot.sName,
										["desc"] = bot.sDescription,
										["version"] = " ",
										["id"] = i,
										["used"] = false,
										["kickName"] = bot.sDefaultPlayerName
									}

				table.insert(Game_Lobby.botPickTable[offset].bots, botInfoTable)
				Game_Lobby.botPickTable[offset].numBots = Game_Lobby.botPickTable[offset].numBots + 1
			end
		end
	end

	--sort the table by heroname
	local sortFunc = function(a,b) return (a.hero < b.hero) end
	table.sort(Game_Lobby.botPickTable, sortFunc)
end

function Game_Lobby:PopulateBotPickEntry(botPlateID, botPickIndex)
	local plateWidget = GetWidget("glb_botpickplate_"..botPlateID)
	if (botPickIndex and (Game_Lobby.botPickTable) and Game_Lobby.botPickTable[botPickIndex]) then
		GetWidget("glb_botpickplate_icon_"..botPlateID):SetTexture(interface:UICmd("GetHeroIconPathFromProduct('"..Game_Lobby.botPickTable[botPickIndex].hero.."')"))
		GetWidget("glb_botpickplate_index_"..botPlateID):SetText(tostring(botPickIndex))
		plateWidget:SetVisible(1)
	else
		plateWidget:SetVisible(0)
	end
end

function Game_Lobby:BotListSlide(slider, value)
	value = tonumber(value)
	Game_Lobby.botPickScrollOffsets = value
	Game_Lobby:PopulateBotPickList()
end

function Game_Lobby:UpdateBotScrollbar()
	local botCount = 1
	if (not ALLOW_DUPE_BOTS) then
		-- count number of bots to be displayed
		for i,hero in ipairs(Game_Lobby.botPickTable) do
			local botUsed = false
			for j,bot in ipairs(hero.bots) do
				if (bot.used) then
					botUsed = true
					break
				end
			end

			if (not botUsed) then
				botCount = botCount + 1
			end
		end
	else
		botCount = #Game_Lobby.botPickTable
	end

	rows = math.ceil(botCount / 6)
	local max = rows - 2
	if (max < 0) then max = 0 end
	local scrollbar = GetWidget("glb_bot_scrollbar")
	if (tonumber(scrollbar:GetValue()) > max) then
		scrollbar:SetValue(max) end
	scrollbar:SetMaxValue(max)
end

function Game_Lobby:MultiBotListSlide(slider, value)
	value = tonumber(value)
	Game_Lobby.multibotPickScrollOffsets= value
	Game_Lobby:UpdateMultibotPicker()
end

function Game_Lobby:UpdateMultiBotScrollbar(botOffset)
	local numBots = Game_Lobby.botPickTable[botOffset].numBots

	local max = numBots - 2
	if (max < 0) then max = 0 end
	local scrollbar = GetWidget("glb_multibot_scrollbar")
	if (tonumber(scrollbar:GetValue()) > max) then
		scrollbar:SetValue(max) end
	scrollbar:SetMaxValue(max)
end

function Game_Lobby:PopulateRandomBotSlot(botPlateID)
	GetWidget("glb_botpickplate_icon_"..botPlateID):SetTexture("/ui/elements/question_mark.tga")
	GetWidget("glb_botpickplate_index_"..botPlateID):SetText("random")
	GetWidget("glb_botpickplate_"..botPlateID):SetVisible(1)
end

function Game_Lobby:PopulateBotPickList(scrollOffset)
	if (RegisterBotDefinitions) and (not GetCvarBool('ui_bot_definitions_loaded')) then
		RegisterBotDefinitions()
		Set('ui_bot_definitions_loaded', 'true', 'bool')
	end

	if (not Game_Lobby.botPickTable) then
		Game_Lobby:CreateBotPickTable()
	end

	if (not scrollOffset) then
		scrollOffset = Game_Lobby.botPickScrollOffsets
	end

	-- eat up slots above used by bots
	local botOffset = 0
	if (scrollOffset ~= 0) then
		for i=1,(scrollOffset * 6) do
			if (botOffset ~= 0) then
				while (HoN_Matchmaking:CheckAllBotsUsed(botOffset)) do botOffset = botOffset + 1 end
			end
			botOffset = botOffset + 1
		end
	end

	for i=1, 12 do
		if (botOffset == 0) then -- offset 1 is always a random slot
			Game_Lobby:PopulateRandomBotSlot(i)
			botOffset = botOffset + 1
		else
			while (Game_Lobby:CheckAllBotsUsed(botOffset)) do botOffset = botOffset + 1 end

			Game_Lobby:PopulateBotPickEntry(i, botOffset)
			botOffset = botOffset + 1
		end
	end

	Game_Lobby:UpdateBotScrollbar()
end

function Game_Lobby:PopulateMultibotEntry(pickTableIndex, botIndex, slotNumber)
	if (Game_Lobby.botPickTable[pickTableIndex].bots[botIndex]) then
		GetWidget("glb_multibotplate_"..slotNumber.."_icon"):SetTexture(interface:UICmd("GetHeroIconPathFromProduct('"..Game_Lobby.botPickTable[pickTableIndex].hero.."')"))
		GetWidget("glb_multibotplate_"..slotNumber.."_name"):SetText(Translate(Game_Lobby.botPickTable[pickTableIndex].bots[botIndex].name))
		GetWidget("glb_multibotplate_"..slotNumber.."_version"):SetText(" ")
		GetWidget("glb_multibotplate_"..slotNumber.."_desc"):SetText(Translate(Game_Lobby.botPickTable[pickTableIndex].bots[botIndex].desc))
		GetWidget("glb_multibotpickplate_index_"..slotNumber):SetText(tostring(botIndex))
		GetWidget("glb_multibotplate_"..slotNumber):SetVisible(1)
	else
		GetWidget("glb_multibotplate_"..slotNumber):SetVisible(0)
	end
end

function Game_Lobby:UpdateMultibotPicker()
	if (Game_Lobby.multibotPickOffset) then
		Game_Lobby:MultibotPicker(Game_Lobby.multibotPickOffset)
	end
end

function Game_Lobby:MultibotPicker(pickTableOffset)
	interface:UICmd("GetHeroInfo('"..Game_Lobby.botPickTable[pickTableOffset].hero.."');")
	GetWidget("hero_info"):SetVisible(1)

	Game_Lobby.multibotPickOffset = pickTableOffset

	local multibotOffset = 1 + Game_Lobby.multibotPickScrollOffsets
	for i=1, 2 do
		while (Game_Lobby:CheckBotUsageByOffsets(pickTableOffset, multibotOffset)) do multibotOffset = multibotOffset + 1 end
		Game_Lobby:PopulateMultibotEntry(pickTableOffset, multibotOffset, i)
		multibotOffset = multibotOffset + 1
	end

	GetWidget("glb_mp_hero"):SetText(Translate("mstore_"..Game_Lobby.botPickTable[pickTableOffset].hero.."_name"))
	GetWidget("public_games_repick_multibot"):FadeIn(100)
end

function Game_Lobby:SelectMultiBot(self, botListPos)
	if not (Game_Lobby.multibotPickOffset) then return end
	local multibotOffset = tonumber(GetWidget("glb_multibotpickplate_index_"..botListPos):GetValue())

	Game_Lobby:MarkBotUsageByOffsets(Game_Lobby.multibotPickOffset, multibotOffset, true)

	GetWidget("glb_invite_bot"):SetVisible(0)
	GetWidget("glb_invite_bot"):FadeOut(150)
	AddBot(Game_Lobby.repickingSlot[2], Game_Lobby.botPickTable[Game_Lobby.multibotPickOffset].bots[multibotOffset].def)
	Game_Lobby:MarkBotUsageByID(Game_Lobby.repickingSlot[2], true)
	Game_Lobby.repickingSlot = nil
	Game_Lobby.multibotPickOffset = nil

	self:Sleep(125, function()
		Game_Lobby:PopulateBotPickList()
	end)

	GetWidget("public_games_repick_multibot"):FadeOut(150)
end

function Game_Lobby:RandomBots()
	-- find how many bots we need for each team
	local leftTeamNeed = 0
	local rightTeamNeed = 0

	for i=0, 4 do
		if (GetWidget("glb_add_bot_"..i):IsVisible()) then
			leftTeamNeed = leftTeamNeed + 1
		end
	end

	for i=5, 9 do
		if (GetWidget("glb_add_bot_"..i):IsVisible()) then
			rightTeamNeed = rightTeamNeed + 1
		end
	end

	-- make a table of all the available bots
	local botsAvailable = {}
	for i, t in pairs(Game_Lobby.botPickTable) do
		for j=1, #t.bots do
			if not Game_Lobby:CheckBotUsageByOffsets(i, j) then
				table.insert(botsAvailable, {i, j})
			end
		end
	end

	-- not enough bots, this should never happen ~~
	if ((leftTeamNeed + rightTeamNeed) > #botsAvailable) then
		return
	end

	-- pick bots -- team == 1
	for i=1, leftTeamNeed do
		local botOffset = math.random(1, #botsAvailable)
		AddBot(1, Game_Lobby.botPickTable[botsAvailable[botOffset][1]].bots[botsAvailable[botOffset][2]].def)
		Game_Lobby:MarkBotUsageByOffsets(botsAvailable[botOffset][1], botsAvailable[botOffset][2], true)
		table.remove(botsAvailable, botOffset)
	end
	-- team = 2
	for i=1, rightTeamNeed do
		local botOffset = math.random(1, #botsAvailable)
		AddBot(2, Game_Lobby.botPickTable[botsAvailable[botOffset][1]].bots[botsAvailable[botOffset][2]].def)
		Game_Lobby:MarkBotUsageByOffsets(botsAvailable[botOffset][1], botsAvailable[botOffset][2], true)
		table.remove(botsAvailable, botOffset)
	end

	Game_Lobby:PopulateBotPickList()
end

function Game_Lobby:SelectBot(self, botPlateID)
	if (not Game_Lobby.repickingSlot) then return end
	local botOffset = GetWidget("glb_botpickplate_index_"..botPlateID):GetValue()

	if (botOffset == "random") then
		-- make a table of all the available bots
		local botsAvailable = {}
		for i, t in pairs(Game_Lobby.botPickTable) do
			local heroUsed = false
			if ((not ALLOW_DUPE_BOTS)) then
				for j=1, #t.bots do
					if Game_Lobby:CheckBotUsageByOffsets(i, j) then
						heroUsed = true
					end
				end
			end

			if (not heroUsed) then
				for j=1, #t.bots do
					if not Game_Lobby:CheckBotUsageByOffsets(i, j) then
						table.insert(botsAvailable, {i, j})
					end
				end
			end
		end

		local randomBot = math.random(1, #botsAvailable)
		GetWidget("glb_invite_bot"):FadeOut(150)
		AddBot(Game_Lobby.repickingSlot[2], Game_Lobby.botPickTable[botsAvailable[randomBot][1]].bots[botsAvailable[randomBot][2]].def)
		-- mark bot used
		Game_Lobby:MarkBotUsageByOffsets(botsAvailable[randomBot][1], botsAvailable[randomBot][2], true)
	else
		botOffset = tonumber(botOffset)

		if (Game_Lobby.botPickTable[botOffset].numBots > 1) then -- multibot picker
			Game_Lobby:UpdateMultiBotScrollbar(botOffset)
			Game_Lobby:MultibotPicker(botOffset)
			return
		else
			GetWidget("glb_invite_bot"):FadeOut(150)
			AddBot(Game_Lobby.repickingSlot[2], Game_Lobby.botPickTable[botOffset].bots[1].def)
			Game_Lobby:MarkBotUsageByOffsets(botOffset, 1, true)
		end
	end

	Game_Lobby.repickingSlot = nil
	self:Sleep(125, function()
		Game_Lobby:PopulateBotPickList()
	end)
end

function Game_Lobby:WatchBotKicked(_, botName)
	for i,hero in ipairs(Game_Lobby.botPickTable) do
		for j, bot in ipairs(hero.bots) do
			if (bot.kickName == botName) then
				Game_Lobby:MarkBotUsageByOffsets(i, j, false)
				Game_Lobby:PopulateBotPickList()
				break
			end
		end
	end
end
interface:RegisterWatch("LobbyKicked", function(...) Game_Lobby:WatchBotKicked(...) end)

function Game_Lobby:BotJoinHelper(playerName)
	if (playerName == "" or Game_Lobby.botPickTable == nil) then
		return
	end

	for i,hero in ipairs(Game_Lobby.botPickTable) do
		for j, bot in ipairs(hero.bots) do
			if (bot.kickName == playerName) then
				Game_Lobby:MarkBotUsageByOffsets(i, j, true)
				Game_Lobby:PopulateBotPickList()
				break
			end
		end
	end
end

function Game_Lobby:GamePhase(phaseNumber)
	if (tonumber(phaseNumber) == 0) then -- unmark all bots
		Game_Lobby:ClearAllBotUsage()
		Game_Lobby:PopulateBotPickList()
	end
end

function Game_Lobby:GameInfo(allowDupe, canHaveBots)
	local newDupe = AtoB(allowDupe)
	if (ALLOW_DUPE_BOTS ~= newDupe) then
		ALLOW_DUPE_BOTS = newDupe
		Game_Lobby:PopulateBotPickList() -- repopulate to update if bots are marked as used.
	end

	local oldCanHave = GetCvarBool("ui_isBotMatch")
	if string.find(canHaveBots, "botmatch") then
		Set("ui_isBotMatch", true, "bool")
	else
		Set("ui_isBotMatch", false, "bool")
	end

	if (oldCanHave ~= GetCvarBool("ui_isBotMatch")) then -- we swapped, force one or the other
		groupfcall("glb_bot_buttons", function(_, widget, _) widget:DoEventN(5) end)
	end
end

function Game_Lobby:HoverBot(self, botPlateID)
	-- fill out hero info for panel over chat, it will get displayed by the uiscript
	local botOffset = GetWidget("glb_botpickplate_index_"..botPlateID):GetValue()

	if (botOffset == "random") then
		-- hide the hero info
		GetWidget("hero_info"):SetVisible(0)
		-- display the hero name as the title
		GetWidget("glb_heroname"):SetText(Translate("mm3_random_bot"))
		GetWidget("glb_generic"):FadeOut(150)
		GetWidget("glb_title"):FadeOut(150)

		local nameWidget = GetWidget("glb_botname")
		local descWidget = GetWidget("glb_desc")

		nameWidget:SetText("???")
		descWidget:SetText(Translate("mm3_random_desc"))

		GetWidget("glb_heroname"):SetVisible(0)
		nameWidget:SetVisible(0)
		descWidget:SetVisible(0)

		GetWidget("glb_heroname"):FadeIn(150)
		nameWidget:FadeIn(150)
		descWidget:FadeIn(150)
	else
		botOffset = tonumber(botOffset)

		interface:UICmd("GetHeroInfo('"..Game_Lobby.botPickTable[botOffset].hero.."');")

		-- display the hero name as the title
		GetWidget("glb_heroname"):SetText(Translate("mstore_"..Game_Lobby.botPickTable[botOffset].hero.."_name"))
		GetWidget("glb_generic"):FadeOut(150)
		GetWidget("glb_title"):FadeOut(150)

		-- show the bot info on hover
		if (Game_Lobby.botPickTable[botOffset].numBots == 1) then 	-- display the info in place
			local nameWidget = GetWidget("glb_botname")
			local descWidget = GetWidget("glb_desc")

			nameWidget:SetText(Translate(Game_Lobby.botPickTable[botOffset].bots[1].name))
			descWidget:SetText(Translate(Game_Lobby.botPickTable[botOffset].bots[1].desc))

			GetWidget("glb_heroname"):SetVisible(0)
			nameWidget:SetVisible(0)
			descWidget:SetVisible(0)
			GetWidget("glb_heroname"):FadeIn(150)
			nameWidget:FadeIn(150)
			descWidget:FadeIn(150)
		else 	-- there is more than one bot
			local nameWidget = GetWidget("glb_botname")
			local descWidget = GetWidget("glb_desc")

			nameWidget:SetText(Translate("mm3_coop_multiplebots", "count", Game_Lobby.botPickTable[botOffset].numBots))
			descWidget:SetText(Translate("mm3_coop_multiplebots_desc"))

			GetWidget("glb_heroname"):SetVisible(0)
			nameWidget:SetVisible(0)
			descWidget:SetVisible(0)
			GetWidget("glb_heroname"):FadeIn(150)
			nameWidget:FadeIn(150)
			descWidget:FadeIn(150)
		end
	end
end

function Game_Lobby:LeaveBotHover()
	GetWidget("glb_title"):FadeIn(150)
	GetWidget("glb_generic"):FadeIn(150)

	GetWidget("glb_heroname"):FadeOut(150)
	GetWidget("glb_botname"):FadeOut(150)
	GetWidget("glb_desc"):FadeOut(150)
end

function Game_Lobby:RepickBot(self, slotNumber, team)
	Game_Lobby.repickingSlot = {tonumber(slotNumber), team}
end

------------------- These functions are for checking usage, these will all check the allow dups variable
------------------- ALL CHECKS should be ran through these, as then you don't need to worry about checking
------------------- the ALLOW_DUPE variable on your own elsewhere (basically, if allow dupe bots, don't worry about anything)
-- Note: ID is the offset into the botsTable (not the pickTable, but the pickTable bots have an ID member)
function Game_Lobby:MarkBotUsageByID(id, used)
	if (ALLOW_DUPE_BOTS) then return end

	for i=1, #Game_Lobby.botPickTable do
		for j=1, #Game_Lobby.botPickTable[i].bots do
			if (Game_Lobby.botPickTable[i].bots[j].id == id) then
				Game_Lobby.botPickTable[i].bots[j].used = used
				break
			end
		end
	end
end

function Game_Lobby:CheckBotUsageByID(id)
	if (ALLOW_DUPE_BOTS) then return false end

	for i=1, #Game_Lobby.botPickTable do
		for j=1, #Game_Lobby.botPickTable[i].bots do
			if (Game_Lobby.botPickTable[i].bots[j].id == id) then
				return Game_Lobby.botPickTable[i].bots[j].used
			end
		end
	end
end

function Game_Lobby:MarkBotUsageByOffsets(tablePos, botNum, used)
	if (ALLOW_DUPE_BOTS) then return end
	if (not Game_Lobby.botPickTable[tablePos] or not Game_Lobby.botPickTable[tablePos].bots[botNum]) then return end

	Game_Lobby.botPickTable[tablePos].bots[botNum].used = used
end

function Game_Lobby:CheckBotUsageByOffsets(tablePos, botNum)
	if (ALLOW_DUPE_BOTS) then return false end
	if (not Game_Lobby.botPickTable[tablePos] or not Game_Lobby.botPickTable[tablePos].bots[botNum]) then return false end
	return Game_Lobby.botPickTable[tablePos].bots[botNum].used
end

function Game_Lobby:CheckAllBotsUsed(tablePos)
	if (ALLOW_DUPE_BOTS) then return false end
	if (not Game_Lobby.botPickTable or not Game_Lobby.botPickTable[tablePos]) then return false end

	local allUsed
	if (false) then 	-- true to allow dupe heros with different bots scripts
		allUsed = true
		for i=1, #Game_Lobby.botPickTable[tablePos].bots do
			if (not Game_Lobby.botPickTable[tablePos].bots[i].used) then
				allUsed = false
				break
			end
		end
 	else
		allUsed = false
		for i=1, #Game_Lobby.botPickTable[tablePos].bots do
			if (Game_Lobby.botPickTable[tablePos].bots[i].used) then
				allUsed = true
				break
			end
		end
	end

	return allUsed
end

function Game_Lobby:ClearAllBotUsage()
	if (ALLOW_DUPE_BOTS) then return end
	if (not Game_Lobby.botPickTable) then return end

	for i=1, #Game_Lobby.botPickTable do
		for j=1, #Game_Lobby.botPickTable[i].bots do
			Game_Lobby:MarkBotUsageByOffsets(i, j, false)
		end
	end
end
----------------------------- End of usage functions

------------ AP filter stuff -----------------
function Game_Lobby:RegisterFavoriteButton(widget, heroName)
	-- empty hero names exist for blank slots
	if (NotEmpty(heroName)) then
		if (not Game_Lobby.filterInfoList[heroName]) then
			Game_Lobby.filterInfoList[heroName] = {}
		end

		Game_Lobby.filterInfoList[heroName].favoriteButton = widget

		-- set the button state
		if (Game_Lobby.favoriteHeroes[heroName]) then
			widget:SetButtonState(0)
		else
			widget:SetButtonState(1)
		end
	end
end

function Game_Lobby:UpdateFavoriteButtonStates()
	-- I don't think this function will ever really be needed, the states shouldn't fall out of sync
	for hero, info in pairs(Game_Lobby.filterInfoList) do
		if (Game_Lobby.favoriteHeroes[hero]) then
			if ((not info.isEmpty) and info.favoriteButton) then
				info.favoriteButton:SetButtonState(0)
			end
		else
			if ((not info.isEmpty) and info.favoriteButton) then
				info.favoriteButton:SetButtonState(1)
			end
		end
	end
end

function Game_Lobby:SetFavoriteButtonVisibility(visible)
	-- this is because we don't want the button appearing on slots without heroes
	for hero, info in pairs(Game_Lobby.filterInfoList) do
		if ((not info.isEmpty) and info.favoriteButton) then
			info.favoriteButton:SetVisible(visible)
		end
	end
end

function Game_Lobby:RegisterHeroForFilter(widget, heroName, solo, jungle, carry, support, initiator, ganker, ranged, melee, pusher)
	-- empty hero names exist for blank slots
	if (Empty(heroName)) then
		local slot = "EmptyHeroSlot"..Game_Lobby.emptySlotCounter
		Game_Lobby.emptySlotCounter = Game_Lobby.emptySlotCounter + 1

		Game_Lobby.filterInfoList[slot] = {}
		Game_Lobby.filterInfoList[slot].filterCover = widget
		Game_Lobby.filterInfoList[slot].isEmpty = true
	else
		if (not Game_Lobby.filterInfoList[heroName]) then
			Game_Lobby.filterInfoList[heroName] = {}
		end

		Game_Lobby.filterInfoList[heroName].filterCover = widget
		Game_Lobby.filterInfoList[heroName].solo 		= tonumber(solo) or 0.0
		Game_Lobby.filterInfoList[heroName].jungle 		= tonumber(jungle) or 0.0
		Game_Lobby.filterInfoList[heroName].carry 		= tonumber(carry) or 0.0
		Game_Lobby.filterInfoList[heroName].support 	= tonumber(support) or 0.0
		Game_Lobby.filterInfoList[heroName].initiator 	= tonumber(initiator) or 0.0
		Game_Lobby.filterInfoList[heroName].ganker 		= tonumber(ganker) or 0.0
		Game_Lobby.filterInfoList[heroName].melee 		= tonumber(melee) or 0.0
		Game_Lobby.filterInfoList[heroName].ranged 		= tonumber(ranged) or 0.0
		Game_Lobby.filterInfoList[heroName].pusher 		= tonumber(pusher) or 0.0
		Game_Lobby.filterInfoList[heroName].isEmpty 		= false
	end
end

function Game_Lobby:RegisterFilterButton(widget, category)
	Game_Lobby.filterButtons[category] = widget
end

function Game_Lobby:UpdateFilteredHeroes()
	local stringSearch = NotEmpty(Game_Lobby.filterString)
	local searchString = ""	-- heh, sorry 'bout the names
	local filterActive = false

	for filter, active in pairs(Game_Lobby.activeFilters) do
		if (active) then
			filterActive = true
			break
		end
	end

	if (stringSearch) then
		searchString = string.lower(Game_Lobby.filterString)
	end

	if (Empty(searchString) and (not filterActive)) then -- no filters of any kind, just display everything
		for hero, info in pairs(Game_Lobby.filterInfoList) do
			info.filterCover:SetVisible(false)
		end
	else -- some kind of filter is active, filter the list
		for hero, info in pairs(Game_Lobby.filterInfoList) do
			local included = true

			if (info.isEmpty) then
				included = false
			else
				if (stringSearch) then
					if (not string.find(string.lower(Translate("mstore_"..hero.."_name")), searchString, 1, true)) then -- search against name
						if (Translate(hero.."_filter_keywords") ~= (hero.."_filter_keywords")) then -- check if we have keywords
							if (not string.find(string.lower(Translate(hero.."_filter_keywords")), searchString, 1, true)) then -- name failed, try keywords
								included = false
							end
						else
							included = false -- no keywords, search failed
						end
					end
				end

				-- wasn't pruned by string search
				if (included) then
					local anyFilter = false
					local hasFilters = false
					for filter, active in pairs(Game_Lobby.activeFilters) do
						if (active) then
							if (filter ~= "fav") then
								hasFilters = true
								if (info[filter] >= Game_Lobby.filterThreshold) then -- 0 is excluded, anything less than the threshold is excluded
									anyFilter = true
								end
							else
								if (not Game_Lobby.favoriteHeroes[hero]) then
									included = false
									break
								end
							end
						end
					end

					if (included and hasFilters and (not anyFilter)) then
						included = false
					end
				end
			end

			info.filterCover:SetVisible(not included)
		end
	end
end

function Game_Lobby:ToggleFilter(filter)
	local value = not Game_Lobby.activeFilters[filter]

	-- delete stuff if it's false (less stuff to cycle through)
	if (value == false) then
		Game_Lobby.activeFilters[filter] = nil
	else
		Game_Lobby.activeFilters[filter] = value
	end

	if (filter == "fav") then -- show the favorite buttons
		Game_Lobby:SetFavoriteButtonVisibility(value)
		Game_Lobby:SetFilterFavorites()
	else
		Game_Lobby:SetFilterFilters()
	end

	-- count the number of filters enabled
	local filters = 0
	for filter, value in pairs(Game_Lobby.activeFilters) do
		if ((filter ~= "fav") and (filter ~= "melee") and (filter ~= "ranged") and value) then
			filters = filters + 1
		end
	end

	Game_Lobby:UpdateFilteredHeroes()
end

function Game_Lobby:ToggleFilterRadio(filter, conflictingCategories)
	local value = not Game_Lobby.activeFilters[filter]

	local disabled = false
	if (value) then
		-- disable all conflics
		disableFilters = explode("|", conflictingCategories)

		for _, disFilter in pairs(disableFilters) do
			if (Game_Lobby.activeFilters[disFilter]) then
				disabled = true
				Game_Lobby.activeFilters[disFilter] = nil
			end
		end
	end

	-- delete stuff if it's false (less stuff to cycle through)
	if (value == false) then
		Game_Lobby.activeFilters[filter] = nil
	else
		Game_Lobby.activeFilters[filter] = value
	end

	if (filter == "fav") then -- show the favorite buttons
		Game_Lobby:SetFavoriteButtonVisibility(value)
		Game_Lobby:SetFilterFavorites()
	else
		Game_Lobby:SetFilterFilters()
	end

	-- count the number of filters enabled
	local filters = 0
	for filter, value in pairs(Game_Lobby.activeFilters) do
		if ((filter ~= "fav")  and (filter ~= "melee") and (filter ~= "ranged") and value) then
			filters = filters + 1
		end
	end

	if (disabled) then
		Game_Lobby:UpdateFilterButtonStates() -- if stuff was disabled
	end

	Game_Lobby:UpdateFilteredHeroes()
end

function Game_Lobby:FilterOnly(filter)
	Game_Lobby.activeFilters = {}
	Game_Lobby.activeFilters[filter] = true

	--Game_Lobby:ManuallyChangeFilterThreshold(3.0)

	if (filter == "fav") then -- favorite buttons
		Game_Lobby:SetFavoriteButtonVisibility(true)
		Game_Lobby:SetFilterFavorites()
	else
		Game_Lobby:SetFavoriteButtonVisibility(false)
		Game_Lobby:SetFilterFilters()
	end

	-- update button states
	Game_Lobby:UpdateFilterButtonStates()

	Game_Lobby:UpdateFilteredHeroes()
end

function Game_Lobby:UpdateFilterSearchString(w, string)
	if (string == Translate('filter_search_empty')) then
		string = ""
	end

	Game_Lobby.filterString = string
	Game_Lobby:UpdateFilteredHeroes()

	-- sleep so that we don't send an update every time they type a letter ~~
	w:Sleep(400, function()
		Game_Lobby:SetFilterFavorites() -- handles string searches too
	end)
end

function Game_Lobby:ResetFilters()
	Game_Lobby.activeFilters = {}
	GetWidget("picker_filter_textbox"):SetInputLine(Translate('filter_search_empty')) -- this calls to update the filtered heroes
	GetWidget("picker_filter_textbox2"):SetInputLine(Translate('filter_search_empty')) -- this calls to update the filtered heroes
	GetWidget("picker_filter_textbox3"):SetInputLine(Translate('filter_search_empty')) -- this calls to update the filtered heroes

	Game_Lobby:SetFilterFilters()
	Game_Lobby:SetFilterFavorites()

	-- reset all the buttons
	Game_Lobby:UpdateFilterButtonStates()
	-- hide favorite buttons
	Game_Lobby:SetFavoriteButtonVisibility(0)
end

function Game_Lobby:UpdateFilterButtonStates()
	if (Game_Lobby.filterButtons) then
		for category, widget in pairs(Game_Lobby.filterButtons) do
			if (Game_Lobby.activeFilters[category]) then
				widget:SetButtonState(1)
			else
				widget:SetButtonState(0)
			end
		end
	end
end

-- this use to be called on hero picker population, however that repopulates when a hero is picked
-- it's now called on gamephase <= 1 (from the main.lua file)
function Game_Lobby:ClearFilters()
	Game_Lobby:ResetFilters()

	-- clear favorite button onclick events, this is done since they otherwise they get cleared out (and not set again) when a hero is picked
	groupfcall("hero_picker_favorite_buttons", function(_, w, _) w:ClearCallback('onclick') w:RefreshCallbacks() end)

	Game_Lobby.filterInfoList = {}
	Game_Lobby.emptySlotCounter = 0
	Game_Lobby.playerPicks = {}

	Game_Lobby:ClearCompositionBars()

	-- reset the bar the gets as players pick
	Game_Lobby.nextPickBar = 1

	-- reset filter to value from server
	-- Game_Lobby.filterThreshold = GetCvarNumber("sv_heroSelectFilterThreshold")
	-- GetWidget("picker_filter_threshold"):SetValue(Game_Lobby.filterThreshold)
	Game_Lobby:SetFilterThreshold()

	-- load the favorites db
	Game_Lobby.favoriteHeroes = GetDBEntry("picker_favorite_heroes", nil, nil) or {}
end

function Game_Lobby:ToggleFavorite(heroName)
	local value = not Game_Lobby.favoriteHeroes[heroName]

	-- delete stuff if it's false (less stuff to cycle through)
	if (value == false) then
		Game_Lobby.favoriteHeroes[heroName] = nil
	else
		Game_Lobby.favoriteHeroes[heroName] = value
	end

	-- save the db
	GetDBEntry("picker_favorite_heroes", Game_Lobby.favoriteHeroes, true)

	Game_Lobby:UpdateFilteredHeroes()
	Game_Lobby:SetFilterFavorites()
end

-- stuff for the composition bars
local function HeroSelectPlayerInfoHandler(index, _, ...)
	if (not Game_Lobby.playerPicks[index]) then
		Game_Lobby.playerPicks[index] = {}
		if (AtoB(arg[27]) and AtoB(arg[12])) then 	-- new teammate and they have a hero picked already, give them a slot
			Game_Lobby.playerPicks[index].bar = Game_Lobby.nextPickBar
			Game_Lobby.nextPickBar = Game_Lobby.nextPickBar + 1
		end
	elseif ((not Game_Lobby.playerPicks[index].heroPicked) and Game_Lobby.playerPicks[index].teamMate and AtoB(arg[27])) then -- team mate picked a hero, give them a slot
		Game_Lobby.playerPicks[index].bar = Game_Lobby.nextPickBar
		Game_Lobby.nextPickBar = Game_Lobby.nextPickBar + 1
	elseif (Game_Lobby.playerPicks[index].heroPicked and Game_Lobby.playerPicks[index].teamMate and (not AtoB(arg[27]))) then -- team mate repicked, remove their slot and pick others back
		local removedBar = Game_Lobby.playerPicks[index].bar
		Game_Lobby.playerPicks[index].bar = nil
		Game_Lobby.nextPickBar = Game_Lobby.nextPickBar - 1

		-- push all existing bars back beyond the removed one back
		for i=0,9 do
			if (Game_Lobby.playerPicks[i].heroPicked and Game_Lobby.playerPicks[i].bar and (Game_Lobby.playerPicks[i].bar > removedBar)) then
				Game_Lobby.playerPicks[i].bar = Game_Lobby.playerPicks[i].bar - 1
			end
		end
	end

	Game_Lobby.playerPicks[index].isMe 			= AtoB(arg[2])
	Game_Lobby.playerPicks[index].teamMate 		= AtoB(arg[12])
	Game_Lobby.playerPicks[index].color 		= arg[5]
	Game_Lobby.playerPicks[index].isGhostPick 	= AtoB(arg[26])
	Game_Lobby.playerPicks[index].heroPicked 	= AtoB(arg[27])
	Game_Lobby.playerPicks[index].solo 			= tonumber(arg[32])
	Game_Lobby.playerPicks[index].jungle		= tonumber(arg[33])
	Game_Lobby.playerPicks[index].carry			= tonumber(arg[34])
	Game_Lobby.playerPicks[index].support		= tonumber(arg[35])
	Game_Lobby.playerPicks[index].initiator		= tonumber(arg[36])
	Game_Lobby.playerPicks[index].ganker		= tonumber(arg[37])
	Game_Lobby.playerPicks[index].ranged		= tonumber(arg[38])
	Game_Lobby.playerPicks[index].melee			= tonumber(arg[39])
	Game_Lobby.playerPicks[index].pusher		= tonumber(arg[40])

	-- update if the update is from a team-mate
	if (AtoB(arg[12])) then
		Game_Lobby:UpdateTeamComposition()
	end
end
for i=0,9 do
	interface:RegisterWatch("HeroSelectPlayerInfo"..i, function(...) HeroSelectPlayerInfoHandler(i, ...) end)
end

function Game_Lobby:ClearCompositionBars()
	-- normal bars
	for i=1,5 do
		for category, max in pairs(FILTER_CATEGORY_MAX) do
			GetWidget("pick_filter_"..category.."_bar"..i):SetWidth(0)
		end
	end

	-- ghost bar
	for category, max in pairs(FILTER_CATEGORY_MAX) do
		GetWidget("pick_filter_"..category.."_barGhost"):SetWidth(0)
	end

	-- total bar
	for category, max in pairs(FILTER_CATEGORY_MAX) do
		GetWidget("pick_filter_"..category.."_barTotal"):SetWidth(0)
	end
end

function Game_Lobby:UpdateTeamComposition()
	if GetCvarBool('ui_filterMultiBarComposition') then
		------------ multi bar population -------------
		local usedBars = {}

		for i=0, 9 do
			if (Game_Lobby.playerPicks[i] and Game_Lobby.playerPicks[i].teamMate) then
				local info = Game_Lobby.playerPicks[i]

				if (info.isMe and info.isGhostPick) then -- my ghost pick
					for category, max in pairs(FILTER_CATEGORY_MAX) do
						GetWidget("pick_filter_"..category.."_barGhost"):SetWidth(FtoP(info[category] / max))
					end
				elseif (info.isMe and info.heroPicked) then -- my hero pick (need to clear out the ghost bar)
					for category, max in pairs(FILTER_CATEGORY_MAX) do
						GetWidget("pick_filter_"..category.."_bar"..info.bar):SetColor(info.color)
						GetWidget("pick_filter_"..category.."_bar"..info.bar):SetWidth(FtoP(info[category] / max))

						GetWidget("pick_filter_"..category.."_barGhost"):SetWidth(0)

						usedBars[info.bar] = true
					end
				elseif (info.heroPicked) then 			 -- anybodies hero pick
					for category, max in pairs(FILTER_CATEGORY_MAX) do
						GetWidget("pick_filter_"..category.."_bar"..info.bar):SetColor(info.color)
						GetWidget("pick_filter_"..category.."_bar"..info.bar):SetWidth(FtoP(info[category] / max))

						usedBars[info.bar] = true
					end
				end
			end
		end

		-- clear out any unused bars (could be an issue from repicking / shuffling)
		for i=1,5 do
			if (not usedBars[i]) then
				for category, max in pairs(FILTER_CATEGORY_MAX) do
					GetWidget("pick_filter_"..category.."_bar"..i):SetWidth(0)
				end
			end
		end
		-------------------------------------------
	else
		----- single bar population (+ ghost) -----
		local ghosts, totals = {}, {}

		for i=0, 9 do
			if (Game_Lobby.playerPicks[i] and Game_Lobby.playerPicks[i].teamMate) then
				local info = Game_Lobby.playerPicks[i]

				if (info.isMe and info.isGhostPick) then
					for category, max in pairs(FILTER_CATEGORY_MAX) do
						ghosts[category] = (ghosts[category] or 0) + info[category]
					end
				elseif (info.heroPicked) then
					for category, max in pairs(FILTER_CATEGORY_MAX) do
						totals[category] = (totals[category] or 0) + info[category]
					end
				end
			end
		end

		for category, max in pairs(FILTER_CATEGORY_MAX) do
			GetWidget("pick_filter_"..category.."_barTotal"):SetWidth(FtoP((totals[category] or 0) / max))
			GetWidget("pick_filter_"..category.."_barGhost"):SetWidth(FtoP((ghosts[category] or 0) / max))
		end
		-------------------------------------------
	end
end

function Game_Lobby:FilterTooltip(title, body)
	local visible = false

	if (NotEmpty(title)) then
		GetWidget("picker_filters_tooltip_title"):SetText(Translate(title))
		GetWidget("picker_filters_tooltip_title"):SetVisible(1)
		visible = true
	else
		GetWidget("picker_filters_tooltip_title"):SetVisible(0)
	end

	if (NotEmpty(body)) then
		GetWidget("picker_filters_tooltip_body"):SetText(Translate(body))
		GetWidget("picker_filters_tooltip_body"):SetVisible(1)
		visible = true
	else
		GetWidget("picker_filters_tooltip_body"):SetVisible(0)
	end

	GetWidget("picker_filters_tooltip"):SetVisible(visible)
end

function Game_Lobby:ChangeFilterThreshold(value)
	value = tonumber(value)
	Game_Lobby.filterThreshold = value

	Game_Lobby:UpdateFilteredHeroes()
	--Game_Lobby:SetFilterThreshold() -- don't do this, it's done on drag end from the slider
end

function Game_Lobby:ManuallyChangeFilterThreshold(value)
	Game_Lobby.filterThreshold = value
	--Game_Lobby:UpdateFilteredHeroes() -- this is done in all the places after it's called
	Game_Lobby:SetFilterThreshold()
end

function Game_Lobby:SetFilterFilters()
	local filterString = ""

	for filter, active in pairs(Game_Lobby.activeFilters) do
		if (active and (filter ~= 'fav')) then
			if (NotEmpty(filterString)) then
				filterString = filterString .. "|"
			end
			filterString = filterString .. 'filter_' .. filter
		end
	end

	--Echo("SetHeroSelectFilters '"..filterString.."'")
	SetHeroSelectFilters(filterString)
end

function Game_Lobby:SetFilterFavorites()
	-- do the string search here too :(
	local stringSearch = NotEmpty(Game_Lobby.filterString)
	local searchFavorite = Game_Lobby.activeFilters['fav']
	local searchString = ""	-- heh, sorry 'bout the names

	if (stringSearch) then
		searchString = string.lower(Game_Lobby.filterString)
	end

	local favoritesString = ""


	if (searchFavorite or stringSearch) then
		for hero, info in pairs(Game_Lobby.filterInfoList) do
			local included = true

			if (searchFavorite and (not Game_Lobby.favoriteHeroes[hero])) then
				included = false
			end
			if (included and stringSearch) then
				if (not string.find(string.lower(Translate("mstore_"..hero.."_name")), searchString, 1, true)) then -- search against name
					if (Translate(hero.."_filter_keywords") ~= (hero.."_filter_keywords")) then -- check if we have keywords
						if (not string.find(string.lower(Translate(hero.."_filter_keywords")), searchString, 1, true)) then -- name failed, try keywords
							included = false
						end
					else
						included = false -- no keywords, search failed
					end
				end
			end

			if (included) then
				if (NotEmpty(favoritesString)) then
					favoritesString = favoritesString .. "|"
				end
				favoritesString = favoritesString .. hero
			end
		end
	end

	--Echo("SetHeroSelectFavoriteHeroes '"..favoritesString.."'")
	SetHeroSelectFavoriteHeroes(favoritesString, Game_Lobby.activeFilters['fav'] or false) -- send false if nil
end

function Game_Lobby:SetFilterThreshold()
	--Echo("SetHeroSelectThreshold '"..Game_Lobby.filterThreshold.."'")
	SetHeroSelectThreshold(Game_Lobby.filterThreshold)
end

----------- END AP filter stuff --------------

function Game_Lobby:AddCardsListItems(heroName, avatarName)

	Set('_globby_buyavatar_discount', '')
	Game_Lobby.GCardsTable = {}
	Game_Lobby.CardLastSelect = -1

	local listbox =	GetWidget('easy_CardListbox_lobby')
	local cardsTable = GetCardsInfo(heroName, avatarName)

	for index, cardTable in pairs(cardsTable) do
		Game_Lobby.GCardsTable[index - 1] = cardTable

		local cardName = nil
		if (cardTable.Coupon_id == "ext") then
			cardName = Translate('mstore_trial_name')
		else
			cardName = Translate('mstore_product'..tostring(cardTable.Product_id)..'_name')
		end

		listbox:AddTemplateListItem('Card_ListItem', '',
									 'name', cardName,
									 'discount', tostring(cardTable.Discount).."% off",
									 'textcolor', '#ffffff',
									 'framecolor0', '#111111',
									 'framecolor1', '#111111',
									 'framecolor2', '#111111')
	end

	local label = GetWidget('easy_CardDesc_lobby')
	local cardlistPanel = GetWidget('CardListPannel_lobby')
	if (#cardsTable > 0) then
		label:SetText(Translate('mstore_nocards_desc'))
		label:SetColor("red")
		cardlistPanel:SetVisible(true)
	else
		cardlistPanel:SetVisible(false)
	end
end

function Game_Lobby:OnCardListSelect(index)

	local label = GetWidget('easy_CardDesc_lobby')

	if (index ~= Game_Lobby.CardLastSelect) then
		Game_Lobby.CardLastSelect = index

		if (Game_Lobby.GCardsTable and Game_Lobby.GCardsTable[index]) then
			local descStr = Translate("mstore_cards_desc").." "..Game_Lobby.GCardsTable[index].EndTime

			label:SetVisible(true)
			label:SetText(descStr)
			label:SetColor("#ffffff")

			Set('_globby_buyavatar_discount', Game_Lobby.GCardsTable[index].Coupon_id)

			local goldPrice = GetCvarInt('_globby_buyavatar_cost', true)
			local silverPrice = GetCvarInt('_globby_buyavatar_SilverCost', true)
			local goldOwn = GetCvarInt('_gLobbyLastTotalCoins', true)
			local silverOwn = GetCvarInt('_gLobbyLastTotalSilverCoins', true)
			goldPrice = math.floor(goldPrice * (100 - Game_Lobby.GCardsTable[index].Discount) * 0.01)
			silverPrice = math.floor(silverPrice * (100 - Game_Lobby.GCardsTable[index].Discount) * 0.01)
			GetWidget('globby_buyavatar_confPrem_goldcost'):SetText(FtoA(goldPrice, 0, 0, ","))
			GetWidget('globby_buyavatar_confPrem_silvercost'):SetText(FtoA(silverPrice, 0, 0, ","))

			if (goldPrice <= goldOwn) then
				GetWidget('globby_buyavatar_confPrem_goldbtn'):SetVisible(true)
			end
			if (silverPrice <= silverOwn) then
				GetWidget('globby_buyavatar_confPrem_silverbtn'):SetVisible(true)
			end
		else
			label:SetVisible(false)
			Set('_globby_buyavatar_discount', '')
		end
	else
		local listbox =	GetWidget('easy_CardListbox_lobby')
		listbox:SetSelectedItemByIndex(-1)
		Game_Lobby.CardLastSelect = -1
		local goldPrice = GetCvarInt('_globby_buyavatar_cost', true)
		local silverPrice = GetCvarInt('_globby_buyavatar_SilverCost', true)
		local goldOwn = GetCvarInt('_gLobbyLastTotalCoins', true)
		local silverOwn = GetCvarInt('_gLobbyLastTotalSilverCoins', true)
		GetWidget('globby_buyavatar_confPrem_goldcost'):SetText(FtoA(goldPrice, 0, 0, ","))
		GetWidget('globby_buyavatar_confPrem_silvercost'):SetText(FtoA(silverPrice, 0, 0, ","))
		Set('_globby_buyavatar_discount', '')
		label:SetText(Translate('mstore_nocards_desc'))
		label:SetColor("red")
		if (goldPrice > goldOwn) then
			GetWidget('globby_buyavatar_confPrem_goldbtn'):SetVisible(false)
		end
		if (silverPrice > silverOwn) then
			GetWidget('globby_buyavatar_confPrem_silverbtn'):SetVisible(false)
		end
	end
end

function interface:HoNGameLobbyF(func, ...)
	print(Game_Lobby[func](self, ...))
end

object:RegisterWatch('HeroSelected', function(widget, entityName)
	if (not Game_Lobby.ignoreHeroSelectedDefaultAvatar) then
		local defaultAvatar = GetDBEntry('def_av_'..entityName, 'Base', false, false, false)
		SelectAvatar('' .. defaultAvatar ..'')
	end
	Game_Lobby.ignoreHeroSelectedDefaultAvatar = false

	if GetMap() == 'devowars' then
		Game_Lobby.ClickedViewAvatars(GetCvarString('cg_avatarHero'), nil, nil)
	end
end)

GetWidget('event_background_scene'):RegisterWatch('GamePhase', function(widget, gamePhase)
	if AtoN(gamePhase) == 0 then
		Game_Lobby.ignoreHeroSelectedDefaultAvatar = false
	end
end)

testCampainLevel = 0
function Game_Lobby:SetupCampainLevel(self, index, clientNum, sameTeam, levelStr)
	local visible = false

	-- NAEU (show enemy rank)
	if not GetCvarBool('cl_GarenaEnable') then
		visible = ((clientNum and tonumber(clientNum) >= 0) or ViewingReplay()) and IsCampaignMatch()
	-- SEA (hide enemy rank)
	else
		visible = clientNum and tonumber(clientNum) >= 0 and (AtoB(sameTeam) or ViewingReplay()) and IsCampaignMatch()
	end
	
	-- Test check for client-side purposes
	-- local TEST = testCampainLevel and testCampainLevel > 0
	-- if TEST then
		-- visible = clientNum and tonumber(clientNum) >= 0 and AtoB(sameTeam)
	-- end

	if visible then
		local level = tonumber(levelStr)

		if TEST then
			level = testCampainLevel
		end

		local text = ''
		if level > 0 then
			text = Translate('player_compaign_level_name_S7_'..level)
		end
		self:GetWidget('HeroSelectPlayerRankLabel'..index):SetText(text)

		local colorType = ''

		if level > 20 or level < 1 then
			colorType = ''
		elseif level == 20 then
			colorType = 'master'
		elseif level >= 18 then
			colorType = 'platinum'
		elseif level >= 15 then
			colorType = 'diamond'
		elseif level > 10 then
			colorType = 'gold'
		elseif level > 5 then
			colorType = 'silver'
		elseif level >= 1 then
			colorType = 'bronze'
		end

		local image = self:GetWidget('HeroSelectPlayerRankImage'..index)
		local bgImage = self:GetWidget('HeroSelectPlayerRankBgImage'..index)
		local showImage = false
		if colorType ~= '' then
			image:SetTexture('/ui/fe2/season/icon_mini/'..GetRankIconNameRankLevelAfterS6(level))
			bgImage:SetTexture('/ui/fe2/season/'..colorType..'_bar.tga')
			showImage = true
		end
		image:SetVisible(showImage)
		bgImage:SetVisible(showImage)
	end
	
	self:SetVisible(visible)
end
