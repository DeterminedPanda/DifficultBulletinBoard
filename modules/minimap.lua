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
  
  local function UpdatePosition()
    local angle = math.rad(DBB2.minimapButton.angle)
    local x, y
    local radius = 80
    
    x = math.cos(angle) * radius
    y = math.sin(angle) * radius
    
    DBB2.minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - radius + x, y - 52)
  end
  
  DBB2.minimapButton:SetScript("OnDragStart", function()
    this:LockHighlight()
    this.isDragging = true
  end)
  
  DBB2.minimapButton:SetScript("OnDragStop", function()
    this:UnlockHighlight()
    this.isDragging = false
    DBB2_Config.minimapAngle = DBB2.minimapButton.angle
  end)
  
  DBB2.minimapButton:SetScript("OnUpdate", function()
    if this.isDragging then
      local mx, my = GetCursorPosition()
      local px, py = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      
      mx = mx / scale
      my = my / scale
      
      local angle = math.deg(math.atan2(my - py, mx - px))
      DBB2.minimapButton.angle = angle
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
    end
  end)
  
  -- Tooltip
  DBB2.minimapButton:SetScript("OnEnter", function()
    DBB2.api.ShowTooltip(this, "LEFT", {
      {"|cffaaa7ccDifficult|cffffffffBulletinBoard", "highlight"},
      "Left-click to toggle window",
      "Drag to move this button"
    })
  end)
  
  DBB2.minimapButton:SetScript("OnLeave", function()
    DBB2.api.HideTooltip()
  end)
  
  -- Initial position
  UpdatePosition()
end)
