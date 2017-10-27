--[[
	Author:			Mimma
	Create Date:	5/10/2015 5:50:57 PM
	
- write when you are ressing a target another healer is also ressing (maybe with name?)

-- UI to display corpses / deaths - prioritised (a little like decursive)	
	
]]


local PARTY_CHANNEL = "PARTY"
local RAID_CHANNEL  = "RAID"
local YELL_CHANNEL  = "YELL"
local SAY_CHANNEL   = "SAY"
local WARN_CHANNEL  = "RAID_WARNING"
local GUILD_CHANNEL = "GUILD"
local CHAT_END      = "|r"
local COLOUR_CHAT   = "|c8040A0F8"
local COLOUR_INTRO  = "|c80B040F0"
local THALIZ_PREFIX = "Thalizv1"
local CTRA_PREFIX   = "CTRA"
local THALIZ_MAX_MESSAGES = 200
local THALIZ_MAX_VISIBLE_MESSAGES = 20
local THALIZ_EMPTY_MESSAGE = "(Empty)"

local THALIZ_CURRENT_VERSION = 0
local THALIZ_UPDATE_MESSAGE_SHOWN = false

--	List of valid class names with priority and resurrection spell name (if any)
local classInfo = {
	{ "Druid",   40, "Rebirth" },
	{ "Hunter",  30, nil },
	{ "Mage",    40, nil },
	{ "Paladin", 50, "Redemption" },
	{ "Priest",  50, "Resurrection" },
	{ "Rogue",   10, nil },
	{ "Shaman",  50, "Ancestral Spirit" },
	{ "Warlock", 30, nil },
	{ "Warrior", 20, nil }
}

local PriorityToFirstWarlock  = 45;     -- Prio below ressers if no warlocks are alive
local PriorityToGroupLeader   = 45;     -- Prio below ressers if raid leader or assistant
local PriorityToCurrentTarget = 100;	-- Prio over all if target is selected

-- List of blacklisted (already ressed) people
local blacklistedTable = {}
-- Corpses are blacklisted for 25 seconds (10 seconds cast time + 15 seconds waiting) as default
local Thaliz_Blacklist_Timeout = 25;

local Thaliz_Enabled = true;

-- Configuration constants:
local Thaliz_Configuration_Default_Level = "Character";	-- Can be "Character" or "Realm"
local Thaliz_Target_Channel_Default = "RAID";
local Thaliz_Target_Whisper_Default = "0";

local Thaliz_ConfigurationLevel = Thaliz_Configuration_Default_Level;

local Thaliz_ROOT_OPTION_CharacterBasedSettings = "CharacterBasedSettings";
local Thaliz_OPTION_ResurrectionMessageTargetChannel = "ResurrectionMessageTargetChannel";
local Thaliz_OPTION_ResurrectionMessageTargetWhisper = "ResurrectionMessageTargetWhisper";
local Thaliz_OPTION_ResurrectionMessages = "ResurrectionMessages";


-- Persisted information:
Thaliz_Options = {}


-- List of resurrection messages
local Thaliz_DefaultResurrectionMessages = {
	"(Ressing) Stop slacking and get up, %s!",
	"(Ressing) How many \'Z\'s are in Vaelastrasz, %s?",
	"(Ressing) Did you just do the unsafety dance, %s?",
	"(Ressing) I\'m keeping my eye on you, %s!",
	"(Ressing) Too soon, %s - you have died too soon!",
	"(Ressing) Cower, %s! The age of darkness is at hand!",
	"(Ressing) %s! Death! Destruction!",
	"(Ressing) No more play, %s?",
	"(Ressing) Forgive me %s, your death only adds to my failure.",
	"(Ressing) Your friends will abandon you, %s!",
	"(Ressing) Slay %s in the masters name!",
	"(Ressing) %s, Chuck Norris would have survived that!",
	"(Ressing) %s, seems you ran out of health!",
	"(Ressing) %s, you make the floor look dirty!",
	"(Ressing) %s, there\'s loot waiting for you!",
	"(Ressing) %s, you are too late... I... must... OBEY!",
	"(Ressing) Shhh, %s... it will all be over soon.",
	"(Ressing) %s! Cease this foolish venture at once!",
	"(Ressing) Death is the only escape, %s.",
	"(Ressing) The time for practice is over, %s!",
}



--[[
	Echo a message for the local user only.
]]
local function echo(msg)
	if not msg then
		msg = ""
	end
	DEFAULT_CHAT_FRAME:AddMessage(COLOUR_CHAT .. msg .. CHAT_END)
end

--[[
	Echo in raid chat (if in raid) or party chat (if not)
]]
local function partyEcho(msg)
	if Thaliz_IsInRaid() then
		SendChatMessage(msg, RAID_CHANNEL)
	elseif Thaliz_IsInParty() then
		SendChatMessage(msg, PARTY_CHANNEL)
	end
end

--[[
	Echo a message for the local user only, including Thaliz "logo"
]]
function Thaliz_Echo(msg)
	echo("<"..COLOUR_INTRO.."THALIZ"..COLOUR_CHAT.."> "..msg);
end





--  *******************************************************
--
--	Slash commands
--
--  *******************************************************

--[[
	Main entry for Thaliz.
	This will send the request to one of the sub slash commands.
	Syntax: /thaliz [option, defaulting to "res"]
	Added in: 0.0.1
]]
SLASH_THALIZ_THALIZ1 = "/thaliz"
SlashCmdList["THALIZ_THALIZ"] = function(msg)
	local _, _, option = string.find(msg, "(%S*)")

	if not option or option == "" then
		option = "RES"
	end
	option = string.upper(option);
		
	if (option == "RES" or option == "RESURRECT") then
		SlashCmdList["THALIZ_RES"]();
	elseif (option == "CFG" or option == "CONFIG") then
		SlashCmdList["THALIZ_CONFIG"]();
	elseif option == "DISABLE" then
		SlashCmdList["THALIZ_DISABLE"]();
	elseif option == "ENABLE" then
		SlashCmdList["THALIZ_ENABLE"]();
	elseif option == "HELP" then
		SlashCmdList["THALIZ_HELP"]();
	elseif option == "VERSION" then
		SlashCmdList["THALIZ_VERSION"]();
	else
		Thaliz_Echo(string.format("Unknown command: %s", option));
	end
end

--[[
	Resurrect highest priority target.
	Syntax: /thalizres
	Alternative: /thaliz res
	Added in: 0.3.0
]]
SLASH_THALIZ_RES1 = "/thalizres"
SlashCmdList["THALIZ_RES"] = function(msg)
	Thaliz_StartResurrectionOnPriorityTarget();
end


--[[
	Request client version information
	Syntax: /thalizversion
	Alternative: /thaliz version
	Added in: 0.2.1
]]
SLASH_THALIZ_VERSION1 = "/thalizversion"
SlashCmdList["THALIZ_VERSION"] = function(msg)
	if Thaliz_IsInRaid() or Thaliz_IsInParty() then
		Thaliz_SendAddonMessage("TX_VERSION##");
	else
		Thaliz_Echo(string.format("%s is using Thaliz version %s", UnitName("player"), GetAddOnMetadata("Thaliz", "Version")));
	end
end

--[[
	Show configuration options
	Syntax: /thalizconfig
	Alternative: /thaliz config
	Added in: 0.3.0
]]
SLASH_THALIZ_CONFIG1 = "/thalizconfig"
SLASH_THALIZ_CONFIG2 = "/thalizcfg"
SlashCmdList["THALIZ_CONFIG"] = function(msg)
	Thaliz_OpenConfigurationDialogue();
end

--[[
	Disable Thaliz' messages
	Syntax: /thaliz disable
	Added in: 0.3.2
]]
SLASH_THALIZ_DISABLE1 = "/thalizdisable"
SlashCmdList["THALIZ_DISABLE"] = function(msg)
	Thaliz_Enabled = false;
	Thaliz_Echo("Resurrection announcements has been disabled.");
end

--[[
	Enable Thaliz' messages
	Syntax: /thaliz enable
	Added in: 0.3.2
]]
SLASH_THALIZ_ENABLE1 = "/thalizenable"
SlashCmdList["THALIZ_ENABLE"] = function(msg)
	Thaliz_Enabled = true;
	Thaliz_Echo("Resurrection announcements has been enabled.");
end

--[[
	Show HELP options
	Syntax: /thalizhelp
	Alternative: /thaliz help
	Added in: 0.2.0
]]
SLASH_THALIZ_HELP1 = "/thalizhelp"
SlashCmdList["THALIZ_HELP"] = function(msg)
	Thaliz_Echo(string.format("Thaliz version %s options:", GetAddOnMetadata("Thaliz", "Version")));
	Thaliz_Echo("Syntax:");
	Thaliz_Echo("    /thaliz [option]");
	Thaliz_Echo("Where options can be:");
	Thaliz_Echo("    Res          (default) Resurrect next target.");
	Thaliz_Echo("    Config       Open the configuration dialogue,");
	Thaliz_Echo("    Disable      Disable Thaliz resurrection messages.");
	Thaliz_Echo("    Enable       Enable Thaliz resurrection messages again.");
	Thaliz_Echo("    Help         This help.");
	Thaliz_Echo("    Version      Request version info from all clients.");
end




--  *******************************************************
--
--	Configuration functions
--
--  *******************************************************
function Thaliz_OpenConfigurationDialogue()
	--Thaliz_RefreshVisibleMessageList(1);
	
	ThalizFrame:Show();
end

function Thaliz_RefreshVisibleMessageList(offset)
	local resMsgs = Thaliz_GetResurrectionMessages();
	for n=1, THALIZ_MAX_VISIBLE_MESSAGES, 1 do
		local msg = resMsgs[n + offset];
		local frame = getglobal("ThalizFrameTableListEntry"..n);
		if not msg or msg == "" then
			msg = THALIZ_EMPTY_MESSAGE;
		end
		getglobal(frame:GetName().."Message"):SetText(msg);
		frame:Show();
	end
end



function Thaliz_UpdateMessageList(frame)
	FauxScrollFrame_Update(ThalizFrameTableList, THALIZ_MAX_MESSAGES, 10, 20);
	local offset = FauxScrollFrame_GetOffset(ThalizFrameTableList);
	
	Thaliz_RefreshVisibleMessageList(offset);
end

function Thaliz_InitializeListElements()
	local entry = CreateFrame("Button", "$parentEntry1", ThalizFrameTableList, "Thaliz_CellTemplate");
	entry:SetID(1);
	entry:SetPoint("TOPLEFT", 4, -4);
	for n=2, THALIZ_MAX_MESSAGES, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, ThalizFrameTableList, "Thaliz_CellTemplate");
		entry:SetID(n);
		entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
	end
end

function Thaliz_OnMessageClick(object)
	local msgID = object:GetID();
	local offset = FauxScrollFrame_GetOffset(ThalizFrameTableList);
		
	local message = getglobal(object:GetName().."Message"):GetText();
	if not message or message == THALIZ_EMPTY_MESSAGE then
		message = "";
	end
		
	StaticPopupDialogs["MessageEditor"] = {
		text = "Update Resurrection message:",
		hasEditBox = true,
		hasWideEditBox = true,
		hideOnEscape = true,
		whileDead = true,
		button1 = "Okay",
		button2 = "Cancel",
		timeout = 0,
		maxLetters = 128,
		EditBoxOnEnterPressed = function()
			this:GetParent():Hide();
			Thaliz_UpdateResurrectionMessage(msgID, offset, this:GetText());
		end,
		OnShow = function()	
			local c = getglobal(this:GetName().."WideEditBox");
			c:SetText(message);
			this:SetWidth(410);
		end,
		OnAccept = function(self, data)
			local c = getglobal(this:GetParent():GetName().."WideEditBox");			
			Thaliz_UpdateResurrectionMessage(msgID, offset, c:GetText());
		end
	}
		
	StaticPopup_Show("MessageEditor");	
end


function Thaliz_HandleCheckbox(checkbox)
	local checkboxname = checkbox:GetName();
	
	--	If checked, then we need to uncheck others in same group:
	if checkboxname == "ThalizFrameCheckbuttonRaid" or checkboxname == "ThalizFrameCheckbuttonYell" or checkboxname == "ThalizFrameCheckbuttonSay" then	
		if checkbox:GetChecked() then
			if checkboxname == "ThalizFrameCheckbuttonRaid" then
				Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel, "RAID");
				getglobal("ThalizFrameCheckbuttonSay"):SetChecked(0);
				getglobal("ThalizFrameCheckbuttonYell"):SetChecked(0);
			elseif checkboxname == "ThalizFrameCheckbuttonYell" then
				Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel, "YELL");
				getglobal("ThalizFrameCheckbuttonSay"):SetChecked(0);
				getglobal("ThalizFrameCheckbuttonRaid"):SetChecked(0);
			elseif checkboxname == "ThalizFrameCheckbuttonSay" then
				Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel, "SAY");
				getglobal("ThalizFrameCheckbuttonRaid"):SetChecked(0);
				getglobal("ThalizFrameCheckbuttonYell"):SetChecked(0);
			end
		else
			Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel, "NONE");
			getglobal("ThalizFrameCheckbuttonRaid"):SetChecked(0);
			getglobal("ThalizFrameCheckbuttonSay"):SetChecked(0);
			getglobal("ThalizFrameCheckbuttonYell"):SetChecked(0);
		end
	end

	if getglobal("ThalizFrameCheckbuttonWhisper"):GetChecked() then
		Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetWhisper, 1);
	else
		Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetWhisper, 0);
	end	
	
	if getglobal("ThalizFrameCheckbuttonPerCharacter"):GetChecked() then
		Thaliz_SetRootOption(Thaliz_ROOT_OPTION_CharacterBasedSettings, "Character");
	else
		Thaliz_SetRootOption(Thaliz_ROOT_OPTION_CharacterBasedSettings, "Realm");
	end	
	
end


function Thaliz_GetRootOption(parameter, defaultValue)
	if Thaliz_Options then
		if Thaliz_Options[parameter] then
			local value = Thaliz_Options[parameter];
			if (type(value) == "table") or not(value == "") then
				return value;
			end
		end		
	end
	
	return defaultValue;
end

function Thaliz_SetRootOption(parameter, value)
	if not Thaliz_Options then
		Thaliz_Options = {};
	end
	
	Thaliz_Options[parameter] = value;
end

function Thaliz_GetOption(parameter, defaultValue)
	local realmname = GetRealmName();
	local playername = UnitName("player");

	if Thaliz_ConfigurationLevel == "Character" then
		-- Character level
		if Thaliz_Options[realmname] then
			if Thaliz_Options[realmname][playername] then
				if Thaliz_Options[realmname][playername][parameter] then
					local value = Thaliz_Options[realmname][playername][parameter];
					if (type(value) == "table") or not(value == "") then
						return value;
					end
				end		
			end
		end
	else
		-- Realm level:
		if Thaliz_Options[realmname] then
			if Thaliz_Options[realmname][parameter] then
				local value = Thaliz_Options[realmname][parameter];
				if (type(value) == "table") or not(value == "") then
					return value;
				end
			end		
		end
	end
	
	return defaultValue;
end

function Thaliz_SetOption(parameter, value)
	local realmname = GetRealmName();
	local playername = UnitName("player");

	if Thaliz_ConfigurationLevel == "Character" then
		-- Character level:
		if not Thaliz_Options[realmname] then
			Thaliz_Options[realmname] = {};
		end
		
		if not Thaliz_Options[realmname][playername] then
			Thaliz_Options[realmname][playername] = {};
		end
		
		Thaliz_Options[realmname][playername][parameter] = value;
		
	else
		-- Realm level:
		if not Thaliz_Options[realmname] then
			Thaliz_Options[realmname] = {};
		end	
		
		Thaliz_Options[realmname][parameter] = value;
	end
end


function Thaliz_InitializeConfigSettings()

	if not Thaliz_Options then
		Thaliz_options = { };
	end

	Thaliz_SetRootOption(Thaliz_ROOT_OPTION_CharacterBasedSettings, Thaliz_GetRootOption(Thaliz_ROOT_OPTION_CharacterBasedSettings, Thaliz_Configuration_Default_Level))
	Thaliz_ConfigurationLevel = Thaliz_GetRootOption(Thaliz_ROOT_OPTION_CharacterBasedSettings, Thaliz_Configuration_Default_Level);
	
	Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel, Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel, Thaliz_Target_Channel_Default))
	Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessageTargetWhisper, Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetWhisper, Thaliz_Target_Whisper_Default))

	if Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel) == "RAID" then
		getglobal("ThalizFrameCheckbuttonRaid"):SetChecked(1)
	end
	if Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel) == "SAY" then
		getglobal("ThalizFrameCheckbuttonSay"):SetChecked(1)
	end
	if Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel) == "YELL" then
		getglobal("ThalizFrameCheckbuttonYell"):SetChecked(1)
	end
	if Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetWhisper) == 1 then
		getglobal("ThalizFrameCheckbuttonWhisper"):SetChecked(1)
	end
	if Thaliz_GetRootOption(Thaliz_ROOT_OPTION_CharacterBasedSettings) == "Character" then
		getglobal("ThalizFrameCheckbuttonPerCharacter"):SetChecked(1)
	end    
	
end


--  *******************************************************
--
--	Resurrect message functions
--
--  *******************************************************
function Thaliz_AnnounceResurrection(playername)
	if not Thaliz_Enabled then
		return;
	end

	--echo("Announcing resurrection on "..playername);
	local validMessages = {}
	local validCount = 0;
	local resMsgs = Thaliz_GetResurrectionMessages();
	for n=1, table.getn( resMsgs ), 1 do
		local msg = resMsgs[n];
		if msg and not (msg == "") then
			validCount = validCount + 1;
			validMessages[ validCount ] = msg;
		end
	end
	
	-- Fallback message if none are configured
	if validCount == 0 then
		validMessages[1] = "Resurrecting %s";
		validCount = 1;
	end
	
	local message = string.format( validMessages[ random(validCount) ], playername );
	
	if Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel) == "RAID" then
		partyEcho(message);
	elseif Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel) == "SAY" then
		SendChatMessage(message, SAY_CHANNEL)
	elseif Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetChannel) == "YELL" then
		SendChatMessage(message, YELL_CHANNEL)
	end
	
	if Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessageTargetWhisper) == 1 then
		SendChatMessage("Resurrection incoming in 10 seconds!", "WHISPER", nil, playername);
	end
end

function Thaliz_GetResurrectionMessages()
	local messages = Thaliz_GetOption(Thaliz_OPTION_ResurrectionMessages, nil);
	
	if (not messages) or not(type(messages) == "table") or (table.getn(messages) == 0) then
		messages = Thaliz_ResetResurrectionMessages(); 
	end
	
	return messages;
end

function Thaliz_RenumberTable(sourcetable)
	local index = 1;
	local temptable = { };
	
	for key, value in next, sourcetable do
		temptable[index] = value;
		index = index + 1
	end
	return temptable;
end

function Thaliz_SetResurrectionMessages(resurrectionMessages)
	Thaliz_SetOption(Thaliz_OPTION_ResurrectionMessages, Thaliz_RenumberTable(resurrectionMessages));
end

function Thaliz_ResetResurrectionMessages()
	Thaliz_SetResurrectionMessages( Thaliz_DefaultResurrectionMessages );
	
	return Thaliz_DefaultResurrectionMessages;
end

function Thaliz_AddResurrectionMessage(message)
	if message and not (message == "") then
		--echo("Adding resurrection message: "..message);
		local resMsgs = Thaliz_GetResurrectionMessages();		
		resMsgs[ table.getn(resMsgs) + 1] = message;
		
		Thaliz_SetResurrectionMessages(resMsgs);
	end
end



function Thaliz_UpdateResurrectionMessage(index, offset, message)
	--echo(string.format("Updating message, Index=%d, offset=%d, msg=%s", index, offset, message));

	local messages = Thaliz_GetResurrectionMessages();
	messages[index + offset] = message;
	Thaliz_SetResurrectionMessages( messages );

	--	Update the frame UI:
	local frame = getglobal("ThalizFrameTableListEntry"..index);
	if not message or message == "" then
		message = THALIZ_EMPTY_MESSAGE;
	end
	getglobal(frame:GetName().."Message"):SetText(message);
end



--  *******************************************************
--
--	Ressing functions
--
--  *******************************************************

--[[
	Scan the party / raid for dead people, and prioritize those.
	Ignore blacklisted people.
	Only do this if the current player is a resser!
]]
function Thaliz_StartResurrectionOnPriorityTarget()
	-- Check by spell: no need to update death list if player cannot resurrect!
	local classinfo = Thaliz_GetClassinfo(UnitClass("player"));
	local spellname = classinfo[3];
	if not spellname then
		return;
	end
		
	local groupsize, grouptype;
	if Thaliz_IsInRaid() then
		groupsize = GetNumRaidMembers();
		grouptype = "raid";	
	elseif Thaliz_IsInParty() then
		groupsize = GetNumPartyMembers();
		grouptype = "party";
	else
		Thaliz_Echo("You are not in a group!");
		return;
	end
	
	local warlocksAlive = false;
	for n=1, groupsize, 1 do
		unitid = grouptype..n
		if not UnitIsDead(unitid) and UnitIsConnected(unitid) and UnitIsVisible(unitid) and UnitClass(unitid) == "Warlock" then
			warlocksAlive = true;
			break;
		end
	end
	
	Thaliz_CleanupBlacklistedPlayers();

	local targetprio;
	local targetname;
		
	local corpseTable = {};
	local playername, unitid, classinfo;
	for n=1, groupsize, 1 do
		unitid = grouptype..n
		playername = UnitName(unitid)
		
		local isBlacklisted = false;
		for b=1, table.getn(blacklistedTable), 1 do
			blacklistInfo = blacklistedTable[b];
			blacklistTick = blacklistInfo[2];					
			if blacklistInfo[1] == playername then
				isBlacklisted = true;
				break;
			end
		end
		
		targetname = UnitName("playertarget");
		if not isBlacklisted and UnitIsDead(unitid) and UnitIsConnected(unitid) and UnitIsVisible(unitid) then
			classinfo = Thaliz_GetClassinfo(UnitClass(unitid));
			targetprio = classinfo[2];
			if targetname and targetname == playername then
				targetprio = PriorityToCurrentTarget;
			end
			if IsRaidLeader(playername) and targetprio < PriorityToGroupLeader then
				targetprio = PriorityToGroupLeader;
			end
			if not warlocksAlive and classinfo[1] == "Warlock" then
				targetprio = PriorityToFirstWarlock;				
			end
			
			-- Add a random decimal factor to priority to spread ressings out.
			-- Random is a float between 0 and 1:
			targetprio = targetprio + random();		
			--echo(string.format("%s added, priority=%f", playername, targetprio));			
			corpseTable[ table.getn(corpseTable) + 1 ] = { unitid, targetprio } ;
		end
	end	

	if (table.getn(corpseTable) == 0) then
		if (table.getn(blacklistedTable) == 0) then
			Thaliz_Echo("There is no one to resurrect.");
		else
			Thaliz_Echo("All targets have received a res.");
		end
		return;
	end

	-- Sort the corpses with highest priority in top:
	Thaliz_SortTableDescending(corpseTable, 2);

	-- Start casting the spell:	
	CastSpellByName(spellname);
	local unitid = Thaliz_ChooseCorpse(corpseTable);	
	if unitid then
		playername = UnitName(unitid)
		
		SpellTargetUnit(unitid);
		if not SpellIsTargeting() then
			Thaliz_BlacklistPlayer(playername);
			Thaliz_AnnounceResurrection(playername);
			Thaliz_SendAddonMessage("TX_RESBEGIN#"..playername.."#");
		else
			SpellStopTargeting();
		end
	else
		SpellStopTargeting();
		--Not in range. UI already write that, we dont need to also!
	end
end

function Thaliz_ChooseCorpse(corpseTable)
	for key, val in corpseTable do
		if SpellCanTargetUnit(val[1]) then
			return val[1];
		end
	end
	return nil;
end

function Thaliz_GetClassinfo(classname)
	for key, val in classInfo do
		if val[1] == classname then
			return val;
		end
	end
	return nil;
end



--  *******************************************************
--
--	Blacklisting functions
--
--  *******************************************************
function Thaliz_BlacklistPlayer(playername)
	if not Thaliz_IsPlayerBlacklisted(playername) then
		--echo("Blacklisting "..playername);
		blacklistedTable[ table.getn(blacklistedTable) + 1 ] = { playername, Thaliz_GetTimerTick() + Thaliz_Blacklist_Timeout };
	end
end

--[[
	Remove player from Blacklist (if any)
]]
function Thaliz_WhitelistPlayer(playername)
	local WhitelistTable = {}
	--echo("Whitelisting "..playername);

	for n=1, table.getn(blacklistedTable), 1 do
		blacklistInfo = blacklistedTable[n];
		if not (playername == blacklistInfo[1]) then
			WhitelistTable[ table.getn(WhitelistTable) + 1 ] = blacklistInfo;
		end
	end
	blacklistedTable = WhitelistTable;
end


function Thaliz_IsPlayerBlacklisted(playername)
	Thaliz_CleanupBlacklistedPlayers();

	for n=1, table.getn(blacklistedTable), 1 do		 
		if blacklistedTable[n][1] == playername then
			return true;
		end
	end
	return false;
end


function Thaliz_CleanupBlacklistedPlayers()
	local BlacklistedTableNew = {}
	local blacklistInfo;	
	local timerTick = Thaliz_GetTimerTick();
	
	for n=1, table.getn(blacklistedTable), 1 do
		blacklistInfo = blacklistedTable[n];
		if timerTick < blacklistInfo[2] then
			BlacklistedTableNew[ table.getn(BlacklistedTableNew) + 1 ] = blacklistInfo;
		end
	end
	blacklistedTable = BlacklistedTableNew;
end



--  *******************************************************
--
--	Helper functions
--
--  *******************************************************
function Thaliz_IsInParty()
	if not Thaliz_IsInRaid() then
		return ( GetNumPartyMembers() > 0 );
	end
	return false
end


function Thaliz_IsInRaid()
	return ( GetNumRaidMembers() > 0 );
end


function Thaliz_SortTableDescending(sourcetable, index)
	local doSort = true
	while doSort do
		doSort = false
		for n=1,table.getn(sourcetable) - 1,1 do
			local a = sourcetable[n]
			local b = sourcetable[n + 1]
			if tonumber(a[index]) and tonumber(b[index]) and tonumber(a[index]) < tonumber(b[index]) then
				sourcetable[n] = b
				sourcetable[n + 1] = a
				doSort = true
			end
		end
	end
end



--  *******************************************************
--
--	Version functions
--
--  *******************************************************

--[[
	Broadcast my version if this is not a beta (CurrentVersion > 0) and
	my version has not been identified as being too low (MessageShown = false)
]]
function Thaliz_OnRaidRosterUpdate(event, arg1, arg2, arg3, arg4, arg5)
	if THALIZ_CURRENT_VERSION > 0 and not THALIZ_UPDATE_MESSAGE_SHOWN then
		if Thaliz_IsInRaid() or Thaliz_IsInParty() then
			local versionstring = GetAddOnMetadata("Thaliz", "Version");
			Thaliz_SendAddonMessage(string.format("TX_VERCHECK#%s#", versionstring));
		end
	end
end

function Thaliz_CalculateVersion(versionString)
	local _, _, major, minor, patch = string.find(versionString, "([^\.]*)\.([^\.]*)\.([^\.]*)");
	local version = 0;

	if (tonumber(major) and tonumber(minor) and tonumber(patch)) then
		version = major * 100 + minor;
		--echo(string.format("major=%s, minor=%s, patch=%s, version=%d", major, minor, patch, version));
	end
	
	return version;
end

function Thalix_CheckIsNewVersion(versionstring)
	local incomingVersion = Thaliz_CalculateVersion( versionstring );

	if (THALIZ_CURRENT_VERSION > 0 and incomingVersion > 0) then
		if incomingVersion > THALIZ_CURRENT_VERSION then
			if not THALIZ_UPDATE_MESSAGE_SHOWN then
				THALIZ_UPDATE_MESSAGE_SHOWN = true;
				Thaliz_Echo(string.format("NOTE: A newer version of ".. COLOUR_INTRO .."THALIZ"..COLOUR_CHAT.."! is available (version %s)!", versionstring));
				Thaliz_Echo("NOTE: Go to http://armory.digam.dk to download latest version.");
			end
		end	
	end
end


--  *******************************************************
--
--	Timer functions
--
--  *******************************************************
local Timers = {}
local TimerTick = 0

function Thaliz_OnTimer(elapsed)
	TimerTick = TimerTick + elapsed

	for n=1,table.getn(Timers),1 do
		local timer = Timers[n]
		if TimerTick > timer[2] then
			Timers[n] = nil
			timer[1]()
		end
	end
end

function Thaliz_GetTimerTick()
	return TimerTick;
end





--  *******************************************************
--
--	Internal Communication Functions
--
--  *******************************************************

function Thaliz_SendAddonMessage(message)
	local channel = nil
	
	if Thaliz_IsInRaid() then
		channel = "RAID";
	elseif Thaliz_IsInParty() then
		channel = "PARTY";
	else
		return;
	end

	SendAddonMessage(THALIZ_PREFIX, message, channel);
end



--[[
	Respond to a TX_VERSION command.
	Input:
		msg is the raw message
		sender is the name of the message sender.
	We should whisper this guy back with our current version number.
	We therefore generate a response back (RX) in raid with the syntax:
	Thaliz:<sender (which is actually the receiver!)>:<version number>
]]
local function HandleTXVersion(message, sender)
	local response = GetAddOnMetadata("Thaliz", "Version")	
	Thaliz_SendAddonMessage("RX_VERSION#"..response.."#"..sender)
end

local function HandleTXResBegin(message, sender)
	-- Blacklist target unless ress was initated by me
	if not (sender == UnitName("player")) then
		Thaliz_BlacklistPlayer(message);
	end
end

--[[
	A version response (RX) was received. The version information is displayed locally.
]]
local function HandleRXVersion(message, sender)
	Thaliz_Echo(string.format("%s is using Thaliz version %s", sender, message))
end

local function HandleTXVerCheck(message, sender)
--	echo(string.format("HandleTXVerCheck: msg=%s, sender=%s", message, sender));
	Thalix_CheckIsNewVersion(message);
end


function Thaliz_OnChatMsgAddon(event, prefix, msg, channel, sender)
	if prefix == THALIZ_PREFIX then
		Thaliz_HandleThalizMessage(msg, sender);	
	end
	if prefix == CTRA_PREFIX then
		Thaliz_HandleCTRAMessage(msg, sender);
	end
end



function Thaliz_HandleThalizMessage(msg, sender)
--	echo(sender.." --> "..msg);

	local _, _, cmd, message, recipient = string.find(msg, "([^#]*)#([^#]*)#([^#]*)");	
	--	Ignore message if it is not for me. Receipient can be blank, which means it is for everyone.
	if not (recipient == "") then
		if not (recipient == UnitName("player")) then
			return
		end
	end

	if cmd == "TX_VERSION" then
		HandleTXVersion(message, sender)
	elseif cmd == "RX_VERSION" then
		HandleRXVersion(message, sender)
	elseif cmd == "TX_RESBEGIN" then
		HandleTXResBegin(message, sender)
	elseif cmd == "TX_VERCHECK" then
		HandleTXVerCheck(message, sender)
	end
	
end

function Thaliz_HandleCTRAMessage(msg, sender)	
	-- "RESSED" is received when a res LANDS on target.
	-- Add to blacklist.
	if msg == "RESSED" then
		Thaliz_BlacklistPlayer(sender);
		return;
	end
	
	-- "RES <name>" is received when a manual res is CASTED
	-- Add to blacklist.
	local _, _, ctra_command, ctra_player = string.find(msg, "(%S*) (%S*)");
	if ctra_command and ctra_player then
		if ctra_command == "RES" then
			-- If sender is from ME, it is ME doing a manual ress. Announce it!
			if sender == UnitName("player") then
				-- Check if player is online; for this we need the unit id!
				local unitid = nil;
				if Thaliz_IsInRaid() then
					for n=1, GetNumRaidMembers(), 1 do
						if UnitName("raid"..n) == ctra_player then
							unitid = "raid"..n;
							break;
						end
					end
				else
					for n=1, GetNumPartyMembers(), 1 do
						if UnitName("party"..n) == ctra_player then
							unitid = "party"..n;
							break;
						end
					end				
				end

				if unitid then
					if UnitIsConnected(unitid) then
						-- If unit is blacklisted we should NOT display the ress. message.
						-- Unfortunately we cannot cancel the spell cast.
						if Thaliz_IsPlayerBlacklisted(ctra_player) then
							Thaliz_Echo(string.format("NOTE: Someone already ressed %s!", ctra_player));
							return;
						else
							Thaliz_AnnounceResurrection(ctra_player);
						end
					else
						Thaliz_Echo(string.format("NOTE: %s is offline!", ctra_player));
					end
				end				
			end
			
			Thaliz_BlacklistPlayer(ctra_player);
			return;
		end
	end

	-- "RESNO" is received when a res is cancelled 
	-- Do nothing.
	-- Question: should we remove from blacklist in that case?
	-- The cancellation could happen for two reasons (possibly more)
	--	- Target is out of LOS for the resser (but maybe not for me!)
	--	- Res was cancelled by movement or combat.
	--		In this case we SHOULD remove from blacklist, but if in combat we cant ress anyway.
	--	The problem here is we do not know WHO we was ressing!! We only have the SENDER name
	--	which is the name of the RESSER!
	
	-- "NORESSED" is received when res timeout OR res is accepted!
	-- Do nothing (the blacklist expires soon anyway)
end



--  *******************************************************
--
--	Event handlers
--
--  *******************************************************

function Thaliz_OnEvent(event)
	if (event == "ADDON_LOADED") then
		if arg1 == "Thaliz" then
		    Thaliz_InitializeConfigSettings();
		end
		
	elseif (event == "CHAT_MSG_ADDON") then
		Thaliz_OnChatMsgAddon(event, arg1, arg2, arg3, arg4, arg5)
	elseif (event == "RAID_ROSTER_UPDATE") then
		Thaliz_OnRaidRosterUpdate()
	end
end

function Thaliz_OnLoad()
	THALIZ_CURRENT_VERSION = Thaliz_CalculateVersion( GetAddOnMetadata("Thaliz", "Version") );

	Thaliz_Echo(string.format("version %s by %s", GetAddOnMetadata("Thaliz", "Version"), GetAddOnMetadata("Thaliz", "Author")));
    this:RegisterEvent("ADDON_LOADED");
    this:RegisterEvent("CHAT_MSG_ADDON");   
    this:RegisterEvent("RAID_ROSTER_UPDATE")
        
    Thaliz_InitializeListElements();
end

function Thaliz_CloseButton_OnClick()
	ThalizFrame:Hide();
	Thaliz_ConfigurationLevel = Thaliz_GetRootOption(Thaliz_ROOT_OPTION_CharacterBasedSettings, Thaliz_Configuration_Default_Level);
end
