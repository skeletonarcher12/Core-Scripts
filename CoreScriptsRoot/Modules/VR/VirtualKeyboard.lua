-- VirtualKeyboard.lua --
-- Written by Kip Turner, copyright ROBLOX 2016 --


local CoreGui = game:GetService('CoreGui')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')
local HttpService = game:GetService('HttpService')
local ContextActionService = game:GetService('ContextActionService')
local PlayersService = game:GetService('Players')

local RobloxGui = CoreGui:WaitForChild("RobloxGui")
local Util = require(RobloxGui.Modules.Settings.Utility)

local vrKeyboardSuccess, vrKeyboardFlagValue = pcall(function() return settings():GetFFlag("UseVRKeyboardInLua") end)
local useVRKeyboard = (vrKeyboardSuccess and vrKeyboardFlagValue == true)


local RENDER_STEP_NAME = game:GetService("HttpService"):GenerateGUID() .. "VirtualKeyboard"

local NORMAL_KEY_COLOR = Color3.new(1,1,1)
local HOVER_KEY_COLOR = Color3.new(178/255,178/255,178/255)
local PRESSED_KEY_COLOR = Color3.new(0,162/255,1)
local SET_KEY_COLOR = Color3.new(0,162/255,1)
---------------------------------------- KEYBOARD LAYOUT --------------------------------------
local KEYBOARD_LAYOUT = HttpService:JSONDecode([==[
[
  [
    "~\n`",
    "!\n1",
    "@\n2",
    "#\n3",
    "$\n4",
    "%\n5",
    "^\n6",
    "&\n7",
    "*\n8",
    "(\n9",
    ")\n0",
    "_\n-",
    "+\n=",
    {
      "w": 2
    },
    "Delete"
  ],
  [
    {
      "w": 1.5
    },
    "Tab",
    "Q",
    "W",
    "E",
    "R",
    "T",
    "Y",
    "U",
    "I",
    "O",
    "P",
    "{\n[",
    "}\n]",
    {
      "w": 1.5
    },
    "|\n\\"
  ],
  [
    {
      "w": 1.75
    },
    "Caps",
    "A",
    "S",
    "D",
    "F",
    "G",
    "H",
    "J",
    "K",
    "L",
    ":\n;",
    "\"\n'",
    {
      "w": 2.25
    },
    "Enter"
  ],
  [
    {
      "w": 2.25
    },
    "Shift",
    "Z",
    "X",
    "C",
    "V",
    "B",
    "N",
    "M",
    "<\n,",
    ">\n.",
    "?\n/",
    {
      "w": 2.75
    },
    "Shift"
  ],
  [
    {
      "x": 3.75,
      "a": 7,
      "w": 6.25
    },
    ""
  ]
]
]==])
---------------------------------------- END KEYBOARD LAYOUT --------------------------------------


local function tokenizeString(str, tokenChar)
	local words = {}
	for word in string.gmatch(str, '([^' .. tokenChar .. ']+)') do
	    table.insert(words, word)
	end
	return words
end

-- RayPlaneIntersection

-- http://www.siggraph.org/education/materials/HyperGraph/raytrace/rayplane_intersection.htm
local function RayPlaneIntersection(ray, planeNormal, pointOnPlane)
	planeNormal = planeNormal.unit
	ray = ray.Unit
	-- compute Pn (dot) Rd = Vd and check if Vd == 0 then we know ray is parallel to plane
	local Vd = planeNormal:Dot(ray.Direction)
	
	-- could fuzzy equals this a little bit to account for imprecision or very close angles to zero
	if Vd == 0 then -- parallel, no intersection
		return nil
	end

	local V0 = planeNormal:Dot(pointOnPlane - ray.Origin)
	local t = V0 / Vd

	if t < 0 then --plane is behind ray origin, and thus there is no intersection
		return nil
	end
	
	return ray.Origin + ray.Direction * t
end


local function ExtendedInstance(instance)
	local this = {}
	do
		local mt =
		{
			__index = function (t, k)
				return instance[k]
			end;

			__newindex = function (t, k, v)
				instance[k] = v
			end;
		}
		setmetatable(this, mt)
	end
	return this
end






local function CreateKeyboardKey(keyboard, layoutData, keyData)
	local newKeyElement = Util:Create'TextButton'
	{
		Name = keyData[1];
		Text = keyData[#keyData];
		Position = UDim2.new(layoutData['x'], 1, layoutData['y'], 1);
		Size = UDim2.new(layoutData['width'], -2, layoutData['height'], -2);
		BorderSizePixel = 0;
		AutoButtonColor = false;
		Font = Enum.Font.Arial;
		FontSize = Enum.FontSize.Size12;
		BackgroundTransparency = 1;
		ZIndex = 2;
	}
	local backgroundImage = Util:Create'ImageLabel'
	{
		Name = 'KeyBackground';
		Size = UDim2.new(1,0,1,0);
		Position = UDim2.new(0,1,0,0); -- Fixes font's offset
		Image = 'rbxasset://textures/ui/LoadingScreen/BackgroundLight.png'; -- Get a proper image from art
		ScaleType = Enum.ScaleType.Slice;
		SliceCenter = Rect.new(70,70,110,110);
		BackgroundTransparency = 1;
		Parent = newKeyElement
	}

	local newKey = ExtendedInstance(newKeyElement)

	local hovering = false
	local pressed = false
	local isAlpha = #keyData == 1 and type(keyData[1]) == 'string' and #keyData[1] == 1 and string.byte(keyData[1]) >= string.byte("A") and string.byte(keyData[1]) <= string.byte("z")

	local function onClicked()
		local keyValue = nil
		local currentKeySetting = newKey:GetCurrentKeyValue()

		if currentKeySetting == 'Shift' then
			keyboard:SetShift(not keyboard:GetShift())
		elseif currentKeySetting == 'Caps' then
			keyboard:SetCaps(not keyboard:GetCaps())
		elseif currentKeySetting == 'Enter' then
			keyboard:Close(true)
		elseif currentKeySetting == 'Delete' then
			keyboard:BackspaceAtCursor()
		elseif currentKeySetting == 'Tab' then
			keyValue = '\t'
		else
			keyValue = currentKeySetting
		end

		if keyValue ~= nil then
			keyboard:SubmitCharacter(keyValue, isAlpha)
		end
	end

	local function update()
		local currentKey = newKey:GetCurrentKeyValue()

		if pressed then
			backgroundImage.ImageColor3 = PRESSED_KEY_COLOR
		elseif hovering then
			backgroundImage.ImageColor3 = HOVER_KEY_COLOR
		elseif currentKey == 'Caps' and keyboard:GetCaps() then
			backgroundImage.ImageColor3 = SET_KEY_COLOR
		elseif currentKey == 'Shift' and keyboard:GetShift() then
			backgroundImage.ImageColor3 = SET_KEY_COLOR
		else
			backgroundImage.ImageColor3 = NORMAL_KEY_COLOR
		end

		newKeyElement.Text = newKey:GetCurrentKeyValue()
	end

	rawset(newKey, "OnEnter", function()
		hovering = true
		update()
	end)
	rawset(newKey, "OnLeave", function()
		hovering = false
		pressed = false
		update()
	end)
	rawset(newKey, "OnDown", function()
		pressed = true
		update()		
	end)
	rawset(newKey, "OnUp", function()
		if pressed then
			onClicked()
		end
		pressed = false
		update()
	end)
	rawset(newKey, "GetCurrentKeyValue", function(self)
		local shiftEnabled = keyboard:GetShift()
		local capsEnabled = keyboard:GetCaps()

		if isAlpha then
			if capsEnabled and shiftEnabled then
				return string.lower(keyData[#keyData])
			elseif capsEnabled or shiftEnabled then
				return keyData[1]
			else
				return string.lower(keyData[#keyData])
			end
		end

		if shiftEnabled then
			return keyData[1]
		end

		return keyData[#keyData]
	end)
	rawset(newKey, "Update", function(self)
		update()
	end)

	update()

	return newKey
end



local function ConstructKeyboardUI(keyboardLayoutDefinition)
	local Panel3D = require(RobloxGui.Modules.Panel3D)
	local panel = Panel3D.Get(Panel3D.Panels.Keyboard)

	local keyboardContainer = Util:Create'Frame'
	{
		Name = 'VirtualKeyboard';
		Size = UDim2.new(1, 0, 1, 0);
		Position = UDim2.new(0, 0, 0, 0);
		BackgroundTransparency = 1;
		Active = true;
		Visible = false;
	};


	local keyboardSizeConstrainer = Util:Create'Frame'
	{
		Name = 'KeyboardSizeConstrainer';
		Size = UDim2.new(1, 0, 1, -20);
		Position = UDim2.new(0, 0, 0, 20);
		BackgroundTransparency = 1;
		Parent = keyboardContainer;
	};


	local textEntryBackground = Util:Create'ImageLabel'
	{
		Name = 'TextEntryBackground';
		Size = UDim2.new(1,0,0,20);
		Position = UDim2.new(0,0,0,0);
		Image = 'rbxasset://textures/ui/LoadingScreen/BackgroundLight.png';
		ScaleType = Enum.ScaleType.Slice;
		SliceCenter = Rect.new(70,70,110,110);
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		Parent = keyboardContainer;
	}
	local textEntryField = Util:Create'TextLabel'
	{
		Name = "TextEntryField";
		Text = "";
		Position = UDim2.new(0,4,0,4);
		Size = UDim2.new(1, -8, 1, -8);
		Font = Enum.Font.Arial;
		FontSize = Enum.FontSize.Size12;
		TextXAlignment = Enum.TextXAlignment.Left;
		BackgroundTransparency = 1;
		Parent = textEntryBackground;
	}


	local newKeyboard = ExtendedInstance(keyboardContainer)

	local keyboardOptions = nil
	local keys = {}
	local lastHoveredKey = nil

	local capsLockEnabled = false
	local shiftEnabled = false

	local buffer = ""

	local function getBufferText()
		if keyboardOptions and keyboardOptions.TextBox then
			return keyboardOptions.TextBox.Text
		end
		return buffer
	end
	local function setBufferText(newBufferText)
		if keyboardOptions and keyboardOptions.TextBox then
			keyboardOptions.TextBox.Text = newBufferText
		elseif buffer ~= newBufferText then
			buffer = newBufferText
			textEntryField.Text = buffer
		end
	end

	rawset(newKeyboard, "GetKeyByPosition", function(self, x,y)
		-- There are a lot of keys, we could optimize this by caching some sort of lookup
		for _, element in pairs(keys) do
			local minPt = element.AbsolutePosition
			local maxPt = element.AbsolutePosition + element.AbsoluteSize
			if minPt.X <= x and maxPt.X >= x and minPt.Y <= y and maxPt.Y >= y then
				return element
			end
		end
	end)

	rawset(newKeyboard, "GetKeyboardAbsoluteSize", function(self)
		return keyboardContainer.AbsoluteSize
	end)

	rawset(newKeyboard, "SetCursorPosition", function(self, x, y)
		local hoveredKey = self:GetKeyByPosition(x,y)
		if hoveredKey ~= lastHoveredKey then
			if lastHoveredKey then
				lastHoveredKey:OnLeave()
			end
			if hoveredKey then
				hoveredKey:OnEnter()
			end
			lastHoveredKey = hoveredKey
		end
	end)

	rawset(newKeyboard, "SetClickState", function(self, state)
		local hoveredKey = lastHoveredKey
		if hoveredKey then
			if state then
				hoveredKey:OnDown()
			else
				hoveredKey:OnUp()
			end
		end
	end)

	rawset(newKeyboard, "GetCaps", function(self)
		return capsLockEnabled
	end)

	rawset(newKeyboard, "SetCaps", function(self, newCaps)
		capsLockEnabled = newCaps
		for _, key in pairs(keys) do
			key:Update()
		end
	end)

	rawset(newKeyboard, "GetShift", function(self)
		return shiftEnabled
	end)

	rawset(newKeyboard, "SetShift", function(self, newShift)
		shiftEnabled = newShift
		for _, key in pairs(keys) do
			key:Update()
		end
	end)

	local textChangedConn = nil
	rawset(newKeyboard, "Open", function(self, options)
		keyboardOptions = options
		keyboardContainer.Visible = true


		local function OnRenderStep()
			if PlayersService.LocalPlayer then
				local cameraRenderCFrame = workspace.CurrentCamera and workspace.CurrentCamera:GetRenderCFrame()
				if cameraRenderCFrame and panel.part then
					local panelPartSize = panel.part.Size
					local panelSurfaceCFrame = panel.part.CFrame + panel.part.CFrame.lookVector * (panelPartSize.Z * 0.5)
					local intersectionPt = RayPlaneIntersection(Ray.new(cameraRenderCFrame.p, cameraRenderCFrame.lookVector), panelSurfaceCFrame.lookVector, panelSurfaceCFrame.p)
					if intersectionPt then
						local localPoint = panelSurfaceCFrame:pointToObjectSpace(intersectionPt) * Vector3.new(-1, 1, 1) + Vector3.new(panelPartSize.X/2, -panelPartSize.Y/2, 0)
						local guiPoint = Vector2.new((localPoint.X / panelPartSize.X) *  self:GetKeyboardAbsoluteSize().X, (localPoint.Y / panelPartSize.Y) * -self:GetKeyboardAbsoluteSize().Y)
						self:SetCursorPosition(guiPoint.x, guiPoint.y)
					end
				end
			end
		end

		local aDown = false
		local r2Down = false
		local mb1Down = false
		local function ClickedInVrfunction(actionName, inputState, inputObject)
			if inputObject.KeyCode == Enum.KeyCode.ButtonA then
				aDown = inputState == Enum.UserInputState.Begin
				self:SetClickState(aDown)
			elseif inputObject.KeyCode == Enum.KeyCode.ButtonR2 then
				if inputState == Enum.UserInputState.Begin then
					r2Down = true
					self:SetClickState(r2Down)
				elseif inputState == Enum.UserInputState.End then
					r2Down = false
					self:SetClickState(r2Down)
				end
			elseif inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				mb1Down = inputState == Enum.UserInputState.Begin
				self:SetClickState(mb1Down)
			end
		end

		if textChangedConn then textChangedConn:disconnect() end
		textChangedConn = nil	
		if options.TextBox then
			textChangedConn = options.TextBox.Changed:connect(function(prop)
				if prop == 'Text' then
					textEntryField.Text = options.TextBox.Text
				end
			end)
			if options.TextBox.ClearTextOnFocus then
				setBufferText("")
			else
				textEntryField.Text = options.TextBox.Text
			end
		else
			setBufferText("")
		end

		panel.OnMouseEnter = function()
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
			RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, OnRenderStep)
			ContextActionService:BindCoreAction("VirtualKeyboardSelectKey", ClickedInVrfunction, false, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2, Enum.UserInputType.MouseButton1)
		end
		panel.OnMouseLeave = function()
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
			ContextActionService:UnbindCoreAction("VirtualKeyboardSelectKey")
		end

		keyboardContainer.Visible = true

		self.Parent = panel.gui
		-- NOTE: we could dynamically fill in this
		panel:ResizePixels(3 * 125, 1 * 125 + 20)
		panel.pitchLockThreshold = math.rad(0)
		panel.visibilityBehavior = Panel3D.Visibility.Normal
		panel:SetVisible(true)
	end)

	rawset(newKeyboard, "Close", function(self, submit)
		if textChangedConn then textChangedConn:disconnect() end
		textChangedConn = nil
		-- Clean-up
		panel.OnMouseLeave()

		if submit and keyboardOptions and keyboardOptions.TextBox then
			keyboardOptions.TextBox.Text = getBufferText()
		end
		panel:SetVisible(false)
		keyboardContainer.Visible = false
		if keyboardOptions and keyboardOptions.TextBox then
			keyboardOptions.TextBox:ReleaseFocus()
		end
	end)

	rawset(newKeyboard, "BackspaceAtCursor", function(self)
		-- NOTE: we may want to implement cursor
		setBufferText(string.sub(getBufferText(), 1, #getBufferText() - 1))
	end)

	rawset(newKeyboard, "SubmitCharacter", function(self, character, isAnAlphaKey)
		-- NOTE: we may want to implement cursor
		setBufferText(getBufferText() .. character)

		if isAnAlphaKey and self:GetShift() then
			self:SetShift(false)
		end
	end)

	do -- Parse input definition
		local maxWidth = 0
		local maxHeight = 0

		local y = 0
		for rowNum, rowData in pairs(KEYBOARD_LAYOUT) do
			local x = 0
			local width = 1
			local height = 1

			for columnNum, columnData in pairs(rowData) do
				if type(columnData) == 'table' then
					if columnData['w'] then
						width = columnData['w']
					end
					if columnData['h'] then
						height = columnData['h']
					end
					if columnData['x'] then
						x = x + columnData['x']
					end
					if columnData['y'] then
						y = y + columnData['y']
					end
				elseif type(columnData) == 'string' then
					if columnData == "" then
						columnData = " "
					end
					-- put key
					table.insert(keys, CreateKeyboardKey(newKeyboard, {x = x, y = y, width = width, height = height}, tokenizeString(columnData, '\n')))

					x = x + width
					maxWidth = math.max(maxWidth, x)
					maxHeight = math.max(maxHeight, y + height)
					-- reset for next key
					width = 1
					height = 1

				end
			end
			y = y + 1
		end

		-- Fix the positions and sizes to fit in our KeyboardContainer
		for _, element in pairs(keys) do
			element.Position = UDim2.new(element.Position.X.Scale / maxWidth, 0, element.Position.Y.Scale / maxHeight, 0)
			element.Size = UDim2.new(element.Size.X.Scale / maxWidth, 0, element.Size.Y.Scale / maxHeight, 0)
			element.Parent = keyboardSizeConstrainer
		end

		keyboardSizeConstrainer.SizeConstraint = Enum.SizeConstraint.RelativeXX
		keyboardSizeConstrainer.Size = UDim2.new(1, 0, -maxHeight / maxWidth, 0)
		keyboardSizeConstrainer.Position = UDim2.new(0, 0, 1, 0)
	end
	

	return newKeyboard
end


local Keyboard = nil;
local function GetKeyboard()
	if Keyboard == nil then
		Keyboard = ConstructKeyboardUI(KEYBOARD_LAYOUT)
	end
	return Keyboard
end



local VirtualKeyboardClass = {}


function VirtualKeyboardClass:CreateVirtualKeyboardOptions(textbox)
	local keyboardOptions = {}

	keyboardOptions.TextBox = textbox

	return keyboardOptions
end

local VirtualKeyboardPlatform = false
do
	-- iOS, Android and Xbox already have platform specific keyboards
	local platform = UserInputService:GetPlatform()
	VirtualKeyboardPlatform = platform == Enum.Platform.Windows or
	                          platform == Enum.Platform.OSX
end


function VirtualKeyboardClass:ShowVirtualKeyboard(virtualKeyboardOptions)
	if VirtualKeyboardPlatform and UserInputService.VREnabled then
		GetKeyboard():Open(virtualKeyboardOptions)
	end
end

function VirtualKeyboardClass:CloseVirtualKeyboard()
	if VirtualKeyboardPlatform and UserInputService.VREnabled then
		GetKeyboard():Close()
	end
end

if VirtualKeyboardPlatform and useVRKeyboard then
	UserInputService.TextBoxFocused:connect(function(textbox)
		VirtualKeyboardClass:ShowVirtualKeyboard(VirtualKeyboardClass:CreateVirtualKeyboardOptions(textbox))
	end)

	UserInputService.TextBoxFocusReleased:connect(function(textbox)
		VirtualKeyboardClass:CloseVirtualKeyboard()
	end)


	-- Check with product if we should dismiss the keyboard if you navigate away from the textbox?
	-- Before hooking up check on keyboard open if the selectedobject property is the keyboard
	-- GuiService.Changed:connect(function(prop)
	-- 	if prop == 'SelectedObject' then
	-- 		-- we can close keyboard

	-- 	elseif prop == 'SelectedCoreObject' then
	-- 		-- we can close keyboard

	-- 	end
	-- end)
end


return VirtualKeyboardClass