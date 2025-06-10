--- TabBar UI Component
local love = require("love")
local tween = require("tween")
local component = require("ui.component").Component
local colors = require("colors")
local fonts = require("ui.fonts")

local TabBar = setmetatable({}, { __index = component })
TabBar.__index = TabBar

function TabBar:new(config)
	local instance = setmetatable(component.new(self, config), self)
	instance.tabs = config.tabs or {}
	instance.onTabSwitched = config.onTabSwitched
	instance.height = config.height or 40
	instance.width = config.width or 100
	instance.x = config.x or 0
	instance.y = config.y or 0
	instance.tabPadding = 8 -- px left/right
	instance.tabTextPadding = 8
	instance.cornerRadius = instance.height / 4
	instance.animationDuration = 0.2

	instance.tabIndicator = { x = 0, width = 0, animation = nil }
	instance.tabTextColors = {}

	-- Set up tab layout
	instance:layoutTabs()
	instance:initializeTextColors()
	instance:switchToTab(config.initialTab or instance.tabs[1].name)

	return instance
end

function TabBar:layoutTabs()
	local availableWidth = self.width
	local tabCount = #self.tabs
	local tabWidth = availableWidth / tabCount
	for i, tab in ipairs(self.tabs) do
		tab.x = self.x + (i - 1) * tabWidth
		tab.width = tabWidth
	end
end

function TabBar:initializeTextColors()
	for i = 1, #self.tabs do
		self.tabTextColors[i] = {
			color = { 0, 0, 0, 1 },
			animation = nil,
		}
	end
end

function TabBar:getActiveTab()
	for i, tab in ipairs(self.tabs) do
		if tab.active then
			return tab, i
		end
	end
	return self.tabs[1], 1
end

function TabBar:updateTabAnimations()
	local activeTab, _ = self:getActiveTab()
	local targetX = activeTab.x
	local targetWidth = activeTab.width
	self.tabIndicator.animation =
		tween.new(self.animationDuration, self.tabIndicator, { x = targetX, width = targetWidth }, "inOutQuad")
	for i, tab in ipairs(self.tabs) do
		local targetColor
		if tab.active then
			targetColor = { colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1 }
		else
			targetColor = { colors.ui.subtext[1], colors.ui.subtext[2], colors.ui.subtext[3], 1 }
		end
		self.tabTextColors[i].animation =
			tween.new(self.animationDuration, self.tabTextColors[i], { color = targetColor }, "inOutQuad")
	end
end

function TabBar:switchToTab(tabName)
	for _, tab in ipairs(self.tabs) do
		if tab.name:lower() == tabName:lower() then
			for _, t in ipairs(self.tabs) do
				t.active = false
			end
			tab.active = true
			self:updateTabAnimations()
			if self.onTabSwitched then
				self.onTabSwitched(tab)
			end
			return true
		end
	end
	return false
end

function TabBar:nextTab()
	local _, idx = self:getActiveTab()
	local newIndex = idx + 1
	if newIndex > #self.tabs then
		newIndex = 1
	end
	self:switchToTab(self.tabs[newIndex].name)
end

function TabBar:prevTab()
	local _, idx = self:getActiveTab()
	local newIndex = idx - 1
	if newIndex < 1 then
		newIndex = #self.tabs
	end
	self:switchToTab(self.tabs[newIndex].name)
end

function TabBar:update(dt)
	if self.tabIndicator.animation then
		self.tabIndicator.animation:update(dt)
	end
	for _, textColorAnim in ipairs(self.tabTextColors) do
		if textColorAnim.animation then
			textColorAnim.animation:update(dt)
		end
	end
	-- Handle input (shoulder buttons)
	local virtualJoystick = require("input").virtualJoystick
	if virtualJoystick.isGamepadPressedWithDelay("leftshoulder") then
		self:prevTab()
	elseif virtualJoystick.isGamepadPressedWithDelay("rightshoulder") then
		self:nextTab()
	end
end

function TabBar:draw()
	-- Draw indicator (gradient background with outline, animated)
	local indicatorY = self.y
	local indicatorX = self.tabIndicator.x
	local indicatorWidth = self.tabIndicator.width
	if indicatorWidth > 0 then
		local topColor = colors.ui.surface_focus_start
		local bottomColor = colors.ui.surface_focus_stop
		local mesh = love.graphics.newMesh({
			{ indicatorX, indicatorY, 0, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
			{ indicatorX + indicatorWidth, indicatorY, 1, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
			{
				indicatorX + indicatorWidth,
				indicatorY + self.height,
				1,
				1,
				bottomColor[1],
				bottomColor[2],
				bottomColor[3],
				bottomColor[4] or 1,
			},
			{
				indicatorX,
				indicatorY + self.height,
				0,
				1,
				bottomColor[1],
				bottomColor[2],
				bottomColor[3],
				bottomColor[4] or 1,
			},
		}, "fan", "static")
		love.graphics.stencil(function()
			love.graphics.rectangle(
				"fill",
				indicatorX,
				indicatorY,
				indicatorWidth,
				self.height,
				self.cornerRadius,
				self.cornerRadius
			)
		end, "replace", 1)
		love.graphics.setStencilTest("equal", 1)
		love.graphics.draw(mesh)
		love.graphics.setStencilTest()
		love.graphics.setColor(colors.ui.surface_focus_outline)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", indicatorX, indicatorY, indicatorWidth, self.height, self.cornerRadius)
	end
	-- Draw tab text
	for i, tab in ipairs(self.tabs) do
		local tabY = self.y + (self.height - fonts.loaded.body:getHeight()) / 2 - 1
		local tabX = tab.x
		local tabWidth = tab.width
		if tab.active then
			love.graphics.setColor(colors.ui.foreground)
		else
			love.graphics.setColor(self.tabTextColors[i].color)
		end
		love.graphics.setFont(fonts.loaded.body)
		love.graphics.printf(tab.name, tabX, tabY, tabWidth, "center")
	end
end

return TabBar
