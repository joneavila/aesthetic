--- Theme settings utilities
local system = require("utils.system")
local state = require("state")
local errorHandler = require("error_handler")

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

-- Apply content height settings to a scheme file
function themeSettings.applyContentHeightSettings(schemeFilePath, screenHeight)
	return system.modifyFile(schemeFilePath, function(content)
		-- Extract HEADER_HEIGHT and FOOTER_HEIGHT from the scheme file
		local headerHeight
		local footerHeight

		-- Find HEADER_HEIGHT using pattern matching (allowing spaces around equals sign)
		local headerHeightMatch = content:match("HEADER_HEIGHT%s*=%s*(%d+)")
		if headerHeightMatch then
			local parsedHeight = tonumber(headerHeightMatch)
			if parsedHeight then
				headerHeight = parsedHeight
			else
				errorHandler.setError("HEADER_HEIGHT value is not a valid number")
				return content, false
			end
		else
			errorHandler.setError("Failed to find HEADER_HEIGHT in scheme file")
			return content, false
		end

		-- Find FOOTER_HEIGHT using pattern matching (allowing spaces around equals sign)
		local footerHeightMatch = content:match("FOOTER_HEIGHT%s*=%s*(%d+)")
		if footerHeightMatch then
			local parsedHeight = tonumber(footerHeightMatch)
			if parsedHeight then
				footerHeight = parsedHeight
			else
				errorHandler.setError("FOOTER_HEIGHT value is not a valid number")
				return content, false
			end
		else
			errorHandler.setError("Failed to find FOOTER_HEIGHT in scheme file")
			return content, false
		end

		-- Calculate content height (screen height minus header and footer heights)
		local contentHeight = screenHeight - headerHeight - footerHeight

		-- Replace content-height placeholder
		local contentHeightCount
		content, contentHeightCount = content:gsub("%%{%s*content%-height%s*}", tostring(contentHeight))
		if contentHeightCount == 0 then
			errorHandler.setError("Failed to replace content height settings in template")
			return content, false
		end

		-- Determine content item count based on display height
		local contentItemCount = 9 -- Default value for 480px height
		if screenHeight == 576 then
			contentItemCount = 11
		elseif screenHeight == 720 or screenHeight == 768 then
			contentItemCount = 13
		end

		-- Replace content-item-count placeholder
		local contentItemCountReplaceCount
		content, contentItemCountReplaceCount =
			content:gsub("%%{%s*content%-item%-count%s*}", tostring(contentItemCount))
		if contentItemCountReplaceCount == 0 then
			errorHandler.setError("Failed to replace content item count settings in template")
			return content, false
		end

		return content, true
	end)
end

-- Apply content width settings to the `muxplore.ini` file
function themeSettings.applyContentWidth(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Calculate content width based on box art setting
		local boxArtWidth = 0
		if type(state.boxArtWidth) == "number" then
			-- Add some padding to account for list selected padding
			boxArtWidth = state.boxArtWidth + 20
		end
		-- For "Disabled", boxArtWidth remains 0

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

-- Apply antialiasing settings to a scheme file
function themeSettings.applyAntialiasingSettings(schemeFilePath)
	return system.modifyFile(schemeFilePath, function(content)
		-- Modified: Always use antialiasing
		local antialiasingValue = 1
		local antialiasingCount
		content, antialiasingCount = content:gsub("%%{%s*antialiasing%s*}", tostring(antialiasingValue))
		if antialiasingCount == 0 then
			errorHandler.setError("Failed to replace antialiasing setting in template")
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

return themeSettings
