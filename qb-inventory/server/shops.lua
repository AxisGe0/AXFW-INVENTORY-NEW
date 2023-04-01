RegisterNetEvent('ax-ui:GiveShopItems')
AddEventHandler('ax-ui:GiveShopItems',function(items)
    local Player = QBCore.Functions.GetPlayer(source)
    for k,v in pairs(items) do
        v.amount = tonumber(v.amount)
        if v.amount <0 then return end
        if (v.price*v.amount) <= Player.PlayerData.money.cash then 
            Player.Functions.RemoveMoney('cash',v.price*v.amount)
        else
            TriggerClientEvent('QBCore:Notify',source,'You do not have enough cash in your pocket', 'error')
            return 
        end
        if v ~= 0 then
            Player.Functions.AddItem(k,v.amount)
        end
    end
    
    if json.encode(items) == '[]' then 
        TriggerClientEvent('QBCore:Notify',source,'Make sure to add items in your cart before checking out, Try again!', 'error')
    else
        TriggerClientEvent('QBCore:Notify',source,'You have successfully checked out, Visit again!', 'success')
    end
end)