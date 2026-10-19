-- luacheck for Alters Forever: WoW runs Lua 5.1.
-- An unknown global is usually a typo, or a local used before it is defined.
-- Add a WoW API name here only when the code really needs it.
std = "lua51"
max_line_length = false
exclude_files = { "tests/**" }

ignore = {
    "211/ADDON",    -- the addon name from "..." is not used
    "411",          -- redefined local in the same scope
    "431", "432",   -- shadowed upvalues
}

-- written by the addon
globals = {
    "AltersForeverDB",
    "SLASH_ALTERSFOREVER1", "SLASH_ALTERSFOREVER2", "SLASH_ALTERSFOREVER3",
    "SlashCmdList",
    "StaticPopupDialogs",
}

-- WoW API and UI globals that the addon reads
read_globals = {
    -- Lua helpers from WoW
    "date", "format", "strsplit", "strtrim", "time", "wipe", "hooksecurefunc", "issecretvalue",

    -- namespaces
    "C_AuctionHouse", "C_ClassTalents", "C_Container", "C_CurrencyInfo", "C_DateAndTime", "C_Item",
    "C_Reputation", "C_SkillInfo", "C_Spell", "C_Texture", "C_Timer", "C_TradeSkillUI", "C_Traits",
    "Enum", "TooltipDataProcessor",

    -- frames and UI functions
    "CreateFrame", "CreateAtlasMarkup", "CreateColor", "UIParent", "Minimap", "GameTooltip", "ItemRefTooltip",
    "DEFAULT_CHAT_FRAME", "UISpecialFrames", "StaticPopup_Show", "ChatEdit_InsertLink",
    "HandleModifiedItemClick", "IsModifiedClick", "IsShiftKeyDown", "GetCursorPosition", "GetMinimapShape",
    "ButtonFrameTemplate_HideButtonBar", "ButtonFrameTemplate_HidePortrait",
    "GameFontHighlightSmall", "GameFontNormalSmall",
    "LegacyMicroButton", "PlayerSpellsMicroButton", "TalentMicroButton",

    -- player and units
    "UnitArmor", "UnitAttackPower", "UnitClass", "UnitDamage", "UnitFactionGroup", "UnitGUID",
    "UnitHealthMax", "UnitHonor", "UnitHonorLevel", "UnitLevel", "UnitName", "UnitPowerMax", "UnitRace",
    "UnitRangedAttackPower", "UnitRangedDamage", "UnitResistance", "UnitStat", "UnitXP", "UnitXPMax",
    "GetBlockChance", "GetCritChance", "GetDodgeChance", "GetHitModifier", "GetManaRegen", "GetParryChance",
    "GetRangedCritChance", "GetSpellBonusDamage", "GetSpellBonusHealing", "GetSpellCritChance",
    "GetGuildInfo", "GetLocale", "GetMaxPlayerLevel", "GetMoney", "GetMoneyString", "GetRealZoneText",
    "GetRealmName", "GetTime", "GetXPExhaustion", "InCombatLockdown", "IsResting", "RequestTimePlayed",

    -- items, professions, instances, statistics, PvP
    "GetInventoryItemID", "GetInventoryItemLink", "GetInventorySlotInfo", "GetProfessionInfo", "GetProfessions",
    "GetNumSavedInstances", "GetNumSavedWorldBosses", "GetSavedInstanceInfo", "GetSavedWorldBossInfo",
    "RequestRaidInfo", "GetAchievementInfo", "GetCategoryInfo", "GetCategoryNumAchievements", "GetStatistic",
    "GetStatisticsCategoryList", "GetPVPLifetimeStats", "GetPVPSessionStats", "GetPVPYesterdayStats",

    -- guild bank
    "GetCurrentGuildBankTab", "GetGuildBankItemInfo", "GetGuildBankItemLink", "GetGuildBankMoney",
    "GetGuildBankTabInfo", "GetNumGuildBankTabs", "QueryGuildBankTab", "MAX_GUILDBANK_SLOTS_PER_TAB",
    "GUILDBANK_TAB_NUMBER",

    -- mail
    "GetInboxHeaderInfo", "GetInboxItem", "GetInboxItemLink", "GetInboxNumItems", "HasNewMail",
    "GetSendMailCOD", "GetSendMailItem", "GetSendMailItemLink", "GetSendMailMoney",
    "ATTACHMENTS_MAX_RECEIVE", "ATTACHMENTS_MAX_SEND",

    -- global strings and tables
    "ACCEPT", "ARMOR", "BACKPACK_TOOLTIP", "CALENDAR_WEEKDAY_NAMES", "CANCEL", "FACTION_BAR_COLORS",
    "HEALTH", "ITEM_MIN_SKILL", "ITEM_QUALITY_COLORS", "KEYRING", "MANA", "NO", "NUM_CHAT_WINDOWS", "OKAY",
    "RAID_CLASS_COLORS", "UNKNOWN", "YES",
}
