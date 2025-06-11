DifficultBulletinBoard = DifficultBulletinBoard or {}

function DifficultBulletinBoard.GetClassIconFromClassName(class) 
    if class == "Druid" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\druid_class_icon"
    elseif class == "Hunter" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\hunter_class_icon"
    elseif class == "Mage" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\mage_class_icon"
    elseif class == "Paladin" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\paladin_class_icon"
    elseif class == "Priest" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\priest_class_icon"
    elseif class == "Rogue" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\rogue_class_icon"
    elseif class == "Shaman" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\shaman_class_icon"
    elseif class == "Warlock" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\warlock_class_icon"
    elseif class == "Warrior" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\warrior_class_icon"
    else
        return nil
    end
end

function DifficultBulletinBoard.GetClassColorFromClassName(class) 
    if class == "Druid" then
        return 1.00, 0.49, 0.04
    elseif class == "Hunter" then
        return 0.67, 0.83, 0.45
    elseif class == "Mage" then
        return 0.41, 0.80, 0.94
    elseif class == "Paladin" then
        return 0.96, 0.55, 0.73
    elseif class == "Priest" then
        return 1.00, 1.00, 1.00
    elseif class == "Rogue" then
        return 1.00, 0.96, 0.41
    elseif class == "Shaman" then
        return 0.00, 0.44, 0.87
    elseif class == "Warlock" then
        return 0.58, 0.51, 0.79
    elseif class == "Warrior" then
        return 0.78, 0.61, 0.43
    else
        --fallback to a neutral gray
        return 0.8, 0.8, 0.8
    end
end