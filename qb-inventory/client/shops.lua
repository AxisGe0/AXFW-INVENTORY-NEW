RegisterNetEvent('ax-inv:OpenShop')
AddEventHandler('ax-inv:OpenShop',function(items)
    for k,v in pairs(items.items) do 
        v.label = QBCore.Shared.Items[v.name].label
        v.image = QBCore.Shared.Items[v.name].image
    end
    OpenShop(items.items)
end)

OpenShop = function(items)
    SetNuiFocus(true,true)
    SendNUIMessage({
        action = 'OpenShop',
        items = items
    })
end

CloseShop = function()
    SetNuiFocus(false,false)
end

RegisterNUICallback('Closeshop',CloseShop)

RegisterNUICallback('Checkout', function(data,cb)
    TriggerServerEvent('ax-ui:GiveShopItems',data.items)
end)