-----------------------------------------------------------------------------------------------
-- Notes
-----------------------------------------------------------------------------------------------
-- 
-----------------------------------------------------------------------------------------------
-- Item qualities:
-- Item Enum                            CRB_string                          Icon Border Sprite
-----------------------------------------------------------------------------------------------
-- Item.CodeEnumItemQuality.Inferior  = Apollo.GetString("CRB_Inferior")  = "BK3:UI_BK3_ItemQualityGrey"
-- Item.CodeEnumItemQuality.Average   = Apollo.GetString("CRB_Average")   = "BK3:UI_BK3_ItemQualityWhite"
-- Item.CodeEnumItemQuality.Good      = Apollo.GetString("CRB_Good")      = "BK3:UI_BK3_ItemQualityGreen"
-- Item.CodeEnumItemQuality.Excellent = Apollo.GetString("CRB_Excellent") = "BK3:UI_BK3_ItemQualityBlue"
-- Item.CodeEnumItemQuality.Superb    = Apollo.GetString("CRB_Superb")    = "BK3:UI_BK3_ItemQualityPurple"
-- Item.CodeEnumItemQuality.Legendary = Apollo.GetString("CRB_Legendary") = "BK3:UI_BK3_ItemQualityOrange"
-- Item.CodeEnumItemQuality.Artifact  = Apollo.GetString("CRB_Artifact")  = "BK3:UI_BK3_ItemQualityMagenta"

-----------------------------------------------------------------------------------------------
-- Client Lua Script for Scrappy
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- Scrappy Module Definition
-----------------------------------------------------------------------------------------------
local Scrappy = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local ktQualityCodeToBorderStrings = {
	[Item.CodeEnumItemQuality.Inferior]  = "BK3:UI_BK3_ItemQualityGrey",
	[Item.CodeEnumItemQuality.Average]   = "BK3:UI_BK3_ItemQualityWhite",
	[Item.CodeEnumItemQuality.Good]      = "BK3:UI_BK3_ItemQualityGreen",
	[Item.CodeEnumItemQuality.Excellent] = "BK3:UI_BK3_ItemQualityBlue",
	[Item.CodeEnumItemQuality.Superb]    = "BK3:UI_BK3_ItemQualityPurple",
	[Item.CodeEnumItemQuality.Legendary] = "BK3:UI_BK3_ItemQualityOrange",
	[Item.CodeEnumItemQuality.Artifact]  = "BK3:UI_BK3_ItemQualityMagenta"
}
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Scrappy:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    return o
end

function Scrappy:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- Scrappy OnLoad
-----------------------------------------------------------------------------------------------
function Scrappy:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Scrappy.xml")
	self.xmlDoc = XmlDoc.CreateFromFile("Scrappy.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- Scrappy OnDocLoaded
-----------------------------------------------------------------------------------------------
function Scrappy:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "ScrappyForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("sp", "OnScrappyOn", self)
		Apollo.RegisterSlashCommand("scrappy", "OnScrappyOn", self)

		Apollo.RegisterEventHandler("UpdateInventory", "RedrawSalvList", self)

		-- Do additional Addon initialization here
		self.wndSalvList = self.wndMain:FindChild("SalvList")
		self.tSalvList = {}

		-- filter options
		self.wndFilterOptions = Apollo.LoadForm(self.xmlDoc, "FilterOptions", self.wndMain, self)
		self.wndFilterOptions:Show(false)
		self.tFilterOptions = {}
		-- by item quality
		self.tFilterOptions.tQualityFlags = {
			[Item.CodeEnumItemQuality.Inferior]  = false,
			[Item.CodeEnumItemQuality.Average]   = false,
			[Item.CodeEnumItemQuality.Good]      = false,
			[Item.CodeEnumItemQuality.Excellent] = false,
			[Item.CodeEnumItemQuality.Superb]    = false,
			[Item.CodeEnumItemQuality.Legendary] = false,
			[Item.CodeEnumItemQuality.Artifact]  = false,
		}
		self.tFilterOptions.bDecorations = false
		self.tFilterOptions.bCostumes = false
		-- item being salvaged
		self.tFilterOptions.tItemBeingSalvaged = {}
		-- by item id (table of item ids to bool)
		self.tFilterOptions.tItemsIgnored = {}
	end
end

-----------------------------------------------------------------------------------------------
-- Scrappy Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/scrappy"
function Scrappy:OnScrappyOn()
	self.wndMain:Invoke() -- show the window
	self:RedrawSalvList()
end

function Scrappy:RedrawSalvList()
	self:DestroySalvList()

	self.tSalvList = {}
	local tInvItems = GameLib.GetPlayerUnit():GetInventoryItems()
	for i, tInventoryItem in ipairs(tInvItems) do
		if tInventoryItem then
			local tItem = tInventoryItem.itemInBag;
			if tItem and self:FilterItem(tItem) then
				local wnd = Apollo.LoadForm(self.xmlDoc, "SalvItem", self.wndSalvList, self)
				local wndTextContainer = wnd:FindChild("TextContainer")
				wndTextContainer:FindChild("Name"):SetText(tItem:GetName())
				wndTextContainer:FindChild("Type"):SetText(tItem:GetItemTypeName())
				wnd:FindChild("Icon"):SetSprite(tItem:GetIcon())
				wnd:FindChild("QualityBorder"):SetSprite(ktQualityCodeToBorderStrings[tItem:GetItemQuality()])
				local uSellPrice = tItem:GetSellPrice()
				if uSellPrice ~= nil then
					wnd:FindChild("SellValueCashWindow"):SetAmount(uSellPrice)
				end
				local wndSalvButton = wnd:FindChild("SalvButton")
				wndSalvButton:SetActionData(GameLib.CodeEnumConfirmButtonType.SalvageItem, tItem:GetInventoryId())
				wndSalvButton:SetData(tItem:GetItemId())
				local itemEquipped = tItem:GetEquippedItemForItemType()
				Tooltip.GetItemTooltipForm(self, wndSalvButton, tItem, {bPrimary = true, bSelling = false, itemCompare = itemEquipped})
				wnd:FindChild("IgnoreButton"):SetData(tItem:GetItemId())
				table.insert(self.tSalvList, wnd)
			end
		end
	end
	self.wndSalvList:ArrangeChildrenVert()
end

function Scrappy:FilterItem(tItem)
	if tItem == nil then
		return false
	end
	if not tItem:CanSalvage() then
		return false
	end
	if tItem:GetItemId() == self.tFilterOptions.tItemBeingSalvaged then
		return false
	end
	if self.tFilterOptions.tQualityFlags[tItem:GetItemQuality()] then
		return false
	end
	if self.tFilterOptions.bDecorations then
		return false
	end
	if self.tFilterOptions.bCostumes then
		return false
	end
	if self.tFilterOptions.tItemsIgnored[tItem:GetItemId()] then
		return false
	end
	return true
end

function Scrappy:OnSalvItem( wndHandler, wndControl )
	self.tFilterOptions.tItemBeingSalvaged = wndControl:GetData()
	self:RedrawSalvList()
end

function Scrappy:IgnoreItem( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tItemsIgnored[wndControl:GetData()] = true
	self:RedrawSalvList()
end

function Scrappy:DestroySalvList()
	if self.tSalvList == nil then
		return
	end
	for i, wnd in ipairs(self.tSalvList) do
		wnd:Destroy()
	end
	self.tSalvList = {}
end

function Scrappy:ShowFilterOptions()
	self.wndFilterOptions:Show(true)
end

function Scrappy:HideFilterOptions()
	self.wndFilterOptions:Show(false)
end

function Scrappy:OnClose()
	self.wndMain:Close()
end


---------------------------------------------------------------------------------------------------
-- FilterOptions Functions
---------------------------------------------------------------------------------------------------

function Scrappy:HideInferior( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Inferior]  = true
	self:RedrawSalvList()
end

function Scrappy:ShowInferior( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Inferior]  = false
	self:RedrawSalvList()
end

function Scrappy:HideAverage( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Average]   = true
	self:RedrawSalvList()
end

function Scrappy:ShowAverage( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Average]   = false
	self:RedrawSalvList()
end

function Scrappy:HideGood( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Good]      = true
	self:RedrawSalvList()
end

function Scrappy:ShowGood( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Good]      = false
	self:RedrawSalvList()
end

function Scrappy:HideExcellent( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Excellent] = true
	self:RedrawSalvList()
end

function Scrappy:ShowExcellent( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Excellent] = false
	self:RedrawSalvList()
end

function Scrappy:HideSuperb( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Superb]    = true
	self:RedrawSalvList()
end

function Scrappy:ShowSuperb( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Superb]    = false
	self:RedrawSalvList()
end

function Scrappy:HideLegendary( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Legendary] = true
	self:RedrawSalvList()
end

function Scrappy:ShowLegendary( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Legendary] = false
	self:RedrawSalvList()
end

function Scrappy:HideArtifact( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Artifact]  = true
	self:RedrawSalvList()
end

function Scrappy:ShowArtifact( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tQualityFlags[Item.CodeEnumItemQuality.Artifact]  = false
	self:RedrawSalvList()
end

function Scrappy:HideDecorations( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.bDecorations = true
	self:RedrawSalvList()
end

function Scrappy:ShowDecorations( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.bDecorations = false
	self:RedrawSalvList()
end

function Scrappy:HideCostumes( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.bCostumes = true
	self:RedrawSalvList()
end

function Scrappy:ShowCostumes( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.bCostumes = false
	self:RedrawSalvList()
end

function Scrappy:ClearIgnoreList( wndHandler, wndControl, eMouseButton )
	self.tFilterOptions.tItemsIgnored = {}
	self:RedrawSalvList()
end
-----------------------------------------------------------------------------------------------
-- Scrappy Instance
-----------------------------------------------------------------------------------------------
local ScrappyInst = Scrappy:new()
ScrappyInst:Init()
