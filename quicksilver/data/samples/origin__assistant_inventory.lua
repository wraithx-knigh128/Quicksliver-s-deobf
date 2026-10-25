--[[
    InventoryService
    Description: Manages player inventories with validation and safe persistence.
    Features:
        - Add and remove items with quantity validation
        - Persist data using DataStoreService with retry logic
    Usage: require this module from a server Script and call InventoryService.new(player).
    Version: 1.0.0
]]

-- Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Configuration
local MAX_RETRIES = 3
local RETRY_DELAY_SECONDS = 2

local InventoryService = {}
InventoryService.__index = InventoryService

---@param player Player The player who owns this inventory.
---@return InventoryService
function InventoryService.new(player)
    -- Create a new inventory table for the player.
    local self = setmetatable({}, InventoryService)
    self.player = player
    self.items = {}
    print("✅ [InventoryService] Created inventory for " .. player.Name)
    return self
end

---@param itemName string The name of the item to add.
---@param quantity number The amount to add.
---@return boolean success
function InventoryService:addItem(itemName, quantity)
    -- Validate the item name before adding it.
    if type(itemName) ~= "string" then
        warn("[InventoryService] Invalid item name")
        return false
    end
    -- Validate the quantity before adding it.
    if type(quantity) ~= "number" or quantity <= 0 then
        warn("[InventoryService] Invalid quantity")
        return false
    end
    -- Add the quantity to the current amount.
    local currentQuantity = self.items[itemName] or 0
    self.items[itemName] = currentQuantity + quantity
    return true
end

---@param itemName string The name of the item to remove.
---@param quantity number The amount to remove.
---@return boolean success
function InventoryService:removeItem(itemName, quantity)
    -- Check that the item exists in the inventory.
    local currentQuantity = self.items[itemName]
    if not currentQuantity then
        warn("[InventoryService] Item not found: " .. tostring(itemName))
        return false
    end
    -- Remove the quantity from the current amount.
    self.items[itemName] = math.max(0, currentQuantity - quantity)
    return true
end

---@return boolean success
function InventoryService:save()
    -- Attempt to save the inventory with retry logic.
    local store = DataStoreService:GetDataStore("Inventories")
    for attempt = 1, MAX_RETRIES do
        local success, errorMessage = pcall(function()
            store:SetAsync(tostring(self.player.UserId), self.items)
        end)
        if success then
            print("✅ [InventoryService] Saved inventory for " .. self.player.Name)
            return true
        end
        warn("[InventoryService] Save failed (attempt " .. attempt .. "): " .. tostring(errorMessage))
        task.wait(RETRY_DELAY_SECONDS)
    end
    return false
end

-- Example usage:
-- local inventory = InventoryService.new(Players.LocalPlayer)
-- inventory:addItem("Sword", 1)

return InventoryService
