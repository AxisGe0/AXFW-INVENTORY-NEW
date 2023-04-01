QBCore = exports['qb-core']:GetCoreObject()
function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
	local loadedInventory = {}
    local missingItems = {}

    if not inventory then return loadedInventory end

	inventory = json.decode(inventory)
	if table.type(inventory) == "empty" then return loadedInventory end

	for _, item in pairs(inventory) do
		if item then
			local itemInfo = QBCore.Shared.Items[item.name:lower()]
			if itemInfo then
				loadedInventory[item.slot] = {
					name = itemInfo['name'],
					amount = item.amount,
					info = item.info or '',
					label = itemInfo['label'],
					description = itemInfo['description'] or '',
					weight = itemInfo['weight'],
					type = itemInfo['type'],
					unique = itemInfo['unique'],
					useable = itemInfo['useable'],
					image = itemInfo['image'],
					shouldClose = itemInfo['shouldClose'],
					slot = item.slot,
					combinable = itemInfo['combinable']
				}
			else
				missingItems[#missingItems + 1] = item.name:lower()
			end
		end
	end

    if #missingItems > 0 then
        print(("The following items were removed for player %s as they no longer exist"):format(GetPlayerName(source)))
    end

    return loadedInventory
end

exports("LoadInventory", LoadInventory)

---Saves the inventory for the player with the provided source or PlayerData is they're offline
---@param source number | table Source of the player, if offline, then provide the PlayerData in this argument
---@param offline boolean Is the player offline or not, if true, it will expect a table in source
function SaveInventory(source, offline)
	local PlayerData
	if not offline then
		local Player = QBCore.Functions.GetPlayer(source)

		if not Player then return end

		PlayerData = Player.PlayerData
	else
		PlayerData = source -- for offline users, the playerdata gets sent over the source variable
	end

    local items = PlayerData.items
    local ItemsJson = {}
    if items and table.type(items) ~= "empty" then
        for slot, item in pairs(items) do
            if items[slot] then
                ItemsJson[#ItemsJson+1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot,
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(ItemsJson), PlayerData.citizenid })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end

exports("SaveInventory", SaveInventory)

---Gets the totalweight of the items provided
---@param items { [number]: { amount: number, weight: number } } Table of items, usually the inventory table of the player
---@return number weight Total weight of param items
function GetTotalWeight(items)
	local weight = 0
    if not items then return 0 end
    for _, item in pairs(items) do
        weight += item.weight * item.amount
    end
    return tonumber(weight)
end

exports("GetTotalWeight", GetTotalWeight)

---Gets the slots that the provided item is in
---@param items { [number]: { name: string, amount: number, info?: table, label: string, description: string, weight: number, type: string, unique: boolean, useable: boolean, image: string, shouldClose: boolean, slot: number, combinable: table } } Table of items, usually the inventory table of the player
---@param itemName string Name of the item to the get the slots from
---@return number[] slotsFound Array of slots that were found for the item
function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound+1] = slot
        end
    end
    return slotsFound
end

exports("GetSlotsByItem", GetSlotsByItem)

---Get the first slot where the item is located
---@param items { [number]: { name: string, amount: number, info?: table, label: string, description: string, weight: number, type: string, unique: boolean, useable: boolean, image: string, shouldClose: boolean, slot: number, combinable: table } } Table of items, usually the inventory table of the player
---@param itemName string Name of the item to the get the slot from
---@return number | nil slot If found it returns a number representing the slot, otherwise it sends nil
function GetFirstSlotByItem(items, itemName)
    if not items then return nil end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end

exports("GetFirstSlotByItem", GetFirstSlotByItem)

---Add an item to the inventory of the player
---@param source number The source of the player
---@param item string The item to add to the inventory
---@param amount? number The amount of the item to add
---@param slot? number The slot to add the item to
---@param info? table Extra info to add onto the item to use whenever you get the item
---@return boolean success Returns true if the item was added, false it the item couldn't be added
function AddItem(source, item, amount, slot, info)
	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return false end

	local totalWeight = GetTotalWeight(Player.PlayerData.items)
	local itemInfo = QBCore.Shared.Items[item:lower()]
	if not itemInfo and not Player.Offline then
		QBCore.Functions.Notify(source, "Item does not exist", 'error')
		return false
	end

	amount = tonumber(amount) or 1
	slot = tonumber(slot) or GetFirstSlotByItem(Player.PlayerData.items, item)
	info = info or {}

	if itemInfo['type'] == 'weapon' then
		info.serie = info.serie or tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
		info.quality = info.quality or 100
	end
	if (totalWeight + (itemInfo['weight'] * amount)) <= 120000 then
		if (slot and Player.PlayerData.items[slot]) and (Player.PlayerData.items[slot].name:lower() == item:lower()) and (itemInfo['type'] == 'item' and not itemInfo['unique']) then
			Player.PlayerData.items[slot].amount = Player.PlayerData.items[slot].amount + amount
			Player.Functions.SetPlayerData("items", Player.PlayerData.items)

			if Player.Offline then return true end

			TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)

			return true
		elseif not itemInfo['unique'] and slot or slot and Player.PlayerData.items[slot] == nil then
			Player.PlayerData.items[slot] = { name = itemInfo['name'], amount = amount, info = info or '', label = itemInfo['label'], description = itemInfo['description'] or '', weight = itemInfo['weight'], type = itemInfo['type'], unique = itemInfo['unique'], useable = itemInfo['useable'], image = itemInfo['image'], shouldClose = itemInfo['shouldClose'], slot = slot, combinable = itemInfo['combinable'] }
			Player.Functions.SetPlayerData("items", Player.PlayerData.items)

			if Player.Offline then return true end

			TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)

			return true
		elseif itemInfo['unique'] or (not slot or slot == nil) or itemInfo['type'] == 'weapon' then
			for i = 1, 66, 1 do
				if Player.PlayerData.items[i] == nil then
					Player.PlayerData.items[i] = { name = itemInfo['name'], amount = amount, info = info or '', label = itemInfo['label'], description = itemInfo['description'] or '', weight = itemInfo['weight'], type = itemInfo['type'], unique = itemInfo['unique'], useable = itemInfo['useable'], image = itemInfo['image'], shouldClose = itemInfo['shouldClose'], slot = i, combinable = itemInfo['combinable'] }
					Player.Functions.SetPlayerData("items", Player.PlayerData.items)

					if Player.Offline then return true end

					TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. i .. '], itemname: ' .. Player.PlayerData.items[i].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[i].amount)

					return true
				end
			end
		end
	elseif not Player.Offline then
		QBCore.Functions.Notify(source, "Inventory too full", 'error')
	end
	return false
end

exports("AddItem", AddItem)

---Remove an item from the inventory of the player
---@param source number The source of the player
---@param item string The item to remove from the inventory
---@param amount? number The amount of the item to remove
---@param slot? number The slot to remove the item from
---@return boolean success Returns true if the item was remove, false it the item couldn't be removed
function RemoveItem(source, item, amount, slot)
	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return false end

	amount = tonumber(amount) or 1
	slot = tonumber(slot)

	if slot then
		if Player.PlayerData.items[slot].amount > amount then
			Player.PlayerData.items[slot].amount = Player.PlayerData.items[slot].amount - amount
			Player.Functions.SetPlayerData("items", Player.PlayerData.items)

			if not Player.Offline then
				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', removed amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)
			end

			return true
		elseif Player.PlayerData.items[slot].amount == amount then
			Player.PlayerData.items[slot] = nil
			Player.Functions.SetPlayerData("items", Player.PlayerData.items)

			if Player.Offline then return true end

			TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. slot .. '], itemname: ' .. item .. ', removed amount: ' .. amount .. ', item removed')

			return true
		end
	else
		local slots = GetSlotsByItem(Player.PlayerData.items, item)
		local amountToRemove = amount

		if not slots then return false end

		for _, _slot in pairs(slots) do
			if Player.PlayerData.items[_slot].amount > amountToRemove then
				Player.PlayerData.items[_slot].amount = Player.PlayerData.items[_slot].amount - amountToRemove
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)

				if not Player.Offline then
					TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. _slot .. '], itemname: ' .. Player.PlayerData.items[_slot].name .. ', removed amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[_slot].amount)
				end

				return true
			elseif Player.PlayerData.items[_slot].amount == amountToRemove then
				Player.PlayerData.items[_slot] = nil
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)

				if Player.Offline then return true end

				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. _slot .. '], itemname: ' .. item .. ', removed amount: ' .. amount .. ', item removed')

				return true
			end
		end
	end
	return false
end

exports("RemoveItem", RemoveItem)

---Get the item with the slot
---@param source number The source of the player to get the item from the slot
---@param slot number The slot to get the item from
---@return { name: string, amount: number, info?: table, label: string, description: string, weight: number, type: string, unique: boolean, useable: boolean, image: string, shouldClose: boolean, slot: number, combinable: table } | nil item Returns the item table, if there is no item in the slot, it will return nil
function GetItemBySlot(source, slot)
	local Player = QBCore.Functions.GetPlayer(source)
	slot = tonumber(slot)
	return Player.PlayerData.items[slot]
end

exports("GetItemBySlot", GetItemBySlot)

---Get the item from the inventory of the player with the provided source by the name of the item
---@param source number The source of the player
---@param item string The name of the item to get
---@return { name: string, amount: number, info?: table, label: string, description: string, weight: number, type: string, unique: boolean, useable: boolean, image: string, shouldClose: boolean, slot: number, combinable: table } | nil item Returns the item table, if the item wasn't found, it will return nil
function GetItemByName(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	item = tostring(item):lower()
	local slot = GetFirstSlotByItem(Player.PlayerData.items, item)
	return Player.PlayerData.items[slot]
end

exports("GetItemByName", GetItemByName)

---Get the item from the inventory of the player with the provided source by the name of the item in an array for all slots that the item is in
---@param source number The source of the player
---@param item string The name of the item to get
---@return { name: string, amount: number, info?: table, label: string, description: string, weight: number, type: string, unique: boolean, useable: boolean, image: string, shouldClose: boolean, slot: number, combinable: table }[] item Returns an array of the item tables found, if the item wasn't found, it will return an empty table
function GetItemsByName(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	item = tostring(item):lower()
	local items = {}
	local slots = GetSlotsByItem(Player.PlayerData.items, item)
	for _, slot in pairs(slots) do
		if slot then
			items[#items+1] = Player.PlayerData.items[slot]
		end
	end
	return items
end

exports("GetItemsByName", GetItemsByName)

---Clear the inventory of the player with the provided source and filter any items out of the clearing of the inventory to keep (optional)
---@param source number Source of the player to clear the inventory from
---@param filterItems? string | string[] Array of item names to keep
function ClearInventory(source, filterItems)
	local Player = QBCore.Functions.GetPlayer(source)
	local savedItemData = {}

	if filterItems then
		local filterItemsType = type(filterItems)
		if filterItemsType == "string" then
			local item = GetItemByName(source, filterItems)

			if item then
				savedItemData[item.slot] = item
			end
		elseif filterItemsType == "table" and table.type(filterItems) == "array" then
			for i = 1, #filterItems do
				local item = GetItemByName(source, filterItems[i])

				if item then
					savedItemData[item.slot] = item
				end
			end
		end
	end

	Player.Functions.SetPlayerData("items", savedItemData)

	if Player.Offline then return end

	TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** inventory cleared')
end

exports("ClearInventory", ClearInventory)

---Sets the items playerdata to the provided items param
---@param source number The source of player to set it for
---@param items { [number]: { name: string, amount: number, info?: table, label: string, description: string, weight: number, type: string, unique: boolean, useable: boolean, image: string, shouldClose: boolean, slot: number, combinable: table } } Table of items, the inventory table of the player
function SetInventory(source, items)
	local Player = QBCore.Functions.GetPlayer(source)

	Player.Functions.SetPlayerData("items", items)

	if Player.Offline then return end

	TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** items set: ' .. json.encode(items))
end

exports("SetInventory", SetInventory)

---Set the data of a specific item
---@param source number The source of the player to set it for
---@param itemName string Name of the item to set the data for
---@param key string Name of the data index to change
---@param val any Value to set the data to
---@return boolean success Returns true if it worked
function SetItemData(source, itemName, key, val)
	if not itemName or not key then return false end

	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return end

	local item = GetItemByName(source, itemName)

	if not item then return false end

	item[key] = val
	Player.PlayerData.items[item.slot] = item
	Player.Functions.SetPlayerData("items", Player.PlayerData.items)

	return true
end

exports("SetItemData", SetItemData)

---Checks if you have an item or not
---@param source number The source of the player to check it for
---@param items string | string[] | table<string, number> The items to check, either a string, array of strings or a key-value table of a string and number with the string representing the name of the item and the number representing the amount
---@param amount? number The amount of the item to check for, this will only have effect when items is a string or an array of strings
---@return boolean success Returns true if the player has the item
function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = #items
    local count = 0
    local kvIndex = 2
    if isTable and not isArray then
        totalItems = 0
        for _ in pairs(items) do totalItems += 1 end
        kvIndex = 1
    end
    if isTable then
        for k, v in pairs(items) do
            local itemKV = {k, v}
            local item = GetItemByName(source, itemKV[kvIndex])
            if item and ((amount and item.amount >= amount) or (not isArray and item.amount >= v) or (not amount and isArray)) then
                count += 1
            end
        end
        if count == totalItems then
            return true
        end
    else -- Single item as string
        local item = GetItemByName(source, items)
        if item and (not amount or (item and amount and item.amount >= amount)) then
            return true
        end
    end
    return false
end

exports("HasItem", HasItem)

---Create a usable item with a callback on use
---@param itemName string The name of the item to make usable
---@param data any
function CreateUsableItem(itemName, data)
	QBCore.Functions.CreateUseableItem(itemName, data)
end

exports("CreateUsableItem", CreateUsableItem)

---Get the usable item data for the specified item
---@param itemName string The item to get the data for
---@return any usable_item
function GetUsableItem(itemName)
	return QBCore.Functions.CanUseItem(itemName)
end

exports("GetUsableItem", GetUsableItem)

---Use an item from the QBCore.UsableItems table if a callback is present
---@param itemName string The name of the item to use
---@param ... any Arguments for the callback, this will be sent to the callback and can be used to get certain values
function UseItem(itemName, ...)
	local itemData = GetUsableItem(itemName)
	local callback = type(itemData) == 'table' and (rawget(itemData, '__cfx_functionReference') and itemData or itemData.cb or itemData.callback) or type(itemData) == 'function' and itemData
	if not callback then return end
	callback(...)
end

exports("UseItem", UseItem)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "AddItem", function(item, amount, slot, info)
		return AddItem(Player.PlayerData.source, item, amount, slot, info)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "RemoveItem", function(item, amount, slot)
		return RemoveItem(Player.PlayerData.source, item, amount, slot)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "GetItemBySlot", function(slot)
		return GetItemBySlot(Player.PlayerData.source, slot)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "GetItemByName", function(item)
		return GetItemByName(Player.PlayerData.source, item)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "GetItemsByName", function(item)
		return GetItemsByName(Player.PlayerData.source, item)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "ClearInventory", function(filterItems)
		ClearInventory(Player.PlayerData.source, filterItems)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "SetInventory", function(items)
		SetInventory(Player.PlayerData.source, items)
	end)
end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end
	local Players = QBCore.Functions.GetQBPlayers()
	for k in pairs(Players) do
		QBCore.Functions.AddPlayerMethod(k, "AddItem", function(item, amount, slot, info)
			return AddItem(k, item, amount, slot, info)
		end)

		QBCore.Functions.AddPlayerMethod(k, "RemoveItem", function(item, amount, slot)
			return RemoveItem(k, item, amount, slot)
		end)

		QBCore.Functions.AddPlayerMethod(k, "GetItemBySlot", function(slot)
			return GetItemBySlot(k, slot)
		end)

		QBCore.Functions.AddPlayerMethod(k, "GetItemByName", function(item)
			return GetItemByName(k, item)
		end)

		QBCore.Functions.AddPlayerMethod(k, "GetItemsByName", function(item)
			return GetItemsByName(k, item)
		end)

		QBCore.Functions.AddPlayerMethod(k, "ClearInventory", function(filterItems)
			ClearInventory(k, filterItems)
		end)

		QBCore.Functions.AddPlayerMethod(k, "SetInventory", function(items)
			SetInventory(k, items)
		end)
	end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end -- Safety check if the event was not called from the server.
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('inventory:server:UseItemSlot', function(slot)
	local src = source
	local itemData = GetItemBySlot(src, slot)
	if not itemData then return end
	local itemInfo = QBCore.Shared.Items[itemData.name]
	if itemData.type == "weapon" then
		TriggerClientEvent("inventory:client:UseWeapon", src, itemData, itemData.info.quality and itemData.info.quality > 0)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	elseif itemData.useable then
		UseItem(itemData.name, src, itemData)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	end
end)

RegisterNetEvent('inventory:server:UseItem', function(inventory, item)
	local src = source
	if inventory ~= "player" and inventory ~= "hotbar" then return end
	local itemData = GetItemBySlot(src, item.slot)
	if not itemData then return end
	local itemInfo = QBCore.Shared.Items[itemData.name]
	if itemData.type == "weapon" then
		TriggerClientEvent("inventory:client:UseWeapon", src, itemData, itemData.info.quality and itemData.info.quality > 0)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	else
		UseItem(itemData.name, src, itemData)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	end
end)