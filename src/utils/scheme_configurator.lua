--- Theme settings utilities
--
-- This module provides functions for applying theme configuration settings to scheme files.
-- Each function replaces placeholders in scheme template files with calculated values based on the current application
-- state.
local errorHandler = require("error_handler")
local state = require("state")

local system = require("utils.system")

local themeSettings = {}

-- Apply glyph settings to a scheme file
function themeSettings.applyGlyphSettings(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		local glyphSettings = {
			list_pad_left = state.glyphs_enabled and 42 or 20,
			glyph_alpha = state.glyphs_enabled and 255 or 0,
		}

		-- Replace placeholders
		local listPadCount, glyphAlphaCount
		content, listPadCount = content:gsub("{%%%s*list_pad_left%s*}", tostring(glyphSettings["list_pad_left"]))
		content, glyphAlphaCount = content:gsub("%%{%s*glyph_alpha%s*}", tostring(glyphSettings["glyph_alpha"]))

		-- Check if replacements were successful
		if listPadCount == 0 then
			errorHandler.setError("Failed to replace list pad left in template")
			return content, false
		end
		if glyphAlphaCount == 0 then
			errorHandler.setError("Failed to replace glyph alpha in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply screen width settings to a scheme file
function themeSettings.applyScreenWidthSettings(schemeFilePath, screenWidth)
	return system.modifyFile(schemeFilePath, function(content)
		local contentPadding = 4
		local contentWidth = screenWidth - (contentPadding * 2)

		-- Replace content-padding placeholder
		local contentPaddingCount
		content, contentPaddingCount = content:gsub("%%{%s*content%-padding%s*}", tostring(contentPadding))
		if contentPaddingCount == 0 then
			errorHandler.setError("Failed to replace content padding settings in template")
			return content, false
		end

		-- Replace screen-width placeholder
		local screenWidthCount
		content, screenWidthCount = content:gsub("%%{%s*screen%-width%s*}", tostring(contentWidth))
		if screenWidthCount == 0 then
			errorHandler.setError("Failed to replace screen width settings in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply content width settings to the `muxplore.ini` file
function themeSettings.applyContentWidth(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Calculate content width based on box art setting
		local boxArtWidth = state.boxArtWidth + 20
		-- Calculate content width (screen width minus box art width)
		local contentWidth = state.screenWidth - boxArtWidth

		-- Replace content-width placeholder
		local contentWidthCount
		content, contentWidthCount = content:gsub("%%{%s*content%-width%s*}", tostring(contentWidth))
		if contentWidthCount == 0 then
			errorHandler.setError("Failed to replace content width settings in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply navigation alignment settings to a scheme file
function themeSettings.applyNavigationAlignmentSettings(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Map navigation alignment values to numeric settings
		local alignmentValue = 0 -- Default to left (0)

		if state.navigationAlignment == "Center" then
			alignmentValue = 1
		elseif state.navigationAlignment == "Right" then
			alignmentValue = 2
		end -- "Left" remains 0

		-- Replace navigation alignment placeholder
		local navigationAlignmentCount
		content, navigationAlignmentCount = content:gsub("%%{%s*navigation%-alignment%s*}", tostring(alignmentValue))
		if navigationAlignmentCount == 0 then
			errorHandler.setError("Failed to replace navigation alignment setting in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply status alignment settings to a scheme file
function themeSettings.applyStatusAlignmentSettings(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Map status alignment values to numeric settings
		local alignmentValue = 0 -- Default to Left (0)
		if state.statusAlignment == "Right" then
			alignmentValue = 1
		elseif state.statusAlignment == "Center" then
			alignmentValue = 2
		elseif state.statusAlignment == "Space Evenly" then
			alignmentValue = 3
		elseif state.statusAlignment == "Equal Distribution" then
			alignmentValue = 4
		elseif state.statusAlignment == "Edge Anchored" then
			alignmentValue = 5
		end

		-- Replace status-align placeholder
		local statusAlignCount
		content, statusAlignCount = content:gsub("%%{%s*status%-align%s*}", tostring(alignmentValue))
		if statusAlignCount == 0 then
			errorHandler.setError("Failed to replace status alignment setting in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply time alignment settings to a scheme file
function themeSettings.applyTimeAlignmentSettings(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Map time alignment values to numeric settings
		local alignmentValue = 1 -- Default to Left (1)
		if state.timeAlignment == "Auto" then
			alignmentValue = 0
		elseif state.timeAlignment == "Left" then
			alignmentValue = 1
		elseif state.timeAlignment == "Center" then
			alignmentValue = 2
		elseif state.timeAlignment == "Right" then
			alignmentValue = 3
		end

		-- Replace time-align placeholder
		local timeAlignCount
		content, timeAlignCount = content:gsub("%%{%s*time%-align%s*}", tostring(alignmentValue))
		if timeAlignCount == 0 then
			errorHandler.setError("Failed to replace time alignment setting in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply header text alpha settings to a scheme file
function themeSettings.applyHeaderTextAlpha(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		local alphaValue = state.headerTextAlpha or 255
		local headerAlphaCount
		content, headerAlphaCount = content:gsub("%%{%s*header%-text%-alpha%s*}", tostring(alphaValue))
		if headerAlphaCount == 0 then
			errorHandler.setError("Failed to replace header text alpha setting in template")
			return content, false
		end
		return content, true
	end)
end

-- Apply header text alignment settings to a scheme file
function themeSettings.applyHeaderTextAlignmentSettings(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Use the header text alignment value directly
		local alignmentValue = state.headerTextAlignment

		-- Replace header text alignment placeholder
		local headerTextAlignCount
		content, headerTextAlignCount = content:gsub("%%{%s*header%-text%-align%s*}", tostring(alignmentValue))
		if headerTextAlignCount == 0 then
			errorHandler.setError("Failed to replace header text alignment setting in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply navigation alpha settings to a scheme file
function themeSettings.applyNavigationAlphaSettings(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Remap navigation alpha from 0-100 to 0-255
		local alphaValue = math.floor((state.navigationAlpha / 100) * 255)

		-- Ensure the value is in the proper range
		alphaValue = math.max(0, math.min(255, alphaValue))

		-- Replace navigation alpha placeholder
		local navigationAlphaCount
		content, navigationAlphaCount = content:gsub("%%{%s*navigation%-alpha%s*}", tostring(alphaValue))
		if navigationAlphaCount == 0 then
			errorHandler.setError("Failed to replace navigation alpha setting in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply color settings to a scheme file (background, foreground, background-gradient, gradient-direction)
function themeSettings.applyColorSettings(schemeFilePath)
	local colorReplacements = {
		background = state.getColorValue("background"):gsub("^#", ""),
		foreground = state.getColorValue("foreground"):gsub("^#", ""),
		["background-gradient"] = state.backgroundType == "Gradient" and state
			.getColorValue("backgroundGradient")
			:gsub("^#", "") or state.getColorValue("background"):gsub("^#", ""),
	}

	-- First, replace color placeholders
	system.replaceColor(schemeFilePath, colorReplacements)

	-- Now, handle gradient-direction
	return system.modifyFile(schemeFilePath, function(content)
		local directionValue = 0
		if state.backgroundType == "Gradient" then
			if state.backgroundGradientDirection == "Vertical" then
				directionValue = 1
			elseif state.backgroundGradientDirection == "Horizontal" then
				directionValue = 2
			end
		end
		local count
		content, count = content:gsub("%%{%s*gradient%-direction%s*}", tostring(directionValue))
		if count == 0 then
			errorHandler.setError("Failed to replace gradient direction setting in template")
			return content, false
		end
		return content, true
	end)
end

-- Apply grid settings to the muxlaunch.ini file in the resolution-specific directory
function themeSettings.applyGridSettings(muxlaunchIniPath)
	local colCount, rowCount = 0, 0
	if state.homeScreenLayout == "Grid" then
		colCount, rowCount = 4, 2
	end
	return system.modifyFile(muxlaunchIniPath, function(content)
		local colCountReplaced
		content, colCountReplaced = content:gsub("%%{%s*grid%-column%-count%s*}", tostring(colCount))
		local rowCountReplaced
		content, rowCountReplaced = content:gsub("%%{%s*grid%-row%-count%s*}", tostring(rowCount))
		if colCountReplaced == 0 or rowCountReplaced == 0 then
			errorHandler.setError("Failed to replace grid column/row count in muxlaunch.ini")
			return content, false
		end
		return content, true
	end)
end

return themeSettings
