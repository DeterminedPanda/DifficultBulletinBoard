DifficultBulletinBoard = DifficultBulletinBoard or {}

DifficultBulletinBoard.defaultNumberOfPlaceholders = 3

DifficultBulletinBoard.defaultTopics = {
    { name = "Naxxramas", selected = true, tags = { "naxxramas", "naxx" } },
    { name = "Temple of Ahn'Qiraj", selected = true, tags = { "ahn'qiraj", "ahnqiraj", "aq40", "aq" } },
    { name = "Emerald Sanctum", selected = true, tags = { "emerald", "sanctum", "es" } },
    { name = "Blackwing Lair", selected = true, tags = { "blackwing", "bwl" } },
    { name = "Lower Karazhan Halls", selected = true, tags = { "karazhan", "kara", "kara10" } },
    { name = "Onyxia's Lair", selected = true, tags = { "onyxia", "ony" } },
    { name = "Molten Core", selected = true, tags = { "molten", "mc" } },
    { name = "Ruins of Ahn'Qiraj", selected = true, tags = { "ruins", "ahn'qiraj", "ahnqiraj", "aq20", "aq" } },
    { name = "Zul'Gurub", selected = true, tags = { "zul'gurub", "zulgurub", "zg" } },
    { name = "Stormwind Vault", selected = true, tags = { "vault", "swvault" } },
    { name = "Caverns of Time: Black Morass", selected = true, tags = { "cot", "morass", "cavern", "cot:bm", "bm" } },
    { name = "Karazhan Crypt", selected = true, tags = { "crypt", "kara", "karazhan" } },
    { name = "Upper Blackrock Spire", selected = true, tags = { "ubrs", "blackrock", "upper", "spire" } },
    { name = "Lower Blackrock Spire", selected = true, tags = { "lbrs", "blackrock", "lower", "spire" } },
    { name = "Stratholme", selected = true, tags = { "strat", "stratholme" } },
    { name = "Scholomance", selected = true, tags = { "scholo", "scholomance" } },
    { name = "Dire Maul", selected = true, tags = { "dire", "maul", "dm", "dm:e", "dm:w", "dm:n", "dmw", "dmn", "dme" } },
    { name = "Blackrock Depths", selected = true, tags = { "brd", "blackrock", "depths" } },
    { name = "Hateforge Quarry", selected = true, tags = { "hateforge", "quarry", "hq", "hfq"} },
    { name = "The Sunken Temple", selected = true, tags = { "st", "sunken", "temple" } },
    { name = "Zul'Farrak", selected = true, tags = { "zf", "zul'farrak", "zulfarrak" } },
    { name = "Maraudon", selected = true, tags = { "mara", "maraudon" } },
    { name = "Gilneas City", selected = true, tags = { "gilneas" } },
    { name = "Uldaman", selected = true, tags = { "uldaman" } },
    { name = "Razorfen Downs", selected = true, tags = { "razorfen", "downs", "rfd" } },
    { name = "Scarlet Monastery", selected = true, tags = { "scarlet", "monastery", "sm", "armory", "cathedral", "library", "graveyard" } },
    { name = "The Crescent Grove", selected = true, tags = { "crescent", "grove" } },
    { name = "Razorfen Kraul", selected = true, tags = { "razorfen", "kraul" } },
    { name = "Gnomeregan", selected = true, tags = { "gnomeregan", "gnomer" } },
    { name = "The Stockade", selected = true, tags = { "stockade", "stockades", "stock", "stocks" } },
    { name = "Blackfathom Deeps", selected = true, tags = { "bfd", "blackfathom" } },
    { name = "Shadowfang Keep", selected = true, tags = { "sfk", "shadowfang" } },
    { name = "The Deadmines", selected = true, tags = { "vc", "dm", "deadmine", "deadmines" } },
    { name = "Wailing Caverns", selected = true, tags = { "wc", "wailing", "caverns" } },
    { name = "Ragefire Chasm", selected = true, tags = { "rfc", "ragefire", "chasm" } }
}

function DifficultBulletinBoard.deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = DifficultBulletinBoard.deepCopy(value)
        else
            copy[key] = value
        end
    end

    return copy
end

function DifficultBulletinBoard.printDefaultTopics()
    for _, topic in ipairs(DifficultBulletinBoard.defaultTopics) do
        DEFAULT_CHAT_FRAME:AddMessage(topic.name)
    end
end