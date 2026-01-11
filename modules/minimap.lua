DBB2:RegisterModule("minimap", function()
  -- Create minimap button (standard circular minimap button)
  DBB2.minimapButton = CreateFrame("Button", "DBB2MinimapButton", Minimap)
  DBB2.minimapButton:SetFrameStrata("MEDIUM")
  DBB2.minimapButton:SetWidth(31)
  DBB2.minimapButton:SetHeight(31)
  DBB2.minimapButton:SetFrameLevel(8)
  DBB2.minimapButton:RegisterForDrag("LeftButton")
  DBB2.minimapButton:SetMovable(true)
  DBB2.minimapButton:EnableMouse(true)
  DBB2.minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  
  -- Create overlay frame for circular mask
  DBB2.minimapButton.overlay = CreateFrame("Frame", nil, DBB2.minimapButton)
  DBB2.minimapButton.overlay:SetWidth(53)
  DBB2.minimapButton.overlay:SetHeight(53)
  DBB2.minimapButton.overlay:SetPoint("TOPLEFT", 0, 0)
  DBB2.minimapButton.overlay:SetFrameLevel(DBB2.minimapButton:GetFrameLevel() + 1)
  
  -- Create overlay texture (circular border)
  DBB2.minimapButton.overlay.texture = DBB2.minimapButton.overlay:CreateTexture(nil, "OVERLAY")
  DBB2.minimapButton.overlay.texture:SetWidth(53)
  DBB2.minimapButton.overlay.texture:SetHeight(53)
  DBB2.minimapButton.overlay.texture:SetPoint("TOPLEFT", 0, 0)
  DBB2.minimapButton.overlay.texture:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  
  -- Create icon texture (circular)
  DBB2.minimapButton.icon = DBB2.minimapButton:CreateTexture(nil, "BACKGROUND")
  DBB2.minimapButton.icon:SetWidth(20)
  DBB2.minimapButton.icon:SetHeight(20)
  DBB2.minimapButton.icon:SetPoint("TOPLEFT", 7, -5)
  DBB2.minimapButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
  DBB2.minimapButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  
  -- Dragging functionality
  DBB2.minimapButton.angle = DBB2_Config.minimapAngle or 45
  DBB2.minimapButton.freePos = DBB2_Config.minimapFreePos or nil
  DBB2.minimapButton.freeMode = DBB2_Config.minimapFreeMode or false
  
  local function UpdatePosition()
    DBB2.minimapButton:ClearAllPoints()
    
    if DBB2.minimapButton.freeMode and DBB2.minimapButton.freePos then
      -- Free positioning mode - position relative to UIParent
      DBB2.minimapButton:SetPoint("CENTER", UIParent, "BOTTOMLEFT", DBB2.minimapButton.freePos.x, DBB2.minimapButton.freePos.y)
    else
      -- Locked to minimap circle
      local angle = math.rad(DBB2.minimapButton.angle)
      local radius = 80
      local x = math.cos(angle) * radius
      local y = math.sin(angle) * radius
      DBB2.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
  end
  
  DBB2.minimapButton:SetScript("OnDragStart", function()
    this:LockHighlight()
    this.isDragging = true
    this.freeDragging = IsControlKeyDown()
  end)
  
  DBB2.minimapButton:SetScript("OnDragStop", function()
    this:UnlockHighlight()
    this.isDragging = false
    this.freeDragging = false
    DBB2_Config.minimapAngle = DBB2.minimapButton.angle
    DBB2_Config.minimapFreePos = DBB2.minimapButton.freePos
    DBB2_Config.minimapFreeMode = DBB2.minimapButton.freeMode
  end)
  
  DBB2.minimapButton:SetScript("OnUpdate", function()
    if this.isDragging then
      local mx, my = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      mx = mx / scale
      my = my / scale
      
      if this.freeDragging then
        -- Free drag mode - place anywhere
        DBB2.minimapButton.freeMode = true
        DBB2.minimapButton.freePos = { x = mx, y = my }
      else
        -- Locked drag mode - rotate around minimap
        DBB2.minimapButton.freeMode = false
        local px, py = Minimap:GetCenter()
        local angle = math.deg(math.atan2(my - py, mx - px))
        DBB2.minimapButton.angle = angle
      end
      UpdatePosition()
    end
  end)
  
  -- Click handler
  DBB2.minimapButton:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
      if DBB2.gui:IsShown() then
        DBB2.gui:Hide()
      else
        DBB2.gui:Show()
      end
    elseif arg1 == "RightButton" and IsControlKeyDown() then
      -- Reset position to default (locked mode, 45 degrees)
      DBB2.minimapButton.angle = 45
      DBB2.minimapButton.freeMode = false
      DBB2.minimapButton.freePos = nil
      DBB2_Config.minimapAngle = 45
      DBB2_Config.minimapFreeMode = false
      DBB2_Config.minimapFreePos = nil
      UpdatePosition()
      DEFAULT_CHAT_FRAME:AddMessage("|cffaaa7ccDBB2:|r Minimap button position reset.")
    end
  end)
  
  -- Tooltip
  DBB2.minimapButton:SetScript("OnEnter", function()
    DBB2.api.ShowTooltip(this, "LEFT", {
      {"|cffaaa7ccDifficult|cffffffffBulletinBoard", "highlight"},
      "Left-click to toggle window",
      "Drag to rotate around minimap",
      "Ctrl + Drag to move freely",
      "Ctrl + Right-click to reset position"
    })
  end)
  
  DBB2.minimapButton:SetScript("OnLeave", function()
    DBB2.api.HideTooltip()
  end)
  
  -- Initial position
  UpdatePosition()
end)
