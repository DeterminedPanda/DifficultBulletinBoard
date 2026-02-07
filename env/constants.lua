-- DBB2 UI Constants
-- Centralized spacing and font size values for consistent UI
-- These constants are used throughout the config system for layout consistency

-- =====================
-- CONSTANT DOMAINS
-- =====================
-- This file (env/constants.lua) contains static config panel constants:
--   DBB2.env.SPACING   -> Widget spacing, padding, row heights
--   DBB2.env.FONT_SIZE -> Font sizes for labels, inputs, descriptions
-- Used by: config_schema.lua, config_widgets.lua (settings UI)
--
-- Main GUI constants (message rows, scroll frames, tabs) are in api/gui_schema.lua
-- as DBB2.schema.* - computed dynamically with DBB2:ScaleSize()
--
-- The two domains are intentionally separate:
--   DBB2.env    -> Config panels (settings UI)
--   DBB2.schema -> Main GUI (message display, tabs, scrolling)

DBB2.env = DBB2.env or {}

-- Spacing constants (used everywhere for consistency)
DBB2.env.SPACING = {
  widget = 11,        -- Between widgets
  section = 19,       -- Before section headers
  afterSection = 8,   -- After section headers
  description = 5,    -- After descriptions
  padding = 10,       -- Panel edge padding
  rowHeight = 28,     -- Category/keyword row height
  checkSize = 14,     -- Checkbox size
  inputHeight = 18,   -- Input field height
  bottomPadding = 0,  -- Extra scroll space after last content
}

-- Font sizes
DBB2.env.FONT_SIZE = 9             -- For settings/labels under sections
DBB2.env.FONT_SIZE_INPUT = 10     -- For text inside input boxes
DBB2.env.FONT_SIZE_SMALL = 8      -- For descriptions and secondary text
DBB2.env.FONT_SIZE_LARGE = 11     -- For buttons and emphasis
DBB2.env.SECTION_FONT_SIZE = 10   -- For section headers

-- Default widget width
DBB2.env.DEFAULT_WIDTH = 250
