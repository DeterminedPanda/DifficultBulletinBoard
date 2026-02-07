-- DBB2 Static Lookup Tables
-- Descriptions and labels used by config widgets
-- These tables are referenced by config_widgets.lua for tooltips and labels

DBB2.env = DBB2.env or {}

-- Channel descriptions for tooltips
DBB2.env.channelDescriptions = {
  Say = "Local /say chat",
  Yell = "Local /yell chat",
  Guild = "Your guild chat",
  Whisper = "Private whispers",
  Party = "Your party chat",
  General = "Zone general chat",
  Trade = "Trade channel",
  LocalDefense = "Zone defense",
  WorldDefense = "World defense",
  LookingForGroup = "Official LFG channel",
  GuildRecruitment = "Guild recruitment",
  World = "Main LFG channel",
  Hardcore = "Hardcore channel"
}

-- Pattern descriptions for keyword blacklist
DBB2.env.patternDescriptions = {
  ["<*>"] = "<Guild Name>",
  ["\\[??\\]"] = "[pl], [it]",
  ["\\[???\\]"] = "[pol], [ita]",
  ["recruit*"] = "recruit, recruiting",
  ["recrut*"] = "recrut, recrute"
}

-- Instance name aliases for lockout matching
-- Maps WoW's GetSavedInstanceInfo names to addon category names
DBB2.env.instanceAliases = {
  ["ahn'qiraj temple"] = "Temple of Ahn'Qiraj",
  ["ahn'qiraj ruins"] = "Ruins of Ahn'Qiraj",
  ["karazhan halls"] = "Upper Karazhan Halls",
  ["black morass"] = "Caverns of Time: Black Morass",
}
