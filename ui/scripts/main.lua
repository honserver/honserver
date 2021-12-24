----------------------------------------------------------
--	Name: 		Main Interface Script	       			--
--  Copyright 2015 Frostburn Studios					--
----------------------------------------------------------

local _G = getfenv(0)
Main = _G['Main'] or {}
local HoN_Main = _G['HoN_Main'] or {}
local ipairs, pairs, select, string, table, next, type, unpack, tinsert, tconcat, tremove, format, tostring, tonumber, tsort, ceil, floor, sub, find, gfind = _G.ipairs, _G.pairs, _G.select, _G.string, _G.table, _G.next, _G.type, _G.unpack, _G.table.insert, _G.table.concat, _G.table.remove, _G.string.format, _G.tostring, _G.tonumber, _G.table.sort, _G.math.ceil, _G.math.floor, _G.string.sub, _G.string.find, _G.string.gfind
local interface, interfaceName = object, object:GetName()
RegisterScript('Main', '33')
HoN_Main.loadingVisible = false
HoN_Main.gamePhase = 0
HoN_Main.menuPanels = {}
HoN_Main.menuPanels.table = {}
HoN_Main.menuPanels.currentPanel = ''
HoN_Main.menuPanels.panelQueue = ''
HoN_Main.walkthroughs = {}
HoN_Main.walkthroughs.targetOnClick = nil
HoN_Main.walkthroughs.targetOnSelect = nil
HoN_Main.walkthroughs.targetWidget = nil
HoN_Main.walkthroughs.current = ''
HoN_Main.walkthroughs.step = 0
Main.walkthroughState = GetDBEntry('walkthroughState', nil, true, false, true) or 0
Main.walkthroughPrompted = GetDBEntry('walkthroughPrompted', nil, true, false, true) or 0
HoN_Main.uiLoginState = false
HoN_Main.uiPrecacheWorld = GetCvarBool('ui_preloadTheWorld')
Cvar.CreateCvar('_game_phase', 'int', 0)

HoN_Main.selectedTab = ''

local function GetWidget(widget, fromInterface, hideErrors)
	--println('GetWidget Main: ' .. tostring(widget) .. ' in interface ' .. tostring(fromInterface))
	if (widget) then
		local returnWidget
		if (fromInterface) then
			local theInterface = UIManager.GetInterface(fromInterface)
			
			if theInterface == nil then
				if (not hideErrors) then println('^rGetWidget Main Failed: Could not find the interface: ' .. tostring(fromInterface)) end
				return nil
			end

			returnWidget = theInterface:GetWidget(widget)
		else
			returnWidget = interface:GetWidget(widget)
		end
		if (returnWidget) then
			return returnWidget
		else
			if (not hideErrors) then println('GetWidget Main failed to find ' .. tostring(widget) .. ' in interface ' .. tostring(fromInterface)) end
			return nil
		end
	else
		println('GetWidget called without a target')
		return nil
	end
end
GetWidget = memoizeObject(GetWidget)

local lobbyMusicMapLast		= nil
local lobbyMusicLastPhase	= 0

-- ======= Regular music =======
local menuMusic = '/music/menu.mp3'
-- local lobbyMusic	= {
-- 	caldavar		= { '/music/lobby.mp3' },
-- 	-- darkwoodvale	= {	'/music/lobby.mp3' },
-- 	midwars			= {	'/music/lobby.mp3' },
-- 	-- riftwars		= {	'/music/lobby.mp3' },
-- 	-- watchtower	= {	'/music/lobby.mp3' },
-- 	prophets		= {	'/music/lobby.mp3' },
-- 	grimmscrossing	= { '/music/lobby.mp3' },
-- 	devowars	= { '/music/devo_wars/lobby.mp3' },
-- }

-- ======= Halloween music =======
-- local menuMusic = '/music/halloween/menu.mp3'
-- local lobbyMusic	= {
	-- caldavar		= { '/music/halloween/lobby.mp3' },
	-- -- darkwoodvale	= {	'/music/halloween/lobby.mp3' },
	-- midwars			= {	'/music/halloween/lobby.mp3' },
	-- -- riftwars		= {	'/music/halloween/lobby.mp3' },
	-- -- watchtower	= {	'/music/halloween/lobby.mp3' },
	-- prophets		= {	'/music/halloween/lobby.mp3' },
	-- grimmscrossing	= { '/music/halloween/lobby.mp3' },
	-- devowars	= { '/music/halloween/lobby.mp3' },
-- }

-- ======= Christmas music =======
local menuMusic = '/music/yule/menu.mp3'
local lobbyMusic	= {
	caldavar		= { '/music/yule/lobby.mp3' },
	-- darkwoodvale	= {	'/music/lobby.mp3' },
	midwars			= {	'/music/yule/lobby.mp3' },
	-- riftwars		= {	'/music/lobby.mp3' },
	-- watchtower	= {	'/music/lobby.mp3' },
	prophets		= {	'/music/yule/lobby.mp3' },
	grimmscrossing	= { '/music/yule/lobby.mp3' },
	devowars	= { '/music/yule/lobby.mp3' },
}

local rap2Enable = GetCvarBool('cl_Rap2Enable')

function playLobbyMusic(map)
	map = map or lobbyMusicMapLast or 'caldavar'
	local lobbyMusicSet = lobbyMusic[map] or lobbyMusic['caldavar'] or { '/music/lobby.mp3' }

	PlayMusic(lobbyMusicSet[math.random(1, #lobbyMusicSet)], true)
end

GetWidget('musicController'):RegisterWatch('EventPlayLobbyMusic', function(widget, map)
	map = map or lobbyMusicMapLast or 'caldavar'
	local lobbyMusicSet = lobbyMusic[map] or lobbyMusic['caldavar'] or { '/music/lobby.mp3' }

	PlayMusicOverride(lobbyMusicSet[math.random(1, #lobbyMusicSet)], true)
end)

GetWidget('musicController'):RegisterWatch('LobbyGameInfo', function(widget, p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, map)
	local gamePhase = AtoN(widget:UICmd("GetCurrentGamePhase()"))
	if (gamePhase == 1 or gamePhase == 3) and lobbyMusicMapLast ~= map then
		lobbyMusicMapLast = map
		playLobbyMusic()
	else
		lobbyMusicMapLast = map
	end
end)

function playBgMusic()
	local gamePhase = AtoN(interface:UICmd("GetCurrentGamePhase()"))
	if gamePhase == 0 then
		PlayMusic(menuMusic, true)
	elseif (gamePhase == 1 or gamePhase == 3) then
		playLobbyMusic()
	else
		--StopMusic()
	end
end

GetWidget('musicController'):RegisterWatch('GamePhase', function(widget, phase)
	local gamePhase = AtoN(phase)
	if gamePhase == 0 then
		PlayMusic(menuMusic, true)
	end
end)

local function ShowWidget(widgetName, fromInterface)
	if (fromInterface) then
		local widget = UIManager.GetInterface(fromInterface):GetWidget(widgetName)
		if (widget) then
			widget:SetVisible(true)
		else
			println('ShowWidget could not find: ' .. tostring(widgetName))
		end
	else
		local widget = GetWidget(widgetName)
		if (widget) then
			widget:SetVisible(true)
		else
			println('ShowWidget could not find: ' .. tostring(widgetName))
		end
	end
end

local function HideWidget(widgetName, fromInterface)
	if (fromInterface) then
		local widget = UIManager.GetInterface(fromInterface):GetWidget(widgetName)
		if (widget) then
			widget:SetVisible(false)
		else
			println('HideWidget could not find: ' .. tostring(widgetName))
		end
	else
		local widget = GetWidget(widgetName)
		if (widget) then
			widget:SetVisible(false)
		else
			println('HideWidget could not find: ' .. tostring(widgetName))
		end
	end
end

local function SlideInPanel(widget)
	widget:SetVisible(true)
	if GetCvarBool('cg_menuTransitions') then
		widget:Sleep(200, function() widget:SlideY('0', 300) end)
	else
		widget:SetY('0')
	end
end

local function SlideOutPanel(widget, yPos)
	yPos = yPos or '-110%'
	if GetCvarBool('cg_menuTransitions') then
		Cmd("Unbind game ESC")
		widget:SlideY(yPos, 200)
		widget:Sleep(200, function() widget:SetVisible(false) Cmd("BindButton game ESC Cancel") end)
	else
		widget:SetY(yPos)
		widget:SetVisible(false)
	end
end

local function SlideOutPanelTall(widget)
	SlideOutPanel(widget, '-210%')
end


--[[
	Main.walkthroughState
	0 - Initial
	1 - Has starting ingame walkthrough
	2 - Has completed ingame walkthrough
	3 - Has been shown end game rewards
	4 - Has entered store
	5 - Has left store
	6 - Has been shown herodex / play now
--]]
function CheckForWalkthrough()

	printdb('^c CheckForWalkthrough')

	if (IsInGame()) or (IsInQueue()) then
		return
	end

	printdb('Main.walkthroughState = ' .. tostring(Main.walkthroughState) )

	if (Main.walkthroughState == 0) then
		printdb('GetExperience() = ' .. tostring(GetExperience()) )
		if (GetExperience() == 0) or (GetCvarBool('ui_main_walkthroughTest')) then
			if (HoN_Main.menuPanels.currentPanel == 'matchmaking') then
				Main.walkthroughState = 1
			end
		end
	elseif (Main.walkthroughState == 1) then
		-- nada
	elseif (Main.walkthroughState == 2) then
		UIManager.GetInterface('main'):HoNGMainF('UserAction',26, true)
		printdb('GetExperience() = ' .. tostring(GetExperience()) )
		if ((GetExperience() == 0) or (GetCvarBool('ui_main_walkthroughTest'))) then
			-- Show walkthough for end game stuffs
			Match_Stats.Tutorial()
		else
			Main.walkthroughState = 6
		end
	elseif (Main.walkthroughState == 3) then
		if GetCvarBool('ui_allow_store_tutorial') then
			Set('ui_isInWalkthrough', 1)
			Main.walkthroughState = 4
			local store = GetCvarBool('cg_store2_') and 'store_container2' or 'store_container'
			if (not GetWidget(store):IsVisible()) then
				Set("microStore_avatarSelectTarget", '15')
				Set("microStore_targetCategory", '1')
				Trigger('DoWalkthrough', 'tutorial1', '1')
			end
		else
			Main.walkthroughState = 5
		end
	elseif (Main.walkthroughState == 4) then

	elseif (Main.walkthroughState == 5) then
		Main.walkthroughState = 6
		Trigger('DoWalkthrough', 'tutorial2', '1')
	elseif (Main.walkthroughState == 6) then
		Set('ui_isInWalkthrough', false)
	end
	GetDBEntry('walkthroughState', Main.walkthroughState, true, false, false)
end

local function ShowNews()
	GetWidget('news', 'main'):FadeIn(200)
end

local function HideNews()
	GetWidget('news', 'main'):FadeOut(175)
end

local function ShowPlinko()
	GetWidget('plinko', 'main'):DoEventN(1)
end

local function HidePlinko()
	GetWidget('plinko', 'main'):DoEventN(0)
end

local function HideWeb()
	GetWidget('web_browser_panel', 'main'):FadeOut(50)
	UIManager.GetInterface('webpanel'):HoNWebPanelF('WebPanelClose')
end

local function ShowWeb()
	GetWidget('web_browser_panel', 'main'):FadeIn(50)
end

local function HideScheduledMatches()
	GetWidget('hontour', 'main'):FadeOut(50)
end

local function ShowScheduledMatches()
	GetWidget('hontour', 'main'):FadeIn(50)
end

local function HideStore()
	GetWidget('store_container'):DoEventN(1)
end

local function ShowStore()
	GetWidget('store_container'):DoEventN(0)
	-- sleep the news to interrupt it's opening if it's waiting to do that
	GetWidget("news"):Sleep(1, function() self:FadeOut(1) end)
	UIManager.GetInterface('main'):HoNGMainF('UserAction', 1, true)
end

local function HideStore2()
	GetWidget('store_container2'):DoEventN(1)
end

local function ShowStore2()
	GetWidget('store_container2'):DoEventN(0)
	GetWidget("news"):Sleep(1, function() self:FadeOut(1) end)
	UIManager.GetInterface('main'):HoNGMainF('UserAction', 1, true)
end

local function FadeInSplash(splashPanel)
	GetWidget(splashPanel, 'main'):FadeIn(500)
end

local function FadeOutSplash(splashPanel)
	GetWidget(splashPanel, 'main'):FadeOut(250)
end

--[[
local function HidePlayerStats()
	if GetWidget('player_stats'):IsVisible() then
		if (GetWidget('player_stats_mystats_parent'):IsVisible() and (GetCvarInt('player_stats_current_panel') == 0)) or (GetWidget('player_stats_ladder_parent'):IsVisible() and (GetCvarInt('player_stats_current_panel') == 1)) then
			SlideOutPanel(GetWidget('player_stats'))
		end
	end
end
--]]

--[[ These are the main interface elements that show in the top section of the main interface
		show 			- how to show this panel
		hide 			- how to hide this panel
		[interface]		- interface this panel is in if not main
		[context]		- resource context to load/unload with this panel
		[showcmd]		- script to execute after panel shown
		[hidecmd]		- script to execute after panel hidden
		[effectid]		- effect to play
		[finishpanel]	- Call this panel when toggled to shown
		[finishcmd]		- Execute this script on finishpanel
		[hidefunction]	- Execute this function on hide
--]]
local function GetMainMenuPanels()
	HoN_Main.menuPanels.table['news'] 						= { ['show'] = ShowNews, 	 ['hide'] = HideNews,   ['context'] = 'news', ['showcmd'] = "Set(news_auto_displayed, 0); If((GetTime() - _lastNewsRefresh) ge 600, Trigger('RequestMessageOfTheDay'));" }
	HoN_Main.menuPanels.table['store_container2'] 			= { ['show'] = ShowStore2, 	 ['hide'] = HideStore2, ['context'] = 'store', ['hidefunction'] = CheckForWalkthrough }
	HoN_Main.menuPanels.table['store_container'] 			= { ['show'] = ShowStore, 	 ['hide'] = HideStore, 	['context'] = 'store', ['hidefunction'] = CheckForWalkthrough }
	HoN_Main.menuPanels.table['web_browser_panel'] 			= { ['show'] = ShowWeb, 	 ['hide'] = HideWeb }
	HoN_Main.menuPanels.table['player_stats'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '1', ['context'] = 'playerstats' }

	HoN_Main.menuPanels.table['player_tour'] 				= { ['show'] = function() FadeInSplash('player_tour') end, ['hide'] = function() FadeOutSplash('player_tour') end}
	HoN_Main.menuPanels.table['player_tour_stats']			= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanelTall, ['effectid'] = '1', ['showcmd'] = "Call('com_hider2', 'FadeIn(200)');", ['hidefunction'] = function() interface:GetWidget('com_hider2'):FadeOut(200) end }
	HoN_Main.menuPanels.table['player_motd'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanelTall, ['effectid'] = '1', ['showcmd'] = "Call('com_hider2', 'FadeIn(200)');", ['hidefunction'] = function() interface:GetWidget('com_hider2'):FadeOut(200) end }

	HoN_Main.menuPanels.table['watch_system'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanelTall, ['effectid'] = '15', ['showcmd'] = "Call('com_hider2', 'FadeIn(200)');", ['hidefunction'] = function() interface:GetWidget('com_hider2'):FadeOut(200) end }

	HoN_Main.menuPanels.table['player_ladder'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanelTall, ['effectid'] = '1', ['showcmd'] = "Call('com_hider2', 'FadeIn(200)');", ['hidefunction'] = function() interface:GetWidget('com_hider2'):FadeOut(200) end }
	HoN_Main.menuPanels.table['game_options'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '9', ['finishpanel'] = "options_referral_browser", ['finishcmd'] = "DoEvent();" }
	HoN_Main.menuPanels.table['change_log'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '11' }
	HoN_Main.menuPanels.table['offline_replays'] 			= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '10' }
	HoN_Main.menuPanels.table['game_list'] 					= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '3', ['showfunction'] = CheckForWalkthrough, ['finishpanel'] = 'GameListHandler', ['finishcmd'] = 'If(GetGameListCount() == 0, DoEvent())', ['hidecmd'] = "CancelServerList();" }
	HoN_Main.menuPanels.table['compendium'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['context'] = 'compendium', ['effectid'] = '1' }
	HoN_Main.menuPanels.table['matchmaking'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '2', ['showfunction'] = CheckForWalkthrough, ['context'] = 'matchmaking', ['showcmd'] = "RequestTMMPopularityUpdate(); If( !IsInGroup(), Trigger('TMMReset') )" }
	HoN_Main.menuPanels.table['match_stats'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '7', ['showfunction'] = CheckForWalkthrough, ['context'] = 'endstats', ['hidecmd'] = "Set('ui_match_stats_waitingToShow', false); ClearWaitingToShowStats(); GroupCall('matchInfoPlayerRowHighlights', 'SetVisible(false);'); Call('matchstats_new_rewardsscreen', 'SetVisible(false);');" }
	--HoN_Main.menuPanels.table['create_game'] 				= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '4' }
	HoN_Main.menuPanels.table['tutorial'] 					= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel }
	HoN_Main.menuPanels.table['retrieve_password'] 			= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '15' }
	HoN_Main.menuPanels.table['form_create_paid_account'] 	= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '14' }
	HoN_Main.menuPanels.table['form_create_subaccount'] 	= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '14' }
	HoN_Main.menuPanels.table['form_name_change'] 			= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '14' }
	--HoN_Main.menuPanels.table['ladder'] 					= { ['show'] = ShowLadder,   ['hide'] = HideLadder,    ['effectid'] = '14', ['context'] = 'ladder' }
	HoN_Main.menuPanels.table['plinko']						= { ['show'] = ShowPlinko,	 ['hide'] = HidePlinko, 	['context'] = 'plinko'}

	-- Temporary Panels
	HoN_Main.menuPanels.table['main_splash_maliken'] 	= { ['show'] = function() FadeInSplash('main_splash_maliken') end, ['hide'] = function() FadeOutSplash('main_splash_maliken') end, ['context'] = 'splash3' }

	HoN_Main.menuPanels.table['main_splash_new_player'] 			= { ['show'] = function() FadeInSplash('main_splash_new_player') end, ['hide'] = function() if GetWidget('main_splash_new_player'):IsVisible() then Set('ui_showStoreWalkthrough', 'true', 'bool') interface:UICmd([[SetSave('ui_showStoreWalkthrough')]]) end FadeOutSplash('main_splash_new_player') end, ['context'] = 'splash1' }

	HoN_Main.menuPanels.table['main_splash_referral_popup_1'] 			= { ['show'] = function() FadeInSplash('main_splash_referral_popup_1') end, ['hide'] = function() FadeOutSplash('main_splash_referral_popup_1') end, ['context'] = 'referral_popup_1' }
	HoN_Main.menuPanels.table['main_splash_referral_popup_2'] 			= { ['show'] = function() FadeInSplash('main_splash_referral_popup_2') end, ['hide'] = function() FadeOutSplash('main_splash_referral_popup_2') end, ['context'] = 'referral_popup_2' }

	HoN_Main.menuPanels.table['hontour'] 				= { ['show'] = ShowScheduledMatches, ['hide'] = HideScheduledMatches, ['context'] = 'hontour' }

	HoN_Main.menuPanels.table['rap_status']					= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel,  ['effectid'] = '11'}

	--[[ Disabled Panels
		HoN_Main.menuPanels.table['referral'] 					= { ['show'] = SlideInPanel, ['hide'] = SlideOutPanel, ['effectid'] = '14' }
	--]]

	GetMainMenuPanels = function() end
end

-- Allow external scripts to register a main panel
function HoN_Main:RegisterMainMenuPanel(panelName, show, hide, interface, effectid, context, finishpanel, finishcmd, showcmd, hidecmd, showfunction, hidefunction)
	HoN_Main.menuPanels.table[panelName] = {
		['show'] = show,
		['hide'] = hide,
		['interface'] = interface,
		['effectid'] = effectid,
		['context'] = context,
		['finishpanel'] = finishpanel,
		['finishcmd'] = finishcmd,
		['hidefunction'] = hidefunction,
		['showfunction'] = showfunction,
		['showcmd'] = showcmd,
		['hidecmd'] = hidecmd
		}
end

local function ShowMainCornerAds()
	-- if GetCvarBool('ui_promoCornerLeft') then
	-- 	GetWidget('mainmenu_peel_button'):DoEventN(0)
	-- else
	-- 	GetWidget('mainmenu_peel_button'):DoEventN(1)
	-- end
end

local function HideMainCornerAds()
	-- GetWidget('mainmenu_peel_button'):DoEventN(1)
end

local function ShowMainLogoSpecial()
	ResourceManager.LoadContext('bglogo2')
	ResourceManager.LoadContext('bglogo3')
	if GetWidget('logo_effects_special', nil, true) then
		GetWidget('logo_effects_special'):SetVisible(0)
	end
	GetWidget('main_logo'):Sleep(1, function()

		GetWidget('main_logo'):SetVisible(false)
		GetWidget('main_logo'):Sleep(150, function()
			GetWidget('main_logo'):FadeIn(250)
		end)

		GetWidget('main_logo_popup'):SetVisible(false)
		GetWidget('main_logo_popup'):SetY('5h')
		GetWidget('main_logo_popup'):SetHeight('4.5h')
		GetWidget('main_logo_popup'):SetWidth('4.5h')
		GetWidget('main_logo_popup'):SetRotation(0)

		GetWidget('main_logo_popup'):Sleep(750, function()
			GetWidget('main_logo_popup'):Rotate(360, 500)
			GetWidget('main_logo_popup'):Scale('45.5h', '45.5h', 500)
			GetWidget('main_logo_popup'):FadeIn(150)
			if GetWidget('logo_effects_mp', nil, true) and (GetCvarInt('ui_background') == 2) then
				GetWidget('logo_effects_mp'):UICmd([[SetEffect('/ui/fe2/mainmenu/bg_effects/logo_honiversary.effect')]])
			end
			if GetWidget('logo_effects_mp_2', nil, true) and (GetCvarInt('ui_background') == 1) then
				GetWidget('logo_effects_mp_2'):UICmd([[SetEffect('/ui/fe2/mainmenu/bg_effects/logo_honiversary.effect')]])
			end
			if GetWidget('logo_effects_special', nil, true) then
				GetWidget('logo_effects_special'):UICmd([[SetEffect('/ui/fe2/mainmenu/bg_effects/logo_candle.effect')]])
				GetWidget('logo_effects_special'):FadeIn(150)
			end
			GetWidget('main_logo'):FadeOut(250)
		end)

	end)
end

local function HideMainLogoSpecial()
	if GetWidget('logo_effects_special', nil, true) then
		GetWidget('logo_effects_special'):SetVisible(0)
	end
	GetWidget('main_logo_popup'):SetRotation(0)
	GetWidget('main_logo'):Sleep(1, function()

		GetWidget('main_logo'):SetVisible(false)

		GetWidget('main_logo_popup'):Rotate(360, 500)
		GetWidget('main_logo_popup'):SlideY('-40h', 300)
		GetWidget('main_logo_popup'):Sleep(300, function() GetWidget('main_logo_popup'):SetVisible(false) end)

	end)
	ResourceManager.UnloadContext('bglogo2')
	ResourceManager.UnloadContext('bglogo3')
end

local function ShowMainLogo()
	if (GetCvarInt('ui_background') <= 1) then
		if GetWidget('logo_effects_2') then
			ResourceManager.LoadContext('bgeffects2')
			GetWidget('logo_effects_mp_2'):UICmd([[SetEffect('/ui/fe2/mainmenu/bg_effects/logo.effect')]])
			GetWidget('logo_effects_2'):FadeIn(50)
		end
	elseif (GetCvarInt('ui_background') == 2) then
		if GetWidget('logo_effects') then
			ResourceManager.LoadContext('bgeffects2')
			GetWidget('logo_effects_mp'):UICmd([[SetEffect('/ui/fe2/mainmenu/bg_effects/logo.effect')]])
			GetWidget('logo_effects'):FadeIn(50)
			GetWidget('logo_effects_special'):SetVisible(0)
		end
	end
	if (not GetCvarBool('ui_showSpecialEventLogo')) then
		ResourceManager.LoadContext('bglogo2')
		GetWidget('main_logo'):Sleep(1, function()
			GetWidget('main_logo'):Sleep(100, function() GetWidget('main_logo'):FadeIn(500) end)
			GetWidget('main_logo'):SlideY('1h', 600)
		end)
		if not GetCvarBool('cl_GarenaEnable') then
		GetWidget('main_logo_fb'):Sleep(1, function()
			GetWidget('main_logo_fb'):Sleep(100, function() GetWidget('main_logo_fb'):FadeIn(500) end)
		end)
		GetWidget('fe2_background_new'):Sleep(1, function()
			GetWidget('fe2_background_new'):Sleep(100, function() GetWidget('fe2_background_new'):FadeIn(500) end)
		end)
		end
	else
		ShowMainLogoSpecial()
	end
end

local function HideMainLogo()
	if (GetCvarInt('ui_background') <= 1) then
		if GetWidget('logo_effects_2') then
			ResourceManager.UnloadContext('bgeffects2')
			GetWidget('logo_effects_2'):FadeOut(50)
		end
	elseif (GetCvarInt('ui_background') == 2) then
		if GetWidget('logo_effects') then
			ResourceManager.UnloadContext('bgeffects2')
			GetWidget('logo_effects'):FadeOut(50)
			GetWidget('logo_effects_special'):SetVisible(0)
		end
	end
	if (not GetCvarBool('ui_showSpecialEventLogo')) then
		GetWidget('main_logo'):Sleep(1, function()
			GetWidget('main_logo'):SlideY('-40h', 300)
			GetWidget('main_logo'):Sleep(300, function() GetWidget('main_logo'):SetVisible(false) end)
		end)

		if not GetCvarBool('cl_GarenaEnable') then
		GetWidget('main_logo_fb'):Sleep(1, function()
			GetWidget('main_logo_fb'):Sleep(300, function() GetWidget('main_logo_fb'):SetVisible(false) end)
		end)
		GetWidget('fe2_background_new'):Sleep(1, function()
			GetWidget('fe2_background_new'):Sleep(300, function() GetWidget('fe2_background_new'):SetVisible(false) end)
		end)		
		end		
		ResourceManager.UnloadContext('bglogo2')
	else
		HideMainLogoSpecial()
	end
end

local function ShowBackgroundScene2(showImmediately)
	-- moved to news
	-- if (showImmediately) then
	-- 	GetWidget("motd_background"):SetVisible(0)
	-- else
	-- 	GetWidget("motd_background"):FadeOut(1500)
	-- end

	if (GetCvarInt('ui_background') == 2) and (not ResourceManager.IsContextActive('bgmodels2')) and (not HoN_Main.loadingVisible) and GetWidget('hellbourne_scene', nil, true) and GetWidget('legion_scene', nil, true) then
		--println('^g^: ShowBackgroundScene2: ' .. tostring(showImmediately) )
		ResourceManager.LoadContext('bgmodels2')

		if (not GetWidget('legion_scene'):IsVisible()) then
			GetWidget('legion_scene'):Sleep(1, function()
				if (showImmediately) then
					GetWidget('legion_scene'):FadeIn(500)
					GetWidget('legion_scene'):UICmd("SetAnim('idle')")
				else
					GetWidget('legion_scene'):UICmd("SetAnim('entrance')")
					GetWidget('legion_scene'):Sleep(1, function()
						GetWidget('legion_scene'):SetVisible(true)
						GetWidget('legion_scene'):Sleep(1000, function()
							GetWidget('legion_scene'):UICmd("SetAnim('idle')")
						end)
					end)
				end
			end)
		end
		if (not GetWidget('hellbourne_scene'):IsVisible()) then
			GetWidget('hellbourne_scene'):Sleep(1, function()
				if (showImmediately) then
					GetWidget('hellbourne_scene'):FadeIn(250)
					GetWidget('hellbourne_scene'):UICmd("SetAnim('idle')")
				else
					GetWidget('hellbourne_scene'):UICmd("SetAnim('entrance')")
					GetWidget('hellbourne_scene'):Sleep(1, function()
						GetWidget('hellbourne_scene'):SetVisible(true)
						GetWidget('hellbourne_scene'):Sleep(1000, function()
							GetWidget('hellbourne_scene'):UICmd("SetAnim('idle')")
						end)
					end)
				end
			end)
		end
	end
end

local function HideBackgroundScene2(hideImmediately)
	-- moved to news
	-- if (hideImmediately) then
	-- 	GetWidget("motd_background"):SetVisible(1)
	-- else
	-- 	GetWidget("motd_background"):FadeIn(1500)
	-- end

	if (GetCvarInt('ui_background') == 2) and GetWidget('hellbourne_scene', nil, true) and GetWidget('legion_scene', nil, true) then
		if (ResourceManager.IsContextActive('bgmodels2')) then
			ResourceManager.UnloadContext('bgmodels2')
			if (hideImmediately) then
				GetWidget('legion_scene'):SetVisible(false)
				GetWidget('hellbourne_scene'):SetVisible(false)
				groupfcall('main_background_assets', function(_, widget, _) widget:DoEvent() end)
			else
				GetWidget('legion_scene'):Sleep(1, function()
					--GetWidget('legion_scene'):SlideX('-100%', 150)
					GetWidget('legion_scene'):UICmd("SetAnim('exit')")
					GetWidget('legion_scene'):Sleep(1000, function()
						GetWidget('legion_scene'):SetVisible(0)
						groupfcall('main_background_assets', function(_, widget, _) widget:DoEvent() end)
					end)
				end)
				GetWidget('hellbourne_scene'):Sleep(1, function()
					--GetWidget('hellbourne_scene'):SlideX('100%', 150)
					GetWidget('hellbourne_scene'):UICmd("SetAnim('exit')")
					GetWidget('hellbourne_scene'):Sleep(1000, function() GetWidget('hellbourne_scene'):SetVisible(0) end)
				end)
			end
		else
			GetWidget('legion_scene'):SetVisible(false)
			GetWidget('hellbourne_scene'):SetVisible(false)
			groupfcall('main_background_assets', function(_, widget, _) widget:DoEvent() end)
		end
	end
end

local function ShowOldBackgroundScene()
	if GetWidget('hellbourne_scene_2', nil, true) then
		ResourceManager.LoadContext('bgmodels')
		ResourceManager.LoadContext('bgeffects')
		GetWidget('legion_scene_2'):Sleep(1, function()
			GetWidget('legion_scene_2'):SetVisible(true)
			GetWidget('hellbourne_scene_2'):SetVisible(true)
			GetWidget('hellbourne_scene_2'):UICmd("SetAnim('idle')")
			GetWidget('legion_scene_2'):UICmd("SetAnim('idle')")
			ShowWidget('hellbourne_effects_2')
			ShowWidget('legion_effects_2')
		end)
	end
	GetWidget('event_background_scene'):Sleep(1800, function() PlayMusic(menuMusic, true) end)
	ShowMainLogo()
end

local function HideOldBackgroundScene()
	if GetWidget('hellbourne_scene_2', nil, true) then
		ResourceManager.UnloadContext('bgmodels')
		ResourceManager.UnloadContext('bgeffects')
		GetWidget('hellbourne_scene_2'):UICmd("SetAnim('exit')")
		GetWidget('legion_scene_2'):UICmd("SetAnim('exit')")
		GetWidget('hellbourne_scene_2'):Sleep(2000, function() GetWidget('hellbourne_scene_2'):SetVisible(false) end)
		GetWidget('legion_scene_2'):Sleep(2000, function()
			GetWidget('legion_scene_2'):SetVisible(false)
			groupfcall('main_background_assets', function(_, widget, _) widget:DoEvent() end)
		end)
		HideWidget('hellbourne_effects_2')
		HideWidget('legion_effects_2')
	end
	HideMainLogo()
end

local function ShowBackgroundScene()
	if (GetCvarInt('ui_background') == 1) then
		ShowOldBackgroundScene()
	elseif (GetCvarInt('ui_background') == 2) then
		ShowBackgroundScene2(true)
		GetWidget('event_background_scene'):Sleep(1800, function() PlayMusic(menuMusic, true) end)
		ShowMainLogo()
	else
		ShowMainLogo()
		GetWidget('event_background_scene'):Sleep(1800, function() PlayMusic(menuMusic, true) end)
	end
end

local function HideBackgroundScene()
	if (GetCvarInt('ui_background') == 1) then
		HideOldBackgroundScene()
	elseif (GetCvarInt('ui_background') == 2) then
		HideMainLogo()
		HideBackgroundScene2(false)
	else
		HideMainLogo()
	end
end

local function LoggedOut()
	--println('^cLoggedOut')
	Set("_mainmenu_currentpanel", "")
	GetWidget("MainMenuPanelSwitcher"):DoEvent()

	Cvar.CreateCvar('_loggedin', 'bool', 'false')
	HoN_Main.uiLoginState = true

	if (not IsLoggedIn()) and (not IsLoggingIn()) then
		ShowBackgroundScene()
	end

	if GetCvarBool('cl_GarenaEnable') then
		HideWidget('login_iris');
	end

	GetWidget('event_midbar'):DoEventN(0)
	GetWidget('event_com'):DoEventN(0)
	-- GetWidget('codex_entrance'):SetVisible(false)
	-- GetWidget('codex_entrance_help'):SetVisible(false)

	if GetCvarBool('ui_testCats') then
		local wdgCat = GetWidget('catController', 'cats')
		if wdgCat then
			wdgCat:InterruptSleep()
		end
	end

	-- exit the walkthrough
	Main.walkthroughState = 6
	HoN_Main:DoWalkthrough(nil, "")	-- clear out highlights and stuff
	Main_Walkthrough.ShowWalkthroughTextPanel(false)	-- clear out the textbox
	GetDBEntry('walkthroughState', Main.walkthroughState, true, false, false)	-- save the walkthrough as done

	if NotEmpty(GetCvarString('_socialgroups_currentpanel')) then
		Cvar.CreateCvar('_socialgroups_currentpanel', 'string', '')
		GetWidget('SocialGroupPanelSwitcher'):DoEvent()
	end

	if NotEmpty(GetCvarString('_nickmenu_currentpanel')) then
		Cvar.CreateCvar('_nickmenu_currentpanel', 'string', '')
		GetWidget('NickMenuPanelSwitcher'):DoEvent()
	end

	if GetCvarBool('login_rememberPassword') and NotEmpty(GetCvarString('login_name')) and NotEmpty(GetCvarString('login_password')) then
		ShowWidget('auto_auth_txt')
		GetWidget('main_login_button'):SetEnabled(true)
	else
		HideWidget('auto_auth_txt')
	end

end

local function LoggedIn()
	--println('^cLoggedIn')
	Cvar.CreateCvar('_loggedin', 'bool', 'true')
	HoN_Main.uiLoginState = false

	UpdateTimeDependantFunctionality()

	HideBackgroundScene()
	if GetCvarBool('cl_GarenaEnable') then
		ShowWidget('login_iris');
	end
	PlaySound('/shared/sounds/ui/menu/iris_close.wav')
	GetWidget('event_com'):Sleep(100, function() GetWidget('event_com'):DoEventN(1) end)
	GetWidget('event_load_b'):Sleep(1000, function() GetWidget('event_midbar'):DoEventN(1) end)
	-- GetWidget('codex_entrance'):SetVisible(true)
	-- GetWidget('codex_entrance_help'):SetVisible(true)

	-- April fools stuff
	local eightBitInfo = GetDBEntry("eightBitInfo")
	if (eightBitInfo) then
		if(eightBitInfo.enabled) then
			if (eightBitInfo.savedRings and eightBitInfo.savedPostEffects) then
				Set('cg_showSelectionRings', eightBitInfo.savedRings, 'bool')
				Set('vid_postEffects', eightBitInfo.savedPostEffects, 'bool')

				Set('vid_render3Das2D', false, 'bool')
				Set('skel_interpolate', true, 'bool')
				Set('skel_blendAnims', true, 'bool')
				Set('skel_skipKeyFrames', false, 'bool')
				Set('vid_models90DegreeAxis', false, 'bool')
				Set('effect_flatYAxis', false, 'bool')
				Set('vid_posteffectpath', '/core/post/bloom.posteffect', 'string')
			end

			eightBitInfo.enabled = false
			eightBitInfo.savedRings = nil
			eightBitInfo.savedPostEffects = nil
		end
		eightBitInfo.needToLoad = nil
		GetDBEntry("eightBitInfo", eightBitInfo, true)
	end
	--------------------

	---[[
	if (not GetCvarBool('ui_disableChatServer')) then
		if GetCvarBool('login_invisible') then
			interface:UICmd("ChatConnect(1)")
		else
			interface:UICmd("ChatConnect(0)")
		end
		interface:UICmd("CheckReconnect()")
	end
	--]]

	if IsChatMuted and IsChatMuted() then
		GetWidget('sysbar_mute_notification'):SetVisible(1)
		GetWidget('sysbar_mute_notification_label'):UICmd([[SetText(FormatStringNewLine(Translate('sysbar_muted_notice', 'days', ]] .. ceil(GetChatMuteExpiration()/86400) .. [[ ) ) )]])
	end

	if (UIGamePhase() <= 0) then
		-- Show the malikens message splash screen
		local value, setDefault, setCurrent = GetDBEntry('firstTimePrompt3', 1, false, false, false)
		if GetWidget('main_splash_maliken', nil, true) and GetCvarBool('ui_showMalikenMessage') and ((value ~= 1 or setDefault) or GetCvarBool('ui_dev_feature_7') or (not GetCvarBool('ui_maliken_letter_4'))) then
			UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'main_splash_maliken', nil, nil, nil, nil, 63)
		elseif GetCvarBool('ui_showMalikenMessage') then
			local MalikenLetterWidget = GetWidget('news_maliken_msg_btn_parent')
			if MalikenLetterWidget then
				MalikenLetterWidget:SetVisible(true)
			end
		end

		if (not GetCvarBool('ui_supressNews')) and (tonumber(UIGetAccountID()) > 0) then
			-- Request the news
			GetWidget('load_news'):Sleep(1350, function() Trigger('RequestMessageOfTheDay') end)
		end
	end
	if (UI.RequiresValidation) then
		UI.RequiresValidation = false
		ValidateScriptVersions(true)
	end
end

local questsLastDisabled			= false
local questLadderLastDisabled		= false
local questsLastDisabledReason		= false
local questLadderLastDisabledReason	= false

local QUEST_DISABLED_REASON_GENERAL		= 0
local QUEST_DISABLED_REASON_ISENABLED	= 1
local QUEST_DISABLED_REASON_TECHNICAL	= 2
local QUEST_DISABLED_REASON_SEASON		= 3

local chatLastConnected	= false

local function questsDisabledUpdate()

	if questLadderLastDisabled or (not chatLastConnected) then
		GetWidget('playerLadderQuestsEnabledParent'):SetVisible(false)
		--if GetWidget('player_ladder'):IsVisible() then
		--	Player_Stats.ClickedLadder()
		--end
	else
		GetWidget('playerLadderQuestsEnabledParent'):SetVisible(true)
	end

	if questsLastDisabled or (not chatLastConnected) then
		GetWidget('quest_tab_label'):SetText(Translate('quests_disabled'))
		GetWidget('quest_tab'):SetEnabled(false)
		HoN_Main:SelectChat()
	else
		GetWidget('quest_tab_label'):SetText(Translate('communicator_tab_quests'))
		GetWidget('quest_tab'):SetEnabled(true)
	end
end

interface:RegisterWatch('ChatStatus', function(widget, isConnected)
	chatLastConnected = AtoB(isConnected)

	questsDisabledUpdate()
end)

interface:RegisterWatch('QuestsDisabled', function(widget, questsDisabled, questsDisabledReason, questLadderDisabled, questLadderDisabledReason)
	questsLastDisabled = AtoB(questsDisabled)
	questLadderLastDisabled = AtoB(questLadderDisabled)

	questsLastDisabledReason = AtoN(questsDisabledReason)
	questLadderLastDisabledReason = AtoN(questLadderDisabledReason)

	questsDisabledUpdate()

end)

-- accountStatus: offline/waiting/success/failure/expired
local function LoginStatus(self, accountStatus, statusDescription, isLoggedIn, pwordExpired, isLoggedInChanged, updaterStatus)
	local isLoggedIn, pwordExpired, isLoggedInChanged, updaterStatus = AtoB(isLoggedIn), AtoB(pwordExpired), AtoB(isLoggedInChanged), tonumber(updaterStatus)
	LoggedIn()
	if (HoN_IM_Panel) then
		HoN_IM_Panel:OnLogin()
	end

	if HoN_Region.regionTable[HoN_Region.activeRegion].questSystem and (not questsLastDisabled) then
		HoN_Main:SelectQuests()
	else
		HoN_Main:SelectChat()
	end
end
interface:RegisterWatch('LoginStatus', LoginStatus)

local function MainMenuButtonsHandler(disableAll)
	local gamephase = HoN_Main.gamePhase
	local ascensionEnabled = GetCvarBool('cg_ascensionEnabled')
	
	if (disableAll) then
		-- GetWidget('midbar_button_creategame'):SetEnabled(false)
		GetWidget('midbar_button_publicgames'):SetEnabled(false)
		GetWidget('midbar_button_matchmaking'):SetEnabled(false)
		GetWidget('midbar_button_hontour'):SetEnabled(false)
		-- GetWidget('midbar_button_hontour_effect'):SetVisible(false)
		-- GetWidget('midbar_button_matchstats_1'):SetEnabled(false)
		GetWidget('midbar_button_matchstats_2'):SetEnabled(false)
		GetWidget('midbar_button_compendium'):SetEnabled(false)
		GetWidget('midbar_button_plinko'):SetEnabled(false)
		GetWidget('midbar_button_store'):SetEnabled(false)
		if (GetWidget('midbar_button_ladder', nil, true)) then
			GetWidget('midbar_button_ladder'):SetEnabled(false)
		end
		return
	elseif (gamephase == 0) then
		if (IsInQueue() or IsInScheduledMatch()) then 		--IsInGroup() or
			-- GetWidget('midbar_button_creategame'):SetEnabled(false)
			GetWidget('midbar_button_publicgames'):SetEnabled(false)
			GetWidget('midbar_button_hontour'):SetEnabled(false)
		else
			-- GetWidget('midbar_button_creategame'):SetEnabled(true)
			GetWidget('midbar_button_publicgames'):SetEnabled(true)
			GetWidget('midbar_button_hontour'):SetEnabled(IsTMMEnabled())
		end

		GetWidget('midbar_button_matchmaking'):SetEnabled(IsTMMEnabled())
		-- GetWidget('midbar_button_hontour_effect'):SetVisible(ascensionEnabled)
		-- GetWidget('midbar_button_matchstats_1'):SetEnabled(true)
		GetWidget('midbar_button_matchstats_2'):SetEnabled(true)
		GetWidget('midbar_button_compendium'):SetEnabled(true)
		GetWidget('midbar_button_plinko'):SetEnabled(true)
		GetWidget('midbar_button_store'):SetEnabled(true)
		if (GetWidget('midbar_button_ladder', nil, true)) then
			if (HoN_Region.regionTable[HoN_Region.activeRegion].ladder) then
				GetWidget('midbar_button_ladder'):SetEnabled(true)
			else
				GetWidget('midbar_button_ladder'):SetEnabled(false)
			end
		end

	elseif (gamephase == 1) then
		-- GetWidget('midbar_button_creategame'):SetEnabled(false)
		-- GetWidget('midbar_button_publicgames'):SetEnabled(true)
		GetWidget('midbar_button_matchmaking'):SetEnabled(false)
		-- GetWidget('midbar_button_matchstats_1'):SetEnabled(true)
		-- GetWidget('midbar_button_hontour'):SetEnabled(false)
		-- GetWidget('midbar_button_hontour_effect'):SetVisible(ascensionEnabled)
		GetWidget('midbar_button_matchstats_2'):SetEnabled(true)
		GetWidget('midbar_button_compendium'):SetEnabled(true)
		GetWidget('midbar_button_plinko'):SetEnabled(true)
		GetWidget('midbar_button_store'):SetEnabled(true)
		if (GetWidget('midbar_button_ladder', nil, true)) then
			if (HoN_Region.regionTable[HoN_Region.activeRegion].ladder) then
				GetWidget('midbar_button_ladder'):SetEnabled(true)
			else
				GetWidget('midbar_button_ladder'):SetEnabled(false)
			end
		end

	elseif (gamephase == 2) then
		-- GetWidget('midbar_button_creategame'):SetEnabled(false)
		GetWidget('midbar_button_publicgames'):SetEnabled(false)
		-- GetWidget('midbar_button_matchmaking'):SetEnabled(false)
		-- GetWidget('midbar_button_matchstats_1'):SetEnabled(true)
		-- GetWidget('midbar_button_hontour'):SetEnabled(false)
		-- GetWidget('midbar_button_hontour_effect'):SetVisible(ascensionEnabled)
		GetWidget('midbar_button_matchstats_2'):SetEnabled(true)
		GetWidget('midbar_button_compendium'):SetEnabled(true)
		GetWidget('midbar_button_plinko'):SetEnabled(true)
		GetWidget('midbar_button_store'):SetEnabled(true)
		if (GetWidget('midbar_button_ladder', nil, true)) then
			if (HoN_Region.regionTable[HoN_Region.activeRegion].ladder) then
				GetWidget('midbar_button_ladder'):SetEnabled(true)
			else
				GetWidget('midbar_button_ladder'):SetEnabled(false)
			end
		end
	end

	if gamephase ~= 0 then
		local isViewingGame = ViewingReplay() or ViewingStreaming()
		local isLocalBotGame = GetCvarBool('ui_local_bot_game')
		local isButtonEnabled = isViewingGame or isLocalBotGame
		-- Disable matchmaking and publicgames and watch when in a game
		-- Enable matchmaking and publicgames and watch when viewing game or in local bot game
		GetWidget('midbar_button_hontour'):SetEnabled(isButtonEnabled)
		GetWidget('midbar_button_publicgames'):SetEnabled(isButtonEnabled)
		GetWidget('midbar_button_matchmaking'):SetEnabled(isButtonEnabled)
	end

	if rap2Enable then
		local isSuspended = AtoB(interface:UICmd("IsAccountSuspended()"))
		if isSuspended then
			GetWidget('midbar_button_matchmaking'):SetEnabled(false)
		end
	end

	-- Strictly disable HoN Live in NAEU
	if not GetCvarBool('cl_GarenaEnable') then
		GetWidget('midbar_button_hontour'):SetEnabled(false)
	end
end

local function LoginRapStatus(self, forcePopup ,accountStatus, reason, guiltyLevel, endDate)

	if rap2Enable == false then
		return
	end

	Echo('forcePopup: '..forcePopup..' accountStatus: '..accountStatus..' reason: '..reason..' guiltyLevel: '..guiltyLevel..' endDate: '..endDate)

	local rapSysBtn = GetWidget('sysbar_rap_button')
	local title = GetWidget('rap_status_name')
	local progressBar = GetWidget('rap_progress_bar')
	local content = GetWidget('rap_content')
	local reasonTitle = GetWidget('rap_reason_title')
	local reasonContent = GetWidget('rap_reason')
	local observationTips = GetWidget('rap_observation_tip')
	local observationContent = GetWidget('rap_observation_content')

	if accountStatus == '0' then
		Echo('............................Current Account Status Normal............................')
		rapSysBtn:SetVisible(0)
		UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'rap_status', nil, nil, true)
		return
	elseif accountStatus == '1' then

		Echo('............................Current Account Status Warning............................')
		rapSysBtn:SetVisible(1)
		-- Title and ProgressBar
		title:SetText(Translate('rap_warning_status'))
		title:SetColor('#fff200')
		progressBar:SetTexture('/ui/fe2/rap/progress_bar_2.tga')
		-- Line 1
		content:SetText(Translate('rap_warning_content'))
		content:SetVisible(true)
		-- Line 2
		if reason ~= '0' then
			reasonTitle:SetText(Translate('rap_reason_title'))
			reasonTitle:SetVisible(true)
			reasonContent:SetText(Translate('rap_reason'..reason))
			reasonContent:SetVisible(true)
		else
			reasonTitle:SetText(Translate('rap_reason'..reason))
			reasonTitle:SetVisible(true)
			reasonContent:SetVisible(false)
		end
		-- Line 3
		observationTips:SetVisible(false)
		observationContent:SetVisible(false)

	elseif accountStatus == '2' then

		Echo('............................Current Account Status Suspended............................')
		rapSysBtn:SetVisible(1)
		-- Title and ProgressBar
		title:SetText(Translate('rap_suspended_status'))
		title:SetColor('#ff0002')
		progressBar:SetTexture('/ui/fe2/rap/progress_bar_3.tga')
		-- Line 1
		content:SetText(Translate('rap_suspended_content', 'endDate', endDate))
		content:SetVisible(true)
		-- Line 2
		if reason ~= '0' then
			reasonTitle:SetText(Translate('rap_reason_title'))
			reasonTitle:SetVisible(true)
			reasonContent:SetText(Translate('rap_reason'..reason))
			reasonContent:SetVisible(true)
		else
			reasonTitle:SetText(Translate('rap_reason'..reason))
			reasonTitle:SetVisible(true)
			reasonContent:SetVisible(false)
		end
		-- Line 3
		observationTips:SetVisible(false)
		observationContent:SetVisible(false)

		MainMenuButtonsHandler()

	elseif accountStatus == '3' then

		Echo('............................Current Account Status Observed............................')
		rapSysBtn:SetVisible(1)
		-- Title and ProgressBar
		title:SetText(Translate('rap_observating_status'))
		title:SetColor('#ffffff')
		progressBar:SetTexture('/ui/fe2/rap/progress_bar_1.tga')
		-- Line 1
		content:SetVisible(false)
		-- Line 2
		if reason ~= '0' then
			reasonTitle:SetText(Translate('rap_reason_title'))
			reasonTitle:SetVisible(true)
			reasonContent:SetText(Translate('rap_reason'..reason))
			reasonContent:SetVisible(true)
		else
			reasonTitle:SetText(Translate('rap_reason'..reason))
			reasonTitle:SetVisible(true)
			reasonContent:SetVisible(false)
		end
		-- Line 3
		observationTips:SetVisible(true)
		observationContent:SetText(Translate('rap_observation_content', 'guiltLevel', guiltyLevel, 'endDate', endDate))
		observationContent:SetVisible(true)

		MainMenuButtonsHandler()

	elseif accountStatus == '4' then

		Echo('............................Current Account Status Observed Warning ............................')
		rapSysBtn:SetVisible(1)
		-- Title and ProgressBar
		title:SetText(Translate('rap_warning_status'))
		title:SetColor('#fff200')
		progressBar:SetTexture('/ui/fe2/rap/progress_bar_2.tga')
		-- Line 1
		content:SetText(Translate('rap_warning_content'))
		content:SetVisible(true)
		-- Line 2
		if reason ~= '0' then
			reasonTitle:SetText(Translate('rap_reason_title'))
			reasonTitle:SetVisible(true)
			reasonContent:SetText(Translate('rap_reason'..reason))
			reasonContent:SetVisible(true)
		else
			reasonTitle:SetText(Translate('rap_reason'..reason))
			reasonTitle:SetVisible(true)
			reasonContent:SetVisible(false)
		end
		-- Line 3
		observationTips:SetVisible(true)
		observationContent:SetText(Translate('rap_observation_content', 'guiltLevel', guiltyLevel, 'endDate', endDate))
		observationContent:SetVisible(true)
	end

	if forcePopup == 'true' then
		UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'rap_status', nil, true)
	end
end
interface:RegisterWatch('LoginRapStatus', LoginRapStatus)

local function CheckForAutoLogin()
	if GetCvarBool('login_rememberPassword') and (not IsLoggedIn()) and (not IsLoggingIn()) and GetWidget('main_login_password') then
		Set('_autologin_loggedin', 'true', 'bool')
		GetWidget('main_status'):UICmd([[SetWatch('']])
		GetWidget('main_logging_in'):UICmd([[SetWatch('']])
		GetWidget('main_login_status_textbox_1'):UICmd([[SetWatch('']])
		GetWidget('main_login_cancel_button'):UICmd([[SetWatch('']])
		GetWidget('main_login_button'):SetEnabled(false)
		GetWidget('main_login_password'):Sleep(1, function()
			GetWidget('main_status'):SetVisible(true)
			GetWidget('main_logging_in'):SetVisible(true)
			GetWidget('main_login_status_textbox_1'):SetText(Translate('main_label_login_status_prewaiting'))
			GetWidget('main_login_cancel_button'):SetVisible(true)
			GetWidget('main_login_password'):Sleep(250, function()
				GetWidget('main_login_button'):SetEnabled(true)
				GetWidget('main_status'):UICmd([[SetWatch('LoginStatus']])
				GetWidget('main_logging_in'):UICmd([[SetWatch('LoginStatus']])
				GetWidget('main_login_status_textbox_1'):UICmd([[SetWatch('LoginStatus']])
				GetWidget('main_login_cancel_button'):UICmd([[SetWatch('LoginStatus']])
				interface:UICmd([[If(login_rememberPassword, Login(main_login_user, main_login_password))]])
			end)
		end)
	end
end

function Main.InitMain(useLoginSystem)
	interface:Sleep(1, function()
		if (not IsLoggedIn()) and (not IsLoggingIn()) then
			ShowBackgroundScene()
		end
		if (useLoginSystem) then
			CheckForAutoLogin()
		end
		-- Run script at this path if present
		if (ExecuteConsoleScript) and GetCvarString('ui_LoginConsoleScript', true) then
			ExecuteConsoleScript(GetCvarString('ui_LoginConsoleScript'))
		end
	end)
end

local function UpdaterStatus(self, status)
	--println('UpdaterStatus ' .. status)
	local status = tonumber(status)
	if (status == 3) or (status == 7) then
		GetWidget('patch_updater'):SlideY('2%', 300)
		GetWidget('login_gear'):Rotate(73, 300)
	else
		GetWidget('patch_updater'):SlideY('45%', 300)
		GetWidget('login_gear'):Rotate(0, 300)
	end
end
interface:RegisterWatch('UpdaterStatus', UpdaterStatus)

local function UpdateStatus(self, status)
	--Echo('UpdateStatus status: '..status)
	local status = tonumber(status)
	
	if (status == 7) then
		GetWidget('main_update_confirm'):SetVisible(true) --an update was available, show box
	elseif (status == 8) then 
		GetWidget('main_update_confirm'):SetVisible(false) --triggers when user says no to update
	end

	GetWidget('main_update_download'):SetVisible(status == 3) --this is no longer used, and was for the in-game updater system.
	
end
interface:RegisterWatch('UpdateStatus', UpdateStatus)

function HoN_Main:SwitchedAccount()
	--println('^cSwitched Account')
	HoN_Main.uiLoginState = true
end

function HoN_Main:MainMenuPanelToggle(targetPanel, extInterface, forceOpen, forceClose, softOpen, id)
	printdb('^cMainMenuPanelToggle targetPanel: ' .. tostring(targetPanel) .. ' | currentPanel: ' .. tostring(HoN_Main.menuPanels.currentPanel) .. ' | extInterface: '.. tostring(extInterface) .. ' | forceOpen: '.. tostring(forceOpen) .. ' | forceClose: '.. tostring(forceClose) .. ' | softOpen: '.. tostring(softOpen) .. ' | id: '.. tostring(id) )
	if (forceOpen) 	and (type(forceOpen) == 'string')   then forceOpen  = AtoB(forceOpen) 	end
	if (forceClose) and (type(forceClose) == 'string') 	then forceClose = AtoB(forceClose)  end
	if (softOpen) 	and (type(softOpen) == 'string')	then softOpen 	= AtoB(softOpen) 	end

	GetMainMenuPanels()
	CheckForWalkthrough()

	if NotEmpty(targetPanel) then
		local panelWidget = GetWidget(targetPanel, extInterface)

		if (panelWidget) then
			if (NotEmpty(HoN_Main.menuPanels.currentPanel) and not GetWidget(HoN_Main.menuPanels.currentPanel):IsVisible()) then
				if (HoN_Main.menuPanels.currentPanel == "news") then
					HideNews()
				end
				HoN_Main.menuPanels.currentPanel = ""
			end

			if NotEmpty(HoN_Main.menuPanels.currentPanel) and (softOpen) then
				printdb('^oMainMenuPanelToggle: Soft open - did not open ' ..tostring(targetPanel)..' because ' .. HoN_Main.menuPanels.currentPanel)
				if (targetPanel ~= "news") then 	-- don't queue the news
					HoN_Main.menuPanels.panelQueue = targetPanel
				end
			else
				if (HoN_Main.menuPanels.table[targetPanel]) and (HoN_Main.menuPanels.table[targetPanel].hide) and (HoN_Main.menuPanels.table[targetPanel].show)  then
					local isVisible = panelWidget:IsVisible()
					if (forceOpen) then
						if (not isVisible) then
							if (HoN_Main.menuPanels.table[targetPanel].context) then
								ResourceManager.LoadContext(HoN_Main.menuPanels.table[targetPanel].context)
							end
							HideMainCornerAds()
							HoN_Main.menuPanels.table[targetPanel].show(panelWidget)
							HoN_Main.menuPanels.currentPanel = targetPanel
							--Set('_mainmenu_currentpanel', targetPanel)
						end
						if (HoN_Main.menuPanels.table[targetPanel].showcmd) then
							panelWidget:UICmd(""..(HoN_Main.menuPanels.table[targetPanel].showcmd).."")
						end
						if (HoN_Main.menuPanels.table[targetPanel].showfunction) then
							HoN_Main.menuPanels.table[targetPanel].showfunction()
						end
					elseif (forceClose) then
						if (isVisible) then
							HoN_Main.menuPanels.currentPanel = ''
							--Set('_mainmenu_currentpanel', '')
							if (HoN_Main.menuPanels.table[targetPanel].hidecmd) then
								panelWidget:UICmd(""..(HoN_Main.menuPanels.table[targetPanel].hidecmd).."")
							end
							HoN_Main.menuPanels.table[targetPanel].hide(panelWidget)
							if (HoN_Main.menuPanels.table[targetPanel].hidefunction) then
								HoN_Main.menuPanels.table[targetPanel].hidefunction()
							end
							-- forceClose does not unload assests
						end
					else
						if (isVisible) then
							ShowMainCornerAds()
							HoN_Main.menuPanels.currentPanel = ''
							--Set('_mainmenu_currentpanel', '')
							if (HoN_Main.menuPanels.table[targetPanel].hidecmd) then
								panelWidget:UICmd(""..(HoN_Main.menuPanels.table[targetPanel].hidecmd).."")
							end
							HoN_Main.menuPanels.table[targetPanel].hide(panelWidget)
							if (HoN_Main.menuPanels.table[targetPanel].hidefunction) then
								HoN_Main.menuPanels.table[targetPanel].hidefunction()
							end
							if (HoN_Main.menuPanels.table[targetPanel].effectid) and GetCvarBool('cg_menuTransitions') then
								Trigger('main_panel_effects_slideout', (HoN_Main.menuPanels.table[targetPanel].effectid))
							end
							if (HoN_Main.menuPanels.table[targetPanel].context) then
								ResourceManager.UnloadContext(HoN_Main.menuPanels.table[targetPanel].context)
							end
							if NotEmpty(HoN_Main.menuPanels.panelQueue) and (HoN_Main.menuPanels.panelQueue ~= targetPanel) and (not (HoN_Main.loadingVisible)) then
								targetPanel = HoN_Main.menuPanels.panelQueue
								printdb('^oMainMenuPanelToggle: Soft open - delayed opening ' ..tostring(targetPanel)..' because ' .. HoN_Main.menuPanels.currentPanel)
								HoN_Main.menuPanels.panelQueue = ''
								HoN_Main:MainMenuPanelToggle(targetPanel, 'main', false, false, false, 60)
							elseif (not GetCvarBool('ui_supressNews')) and ((Main.walkthroughState < 2) or (Main.walkthroughState > 5))  then
								interface:HoNNewsF('ReopenNews')
							end
						else
							if (HoN_Main.menuPanels.table[targetPanel].context) then
								ResourceManager.LoadContext(HoN_Main.menuPanels.table[targetPanel].context)
							end
							HideMainCornerAds()
							if (HoN_Main.menuPanels.table[targetPanel].showcmd) then
								panelWidget:UICmd(""..(HoN_Main.menuPanels.table[targetPanel].showcmd).."")
							end
							if (HoN_Main.menuPanels.table[targetPanel].showfunction) then
								HoN_Main.menuPanels.table[targetPanel].showfunction()
							end
							HoN_Main.menuPanels.table[targetPanel].show(panelWidget)
							HoN_Main.menuPanels.currentPanel = targetPanel
							--Set('_mainmenu_currentpanel', targetPanel)
							if (HoN_Main.menuPanels.table[targetPanel].effectid) and GetCvarBool('cg_menuTransitions') then
								Trigger('main_panel_effects_slidein', (HoN_Main.menuPanels.table[targetPanel].effectid))
							end
							if (HoN_Main.menuPanels.table[targetPanel].finishpanel) and (WidgetExists(HoN_Main.menuPanels.table[targetPanel].finishpanel)) and (HoN_Main.menuPanels.table[targetPanel].finishcmd) then
								GetWidget(HoN_Main.menuPanels.table[targetPanel].finishpanel):Sleep(500, function() GetWidget(HoN_Main.menuPanels.table[targetPanel].finishpanel):UICmd(""..(HoN_Main.menuPanels.table[targetPanel].finishcmd).."") end)
							end
						end
					end
				else
					println('^oMainMenuPanelToggle: Found widget ' ..tostring(targetPanel)..' without a complete table entry. Add one in main.lua GetMainMenuPanels() ')
				end
			end
		else
			println('^oMainMenuPanelToggle: Could not find widget ' ..tostring(targetPanel)..' in interface '..tostring(extInterface))
		end
	end

	if (HoN_Main.menuPanels.table) and (not forceClose) and (not softOpen) then
		for panelName, panelTable in pairs(HoN_Main.menuPanels.table) do
			local panelWidget
			if (HoN_Main.menuPanels.table[targetPanel]) and (HoN_Main.menuPanels.table[targetPanel].interface) then
				panelWidget = GetWidget(panelName, (HoN_Main.menuPanels.table[targetPanel].interface), true)
			else
				panelWidget = GetWidget(panelName, nil, true)
			end

			if (panelWidget) and (panelName ~= targetPanel) and (panelWidget:IsVisibleSelf()) then
				HoN_Main.menuPanels.table[panelName].hide(panelWidget)
				if (HoN_Main.menuPanels.table[panelName].hidefunction) then
					HoN_Main.menuPanels.table[panelName].hidefunction()
				end
				if (HoN_Main.menuPanels.table[panelName].context) then
					ResourceManager.UnloadContext(HoN_Main.menuPanels.table[panelName].context)
				end
			end
		end
	end
end



local function TMMGamePhase(self, TMMGamePhase)
	local TMMGamePhase = tonumber(TMMGamePhase)
	if (TMMGamePhase > 0) then
		HideBackgroundScene2(true)
	end
end
interface:RegisterWatch('TMMGamePhase', TMMGamePhase)

local function GamePhase(self, gamePhase) -- 0 main, 1 lobby, 3 hero picker, 6 ingame
	local gamePhase = tonumber(gamePhase)

	if (gamePhase == 0) then
		if IsLoggedIn() then
			--ShowBackgroundScene2(true)
			if ((Main.walkthroughState < 1) or (Main.walkthroughState > 5)) then
				interface:HoNNewsF('ReopenNews')
			end
		end
		if ((WaitingToShowStats() or GetCvarBool('ui_match_stats_waitingToShow')) and (GetShowStatsMatchID() ~= 4294967295)) then
			UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'match_stats', nil, true)
		end
		lobbyMusicMapLast = ''

		local gameArcadeTextModel
		

		for i=1,3,1 do
			gameArcadeTextModel = GetWidget('game_arcade_model_'..i, 'game')
			if gameArcadeTextModel and type(gameArcadeTextModel) == 'userdata' then
				gameArcadeTextModel:SetEffect('')
			end
		end
	elseif (gamePhase > 0) and (gamePhase < 5) then
		HideBackgroundScene2(true)
		ResourceManager.LoadContext('lobby')
		if (gamePhase == 1) or (gamePhase == 3) then
			
			if lobbyMusicLastPhase < 1 then
				playLobbyMusic()
			end
		end
	elseif (ResourceManager.IsContextActive('lobby')) then
		if GetWidget('game_lobby_alt_preview_modelpanel_1_1') then
			GetWidget('game_lobby_alt_preview_modelpanel_1_0'):UICmd([[SetModel(''); SetEffect('');]])
			GetWidget('game_lobby_alt_preview_modelpanel_1_1'):UICmd([[SetModel(''); SetEffect('');]])
			GetWidget('game_lobby_alt_preview_modelpanel_1_2'):UICmd([[SetModel(''); SetEffect('');]])
			GetWidget('game_lobby_alt_preview_modelpanel_1_3'):UICmd([[SetModel(''); SetEffect('');]])
			GetWidget('game_lobby_alt_preview_modelpanel_1_4'):UICmd([[SetModel(''); SetEffect('');]])
			GetWidget('game_lobby_alt_preview_modelpanel_1_5'):UICmd([[SetModel(''); SetEffect('');]])
		end
		if GetWidget('game_lobby_alt_preview_modelpanel_2') then
			GetWidget('game_lobby_alt_preview_modelpanel_2'):UICmd([[SetModel(''); SetEffect('');]])
		end
		ResourceManager.UnloadContext('lobby')
	end
	
	lobbyMusicLastPhase = gamePhase

	if (gamePhase <= 2) then
		groupfcall('asset_loading_bars', function(_, widget, _) widget:SetWidth(0) end)
	end

	HoN_Main.gamePhase = gamePhase
	Cvar.CreateCvar('_game_phase', 'int', gamePhase)
	MainMenuButtonsHandler()

	if (GameChat) then
		GameChat.GamePhase(sourceWidget, gamePhase)
	end
	if (HoN_Notifications) then
		HoN_Notifications.GamePhase(sourceWidget, gamePhase)
	end
	-- clear out filter selections
	if (Game_Lobby and (gamePhase <= 1)) then
		Game_Lobby:ClearFilters()
	end
end
interface:RegisterWatch('GamePhase', GamePhase)

local function LoadingVisible(_,isLoading)
	HoN_Main.loadingVisible = AtoB(isLoading)
	if (HoN_Main.loadingVisible) then
		HideBackgroundScene2(true)
		UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'game_list', nil, nil, true, nil, 3)
	end
end
interface:RegisterWatch('LoadingVisible', LoadingVisible)

local function TMMDisplay(self)
	MainMenuButtonsHandler()
end
interface:RegisterWatch('TMMDisplay', TMMDisplay)

local function TMMReset(self)
	MainMenuButtonsHandler()
end
interface:RegisterWatch('TMMReset', TMMReset)

local function TMMAvailable(self)
	MainMenuButtonsHandler()
end
interface:RegisterWatch('TMMAvailable', TMMAvailable)

local function EntityDefinitionsLoaded(self)
	MainMenuButtonsHandler()
end
interface:RegisterWatch('EntityDefinitionsLoaded', EntityDefinitionsLoaded)

local function EntityDefinitionsProgress(self)
	MainMenuButtonsHandler(true)
end
interface:RegisterWatch('EntityDefinitionsProgress', EntityDefinitionsProgress)

local function ScheduledMatchListing(self)
	MainMenuButtonsHandler()
end
interface:RegisterWatch('ScheduledMatchListing', ScheduledMatchListing)

local function EventListing(self)
	MainMenuButtonsHandler()
end
interface:RegisterWatch('EventListing', EventListing)

local function ScheduledMatchInfo(self)
	MainMenuButtonsHandler()
end
interface:RegisterWatch('ScheduledMatchInfo', ScheduledMatchInfo)

local function Initialize()
	interface:RegisterWatch('MainInterfaceInitialize', function() Initialize() end )
end
Initialize()

local function MainRegisterTextures()
	--println('^cMainRegisterTextures - Requesting Texture Registration')
	if (HoN_Main.uiPrecacheWorld) then
		interface:Sleep(550, function() ResourceManager.PrecacheAll() end )
	end
end
interface:RegisterWatch('MainRegisterTextures', function() MainRegisterTextures() end )

function HoN_Main:LoadSpecUI()
	ResourceManager.LoadContext('specui')
end

function HoN_Main:UnloadSpecUI()
	ResourceManager.UnloadContext('specui')
end

local function AnimatePointerIn(pointerWidget, x, y)
	--println('AnimatePointerIn')
	pointerWidget:SlideX(pointerWidget:GetX() - (x * (pointerWidget:GetWidth())), 800)
	pointerWidget:SlideY(pointerWidget:GetY() - (y * (pointerWidget:GetHeight())), 800)
	pointerWidget:Sleep(840, function() pointerWidget:DoEvent() end)
end

local function AnimatePointerOut(pointerWidget, x, y)
	--println('AnimatePointerOut')
	pointerWidget:SlideX(pointerWidget:GetX() + (x * (pointerWidget:GetWidth())), 800)
	pointerWidget:SlideY(pointerWidget:GetY() + (y * (pointerWidget:GetHeight())), 800)
	pointerWidget.onevent = function() AnimatePointerOut(pointerWidget, x, y) end
	pointerWidget:RefreshCallbacks()
	pointerWidget:Sleep(840, function() AnimatePointerIn(pointerWidget, x, y) end)
end

local function PointAtWidget(targetWidget, doPointer, pointerLabel)
	local pointer		= GetWidget('main_widget_highlighter_pointer')
	local label_frame 	= GetWidget('main_widget_highlighter_label_frame')
	local label 		= GetWidget('main_widget_highlighter_label')

	if (doPointer) and (targetWidget) then
		pointer:FadeIn(1000)
		if (pointerLabel) and NotEmpty(pointerLabel) then
			label_frame:FadeIn(1000)
			label_frame:BringToFront()
			label:SetText(Translate(pointerLabel))
		else
			label_frame:SetVisible(false)
		end
		pointer:BringToFront()
		local screenWidth = tonumber(interface:UICmd("GetScreenWidth()"))
		local screenHeight = tonumber(interface:UICmd("GetScreenHeight()"))
		local x = targetWidget:GetAbsoluteX()
		local y = targetWidget:GetAbsoluteY()
		local targetWidth = targetWidget:GetWidth()
		local targetHeight = targetWidget:GetHeight()
		local labelWidth = label_frame:GetWidth()
		local labelHeight = label_frame:GetHeight()
		local pointerWidth = pointer:GetWidth()/2
		local pointerHeight = pointer:GetHeight()/2

		if x > (screenWidth / 2) then
			pointer:SetX(x + (-1.5 * pointerWidth ))
			label_frame:SetX(x + (-1 * (labelWidth + (pointerWidth * 2.1))) )

			if y > (screenHeight / 2) then
				pointer:SetRotation('135')
				pointer:SetY(y + (-1.5 * targetHeight ))
				label_frame:SetY(y + (-1 * (labelHeight + (pointerHeight * 2.1))) )
				AnimatePointerOut(pointer, -0.5, -0.5)
			else
				pointer:SetRotation('45')
				pointer:SetY(y + (0.5 * targetHeight ))
				label_frame:SetY(y + (1 * (targetHeight + (pointerHeight * 2.1))) )
				AnimatePointerOut(pointer, -0.5, 0.5)
			end
		else
			pointer:SetX(x + (0.5 * targetWidth ))
			label_frame:SetX(x + (1 * (targetWidth + (pointerWidth * 2.1))) )

			if y > (screenHeight / 2) then
				pointer:SetRotation('-135')
				pointer:SetY(y + (-1.5 * targetHeight  ))
				label_frame:SetY(y + (-1 * (targetHeight + (pointerHeight * 2.1))) )
				AnimatePointerOut(pointer, 0.5, -0.5)
			else
				pointer:SetRotation('-45')
				pointer:SetY(y + (0.5 * targetHeight  ))
				label_frame:SetY(y + (1 * (targetHeight + (pointerHeight * 2.1))) )
				AnimatePointerOut(pointer, 0.5, 0.5)
			end
		end

	else
		pointer.onevent = function() end
		pointer:RefreshCallbacks()
		pointer:SetVisible(false)
		label_frame:SetVisible(false)
	end
end

function HoN_Main:PointAtWidget(targetWidget, doPointer, pointerLabel)
	PointAtWidget(targetWidget, doPointer, pointerLabel)
end

local function BlackoutWidget(targetWidget, doBlackout)
	local main_widget_highlighter_bg_1 = GetWidget('main_widget_highlighter_bg_1')
	local main_widget_highlighter_bg_2 = GetWidget('main_widget_highlighter_bg_2')
	local main_widget_highlighter_bg_3 = GetWidget('main_widget_highlighter_bg_3')
	local main_widget_highlighter_bg_4 = GetWidget('main_widget_highlighter_bg_4')
	if (doBlackout) and (targetWidget) then
		local targetX = targetWidget:GetAbsoluteX()
		local targetY = targetWidget:GetAbsoluteY()
		local targetW = targetWidget:GetWidth()
		local targetH = targetWidget:GetHeight()
		main_widget_highlighter_bg_1:SetVisible(true)
		main_widget_highlighter_bg_1:SetX(targetX + targetW + 4)
		main_widget_highlighter_bg_2:SetVisible(true)
		main_widget_highlighter_bg_2:SetX(targetX - main_widget_highlighter_bg_2:GetWidthFromString('100%') - 4)
		main_widget_highlighter_bg_3:SetVisible(true)
		main_widget_highlighter_bg_3:SetWidth(targetW + 8)
		main_widget_highlighter_bg_3:SetX(targetX - 4)
		main_widget_highlighter_bg_3:SetY(targetY + targetH + 4)
		main_widget_highlighter_bg_4:SetVisible(true)
		main_widget_highlighter_bg_4:SetWidth(targetW + 8)
		main_widget_highlighter_bg_4:SetX(targetX - 4)
		main_widget_highlighter_bg_4:SetY(targetY - main_widget_highlighter_bg_4:GetHeightFromString('100%') - 4)
		GetWidget('main_widget_highlighter_close'):SetVisible(true)
	else
		main_widget_highlighter_bg_1:SetVisible(false)
		main_widget_highlighter_bg_2:SetVisible(false)
		main_widget_highlighter_bg_3:SetVisible(false)
		main_widget_highlighter_bg_4:SetVisible(false)
		GetWidget('main_widget_highlighter_close'):SetVisible(false)
	end
end

local function WaitForPurchaseConfirmation()
	GetWidget('main_widget_highlighter_blocker'):SetVisible(true)
	GetWidget('main_widget_highlighter_close'):SetVisible(true)
	if GetWidget('store_button_purchase_success_confirm'):IsVisible() then
		GetWidget('store_button_purchase_success_confirm'):Sleep(500, function() Trigger('DoWalkthrough', 'tutorial1', '6') end)
	else
		GetWidget('store_button_purchase_success_confirm'):SetCallback('onshow', function()
			GetWidget('store_button_purchase_success_confirm'):Sleep(500, function() Trigger('DoWalkthrough', 'tutorial1', '6') end)
			GetWidget('store_button_purchase_success_confirm'):ClearCallback('onshow')
			GetWidget('store_button_purchase_success_confirm'):RefreshCallbacks()
		end)
		GetWidget('store_button_purchase_success_confirm'):RefreshCallbacks()
	end
end

local function GetWalkthrough(walkthroughIndex, stepIndex)

	local function getFemalePyro()
		Main.walkthroughState = 5
		Set('microStore_avatarSelectTarget', 'Hero_Pyromancer.Female', 'string')
		-- removed and changed to just the trigger because the load time was removed from the alt avatar list
		-- local function EntityDefinitionsLoaded()
		-- 	GetWidget('heroAvatarListContainer'):Sleep(500, function() GetWidget('heroAvatarListContainer'):UICmd("Trigger('DoWalkthrough', 'tutorial1', 3)") end) -- Continue tutorial
		-- 	GetWidget('heroAvatarListContainer'):UnregisterWatch('EntityDefinitionsLoaded')
		-- end
		-- GetWidget('heroAvatarListContainer'):RegisterWatch('EntityDefinitionsLoaded', EntityDefinitionsLoaded)
		Trigger('DoWalkthrough', 'tutorial1', '3')
	end

	local function walkthroughState()
		Main.walkthroughState = 6
	end

	if (walkthroughIndex == 'tutorial1') then
		local walkthroughTable = {
			{true, 'midbar_button_store', 					true, false, true, 'ui_main_walkthrough_2', true, true},	-- Step 1: Store button
			{false, getFemalePyro},																						-- Step 4: Scroll up
			{true, 'store_avatar_preview_purchase', 		true, true, true, 'main_walkthrough_2_8', true, true},		-- Step 6: Click Purchase
			{true, 'storeConfirmPurchaseButtonBtnGold', 	true, true, true, 'main_walkthrough_1_9', false, true},			-- Step 7: Click popup purchase
			{false, WaitForPurchaseConfirmation},
			{true, 'store_button_purchase_success_confirm', true, true, true, 'main_walkthrough_1_10', false, true},		-- Step 8: Gratz.
			{false, function() HoN_Main.walkthroughs.step = 0 HoN_Main.walkthroughs.current = "" end}					-- Clear out the displayed widgets and clear out this stuff so the tutorial will keep running																			-- make things disappear
		}
		return walkthroughTable[stepIndex]

	elseif (walkthroughIndex == 'tutorial2') then
		local walkthroughTable = {
			{true, 'midbar_button_compendium', 				true, false, true, 'ui_main_walkthrough_5', true, true},
			{true, 'midbar_button_matchmaking', 			true, false, true, 'ui_main_walkthrough_4', true, true},
			{false, walkthroughState},
		}
		return walkthroughTable[stepIndex]

	else
		return nil
	end
end

function HoN_Main:DoWalkthrough(self, walkthroughIndex, stepIndex)
	--Echo('^rDoing walkthrough ' .. walkthroughIndex .. ' ' .. stepIndex)
	local stepIndex = tonumber(stepIndex)
	if (walkthroughIndex) and NotEmpty(walkthroughIndex) and (stepIndex) and ((HoN_Main.walkthroughs.step + 1) == stepIndex) and ( (HoN_Main.walkthroughs.current == walkthroughIndex) or Empty(HoN_Main.walkthroughs.current) ) then
		local walkthroughTable = GetWalkthrough(walkthroughIndex, stepIndex)
		if (walkthroughTable) then
			HoN_Main.walkthroughs.current = walkthroughIndex
			HoN_Main.walkthroughs.step = stepIndex
			HoN_Main:HighlightWidget(self, '', false, false, false, '')
			Main_Walkthrough.ShowWalkthroughTextPanel(false)
			Main_Walkthrough.PointAtWidget(nil, false)
			if (walkthroughTable[1]) then
				printdb('Widget DoWalkthrough W: ' .. tostring(walkthroughIndex) .. ' | I: ' .. tostring(stepIndex) .. ' | C: ' .. tostring(walkthroughTable[2]) )
				local targetWidget = GetWidget(walkthroughTable[2])
				if (targetWidget) then
					if (not walkthroughTable[7]) then
						GetWidget('main_widget_highlighter_close'):SetVisible(true)
						GetWidget('main_widget_highlighter_blocker'):SetVisible(true)
					elseif (walkthroughTable[8]) then
						GetWidget('main_widget_highlighter_close'):SetVisible(true)
						GetWidget('main_widget_highlighter_blocker'):SetVisible(false)
					end
					targetWidget:Sleep(750, function()
						if (targetWidget:IsVisible()) then
							HoN_Main:HighlightWidget(self, walkthroughTable[2], walkthroughTable[3], walkthroughTable[4], walkthroughTable[5])

							Main_Walkthrough.ShowWalkthroughTextPanel(true, '0%', '65%', true, '', walkthroughTable[6], '', '')
						else
							printdb('Abort due to widget not visible: ' .. tostring(walkthroughTable[2]) )
							interface:UICmd("Trigger('DoWalkthrough', '', '')")
						end
					end)
				else
					printdb('Abort due to widget not existing: ' .. tostring(walkthroughTable[2]) )
				end
			else
				printdb('Special Case DoWalkthrough W: ' .. tostring(walkthroughIndex) .. ' | I: ' .. tostring(stepIndex) )
				walkthroughTable[2]()
			end
		end
	else
		printdb('Abort DoWalkthrough W: ' .. tostring(walkthroughIndex) .. ' | I: ' .. tostring(stepIndex) )
		HoN_Main.walkthroughs.current = ''
		HoN_Main.walkthroughs.step = 0
		HoN_Main:HighlightWidget(self, '', false, false, false, '')
		GetWidget('main_widget_highlighter_blocker'):SetVisible(false)
		--[[
		if (HoN_Main.walkthroughs.targetWidget) then
			HoN_Main.walkthroughs.targetWidget:SetCallback('onclick', function()
				HoN_Main.walkthroughs.targetOnClick()
			end)
			HoN_Main.walkthroughs.targetWidget:SetCallback('onselect', function()
				HoN_Main.walkthroughs.targetOnSelect()
			end)
			HoN_Main.walkthroughs.targetWidget:RefreshCallbacks()
			HoN_Main.walkthroughs.targetWidget = nil
		end
		--]]
	end
end
interface:RegisterWatch('DoWalkthrough', function(...) HoN_Main:DoWalkthrough(...) end)

function HoN_Main:HighlightWidget(self, widgetName, showHighlight, doBlackout, doPointer, pointerLabel)
	GetWidget('main_widget_highlighter_blocker'):SetVisible(false)
	local indicatorWidget = GetWidget('main_widget_highlighter')
	if (showHighlight) then
		if (widgetName) and GetWidget(widgetName) then
			printdb('1 HighlightWidget W: ' .. tostring(self) .. ' | ' .. tostring(widgetName) .. ' | ' .. tostring(showHighlight) .. ' | ' .. tostring(doBlackout) .. ' | ' .. tostring(doBlackout) .. ' | ' .. tostring(pointerLabel) )

			local targetWidget = GetWidget(widgetName)
			indicatorWidget:SetHeight(targetWidget:GetHeight())
			indicatorWidget:SetWidth(targetWidget:GetWidth())
			indicatorWidget:SetX(targetWidget:GetAbsoluteX())
			indicatorWidget:SetY(targetWidget:GetAbsoluteY())
			indicatorWidget:SetVisible(true)
			BlackoutWidget(targetWidget, doBlackout)
			PointAtWidget(targetWidget, doPointer, pointerLabel)

			-- Intercept click of the target, advance tutorial, then restore old function onclick.
			local targetCallback = targetWidget:GetCallback('onclick')
			HoN_Main.walkthroughs.targetOnClick = targetCallback
			targetWidget:SetCallback('onclick', function()
				targetWidget:SetCallback('onclick', function()
					if (targetCallback) then targetCallback() end
				end)
				targetWidget:RefreshCallbacks()
				if (targetCallback) then targetCallback() end
				interface:UICmd("Trigger('DoWalkthrough', '"..HoN_Main.walkthroughs.current.."', "..(HoN_Main.walkthroughs.step + 1)..")")
			end)

			local targetCallback = targetWidget:GetCallback('onselect')
			HoN_Main.walkthroughs.targetOnSelect = targetCallback
			targetWidget:SetCallback('onselect', function()
				targetWidget:SetCallback('onselect', function()
					if (targetCallback) then targetCallback() end
				end)
				targetWidget:RefreshCallbacks()
				if (targetCallback) then targetCallback() end
				interface:UICmd("Trigger('DoWalkthrough', '"..HoN_Main.walkthroughs.current.."', "..(HoN_Main.walkthroughs.step + 1)..")")
			end)

			targetWidget:RefreshCallbacks()
			HoN_Main.walkthroughs.targetWidget = targetWidget
		else
			printdb('^rHighlightWidget widget not found: ' .. tostring(widgetName) )
		end
	else
		--printdb('^oClearing HighlightWidget W: ' .. tostring(self) .. ' | ' .. tostring(widgetName) .. ' | ' .. tostring(showHighlight) .. ' | ' .. tostring(doBlackout) .. ' | ' .. tostring(doBlackout) .. ' | ' .. tostring(pointerLabel) )
		indicatorWidget:SetVisible(false)
		BlackoutWidget(nil, false)
		PointAtWidget(nil, false)
	end
end
interface:RegisterWatch('HighlightWidget', function(...) HoN_Main:HighlightWidget(...) end)

function HoN_Main:UITutorialStep(step)

end

function HoN_Main:UICriticalError(errorText, errorID)
	println('^r critical error: ' .. tostring(errorText) .. ' | id: ' .. tostring(errorID) )
	local bg_main_error_display = GetWidget('bg_main_error_display', 'main', true)
	if (bg_main_error_display) and (not GetWidget('bg_errors_label_template_'..errorID)) then
		GetWidget('sysbar_ui_dev_btn'):SetWidth('12h')
		GetWidget('sysbar_ui_dev_btn'):SetVisible(true)
		GetWidget('sysbar_ui_dev_btn'):UICmd([[SetWatch('')]])
		GetWidget('sysbar_ui_dev_img'):SetTexture('/ui/icons/thumbs_down.tga')
		GetWidget('sysbar_ui_dev_img'):SetColor('white')
		bg_main_error_display:SetVisible(true)
		bg_main_error_display:Instantiate('bg_errors_label_template', 'error', tostring(errorText), 'id', tostring(errorID))
	end
end

function HoN_Main:UICheckForErrors()
	if (not GetCvarBool('ui_avatars_package_loaded')) then
		HoN_Main:UICriticalError('store_avatars.package is malformed', 3)
	end
end

function HoN_Main:MainMenuClickedPlayNow()
	--printdb('UpdatePlayNowButton: ' .. tostring(HonTour and HonTour.isMatchScheduled) .. ' | ' .. tostring(IsInScheduledMatch()) )
	if (HonTour) and ((HonTour.isMatchScheduled) or (IsInScheduledMatch())) and (not (IsInGroup() or IsInQueue()) ) then
		if (not IsInScheduledMatch()) and (not GetWidget('hontour'):IsVisible()) then
			HonTour.PromptToJoinLobby()
			--println('PromptToJoinLobby')
		else
			--println('Just show the UI')
			UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'hontour', nil, nil, nil, nil, 707)
		end
	else
		UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'matchmaking', nil, nil, nil, nil, 702)
	end
end

function HoN_Main:EmailInactiveAccount(ui_lastSelectedUser)
	--println('EmailInactiveAccount = ' .. tostring(ui_lastSelectedUser) )
	-- this form will probably need tweaking, inactive_account.package too
	if NotEmpty(GetCvarString('ui_lastSelectedUser')) then
		local _, email = HoN_Region:GetEmailInactiveRegionInfo()
		if (email) then
			groupfcall('main_splash_ref_2_do_it_btn_label', function(_, widget, _) widget:SetText(Translate('ref_string_' .. GetCvarString('ui_raf_region_string').. '_2_7', 'name', GetCvarString('ui_lastSelectedUser'))) end)
		else
			groupfcall('main_splash_ref_2_do_it_btn_label', function(_, widget, _) widget:SetText(Translate('ref_string_referrals')) end)
		end

		ResourceManager.LoadContext('referral_popup_2')
		GetWidget('main_splash_referral_popup_2'):FadeIn(150)

	end
end

function HoN_Main:DoEmailInactiveAccount(ui_lastSelectedUser)
	if NotEmpty(GetCvarString('ui_lastSelectedUser')) then
		local _, email = HoN_Region:GetEmailInactiveRegionInfo()
		if (email) then
			interface:UICmd("SubmitForm('invite_player_back', 'emailNick', ui_lastSelectedUser, 'cookie', GetCookie(), 'template_id', '1'); Trigger('social_panel_inactive_invited', '"..ui_lastSelectedUser.."');")

			GetWidget('main_splash_referral_popup_2'):FadeOut(250)

			Trigger("TriggerDialogBoxWebRequest",
				Translate("inactive_header", "username", ui_lastSelectedUser),
				"inactive_left_button",
				"general_cancel",
				"SubmitForm('invite_player_back', 'emailNick', ui_lastSelectedUser, 'cookie', GetCookie(), 'template_id', '1'); Trigger('social_panel_inactive_invited', '"..ui_lastSelectedUser.."');",
				"",
				"inactive_title",
				"inactive_desc",
				"InviteBackStatus",
				"InviteBackResult",
				"",
				"inactive_success_title",
				"inactive_success_body"
			)
		else
			GetWidget('main_splash_referral_popup_2'):FadeOut(250)
			-- open options to referrals
			OpenOptions(7, 1, false)
		end
	end
end

function HoN_Main:PublicGamesClicked()
	if (not IsInGroup()) then
		HoN_Main:MainMenuPanelToggle('game_list', nil, false)
	else
		Trigger('TriggerDialogBox',
			'main_leavegroup',
			'general_back', 'general_continue',
			'', 'LeaveTMMGroup(); Set(\'_mainmenu_currentpanel\', \'game_list\'); CallEvent(\'MainMenuPanelSwitcher\');',
			'', 'main_leavegroup_body')
	end
end

function HoN_Main:ListModdedFiles()
	local moddedFiles = ListModdedFiles()
	local buffer = GetWidget('main_modded_files_buffer')

	buffer:ClearBufferText()
	for i,file in ipairs(moddedFiles) do
		buffer:AddBufferText(file)
	end

	GetWidget('main_modded_files_list'):FadeIn(250)
end

function interface:HoNMainF(func, ...)
	if (HoN_Main[func]) then
		print(HoN_Main[func](self, ...))
	else
		print('HoNMainF failed to find: ' .. tostring(func) .. '\n')
	end
end

function HoN_Main:SelectChat()
	-- don't reselect
	if (HoN_Main.selectedTab == 'chat') then
		return
	end

	questsRewardsScrollDragEnd()

	HoN_Main.selectedTab = 'chat'

	GetWidget('quest_tab'):DoEventN(0)
	GetWidget('quest_tab_label'):DoEventN(0)
	GetWidget('quest_tab'):SetCallback('onmouseout', function(self)
		self:DoEventN(0)
		Trigger('genericMainFloatingTip', 'false', '', '', '', '', '', '', '', '')
	end)

	GetWidget('chat_tab'):DoEventN(1)
	GetWidget('chat_tab_label'):DoEventN(1)
	GetWidget('chat_tab'):SetCallback('onmouseout', function(self)
		self:DoEventN(1)
		Trigger('genericMainFloatingTip', 'false', '', '', '', '', '', '', '', '')
	end)

	GetWidget('communicator_container'):FadeIn(150)
	GetWidget('quests_container'):FadeOut(150)
end

function HoN_Main:SelectQuests()
	-- don't reselect
	if (HoN_Main.selectedTab == 'quests') then
		return
	end

	HoN_Main.selectedTab = 'quests'

	GetWidget('quest_tab'):DoEventN(1)
	GetWidget('quest_tab_label'):DoEventN(1)
	GetWidget('quest_tab'):SetCallback('onmouseout', function(self)
		self:DoEventN(1)
		Trigger('genericMainFloatingTip', 'false', '', '', '', '', '', '', '', '')
	end)

	GetWidget('chat_tab'):DoEventN(0)
	GetWidget('chat_tab_label'):DoEventN(0)
	GetWidget('chat_tab'):SetCallback('onmouseout', function(self)
		self:DoEventN(0)
		Trigger('genericMainFloatingTip', 'false', '', '', '', '', '', '', '', '')
	end)

	GetWidget('communicator_container'):FadeOut(150)
	GetWidget('quests_container'):FadeIn(150)
end

function scanChildrenForFocus(widget)
	if widget and widget:IsValid() then
		for k,v in ipairs(widget:GetChildren()) do
			if v:HasFocus() then
				print('Found widget named '..(v:GetName() or '')..' with focus.  w: '..v:GetWidth()..' | h: '..v:GetHeight()..' | x: '..v:GetAbsoluteX()..' | y: '..v:GetAbsoluteY()..'\n')
				v:SetColor(1,0,0)
				return
			else
				scanChildrenForFocus(v)
			end
		end
	else
		print('not valid widget\n')
	end
end


function findFocusedWidget(fromInterface)
	local useInterface = nil
	if fromInterface and type(fromInterface) == 'string' and string.len(fromInterface) then
		useInterface = UIManager.GetInterface(fromInterface)
		print('using named interface\n')
	else
		useInterface = UIManager.GetActiveInterface()
		print('using active interface\n')
	end

	scanChildrenForFocus(useInterface)
end

interface:RegisterWatch('WebpageUIRequest', function(widget, action, param0, param1)
	Echo('WebpageUIRequest action: ' .. action .. ' param0: ' .. param0 .. ' param1: ' .. param1)
	if action == 'store_category' then
		if param0 and tonumber(param0) then
			OpenStoreToCategory(tonumber(param0), true)
		end
	elseif action == 'store_avatar_search' then
		if param0 and string.len(param0) > 0 then
			OpenStore2ToAltAndSearch(param0)
		end
	elseif action == 'store_specials' then
		OpenStoreToSpecials()
	elseif action == 'plinko' then
		UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'plinko', nil, false)
	elseif action == 'buy_coins' then
		OpenStoreToBuyCoins(true)
		interface:Sleep(1000, function() 
			OpenStoreToBuyCoins(true)
		end)
	elseif action == 'player_tour' then
		Player_Tour.Open(param0, param1)
	elseif action == 'player_motd' then
		if (NotEmpty(param0)) then
			UIManager.GetInterface('webpanel'):HoNWebPanelF('ShowMOTD', GetWidget('web_browser_motd_insert'), param0)
			UIManager.GetInterface('main'):HoNMainF('MainMenuPanelToggle', 'player_motd', nil, false)
		end
	end
end)
