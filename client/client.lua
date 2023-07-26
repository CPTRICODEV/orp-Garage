local garages = {}
local impounds = {}

local currentGarage = nil
local currentImpound = nil
local jobBlips = {}

local ped = nil

local function getGarageLabel(name)
    for i = 1, #Config.Garages do
        local garage = Config.Garages[i]
        if garage.zone.name == name then return garage.label end
    end
end

local function isVehicleInGarage(garage, stored)
    if Config.SplitGarages then
        if (stored == true or stored == 1) and currentGarage.zone.name == garage then
            return Locale('in_garage'), true
        else
            if (stored == false or stored == 0) then
                return Locale('not_in_garage'), false
            else
                return getGarageLabel(garage), false
            end
        end
    else
        if (stored == true or stored == 1) then
            return Locale('in_garage'), true
        else
            return Locale('not_in_garage'), false
        end
    end
end

local function spawnVehicle(data, spawn, price)
    lib.requestModel(data.vehicle.model)
    TriggerServerEvent('orp_garage:SpawnVehicle', data.vehicle.model, data.vehicle.plate, vector3(spawn.x, spawn.y, spawn.z-1), type(spawn) == 'vector4' and spawn.w or spawn.h, price)
end

local function isInsideZone(type, entity)
    local entityCoords = GetEntityCoords(entity)
    if type == 'impound' then
        for k, v in pairs(impounds) do
            if impounds[k]:isPointInside(entityCoords) then
                currentImpound = Config.Impounds[k]
                return true
            end
            if k == #impounds then return false end
        end
    else
        for k, v in pairs(garages) do
            if garages[k]:isPointInside(entityCoords) then
                currentGarage = Config.Garages[k]
                return true
            end
            if k == #garages then return false end
        end
    end
end

local function ImpoundBlips(coords, type, label, blipOptions)
    if blipOptions == false then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipOptions?.sprite or 285)
    SetBlipScale(blip, blipOptions?.scale or 0.8)
    SetBlipColour(blip, blipOptions?.colour and blipOptions.colour or type == 'car' and Config.BlipColors.Car or type == 'boat' and Config.BlipColors.Boat or Config.BlipColors.Aircraft)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label or Locale(type) .. ' ' .. Locale('impound_lot'))
    EndTextCommandSetBlipName(blip)
end


local function GarageBlips(coords, type, label, job, blipOptions)
    if blipOptions == false then return end
    if job then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipOptions?.sprite or 357)
    SetBlipScale(blip, blipOptions?.scale or 0.8)
    SetBlipColour(blip, blipOptions?.colour ~= nil and blipOptions.colour or type == 'car' and Config.BlipColors.Car or type == 'boat' and Config.BlipColors.Boat or Config.BlipColors.Aircraft)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.SplitGarages == true and label or Locale(type) .. ' ' .. Locale('garage'))
    EndTextCommandSetBlipName(blip)
end

local function JobGarageBlip(garage)
    local index = #jobBlips + 1
    local blip = AddBlipForCoord(garage.pedCoords.x, garage.pedCoords.y, garage.pedCoords.z)
    jobBlips[index] = blip
    SetBlipSprite(jobBlips[index], 357)
    SetBlipScale(jobBlips[index], 0.8)
    SetBlipColour(jobBlips[index], garage.type == 'car' and Config.BlipColors.Car or garage.type == 'boat' and Config.BlipColors.Boat or Config.BlipColors.Aircraft)
    SetBlipAsShortRange(jobBlips[index], true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.SplitGarages == true and garage.label or Locale(garage.type) .. ' ' .. Locale('garage'))
    EndTextCommandSetBlipName(jobBlips[index])
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'open_parking',
        icon = 'fa-solid fa-parking',
        label = Locale('store_vehicle'),
        event = 'orp_garage:StoreVehicle',
        canInteract = function(entity)
            hasChecked = false
            if isInsideZone('garage', entity) and not hasChecked then
                hasChecked = true
                return true
            end
        end,
        distance = 2.5
    }
})

local garagePeds = {
    [Config.DefaultGaragePed] = true,
}
for k,v in pairs(Config.Garages) do
    
    GarageBlips(vector3(v.pedCoords.x, v.pedCoords.y, v.pedCoords.z), v.type, v.label, v.job, v.blip)

    garages[k] = BoxZone:Create(
        vector3(v.zone.x, v.zone.y, v.zone.z),
        v.zone.l, v.zone.w, {
            name = v.zone.name,
            heading = v.zone.h,
            debugPoly = false,
            minZ = v.zone.minZ,
            maxZ = v.zone.maxZ
        }
    )

    garages[k].type = v.type
    garages[k].label = v.label
    
    if v.ped then 
        garagePeds[v.ped] = true
    end
end

garages[k]:onPlayerInOut(function(isPointInside, point)
    local model = v.ped or Config.DefaultGaragePed
    local heading = type(v.pedCoords) == 'vector4' and v.pedCoords.w or v.pedCoords.h
    if isPointInside then

        lib.requestModel(model)

        ped = CreatePed(0, model, v.pedCoords.x, v.pedCoords.y, v.pedCoords.z, heading, false, true)
        SetEntityAlpha(ped, 0, false)
        Wait(50)
        SetEntityAlpha(ped, 255, false)

        SetPedFleeAttributes(ped, 2)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdollFromPlayerImpact(ped, false)
        SetPedDiesWhenInjured(ped, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetPedCanPlayAmbientAnims(ped, false)
    else
        DeletePed(ped)
    end DeletePed(ped)
end)


local pedsArr = {}
for ped, _ in pairs(garagePeds) do pedsArr[#pedsArr+1] = ped end
exports.ox_target:addModel(pedsArr, {
    {
        name = 'open_garage',
        icon = 'fa-solid fa-warehouse',
        label = Locale('take_out_vehicle'),
        event = 'orp_garage:GetOwnedVehicles',
        canInteract = function(entity)
            hasChecked = false
            if isInsideZone('garage', entity) and not hasChecked then
                hasChecked = true
                local requiredGroup = currentGarage.job
                local playerJob = ESX.PlayerData.job
                if not requiredGroup then return true end
                if type(requiredGroup) == 'string' then
                    if not requiredGroup == playerJob.name then return false end
                else
                    for job, grade in pairs(requiredGroup) do
                        if playerJob.name == job and playerJob.grade >= grade then return true end
                    end
                    return false
                end
            end
        end,
        distance = 2.5
    }
})

local impoundPeds = {
    [Config.DefaultImpoundPed] = true
}
for k, v in pairs(Config.Impounds) do

    ImpoundBlips(vector3(v.pedCoords.x, v.pedCoords.y, v.pedCoords.z), v.type, v.label, v.blip)

    impounds[k] = BoxZone:Create(
        vector3(v.zone.x, v.zone.y, v.zone.z),
        v.zone.l, v.zone.w, {
            name = v.zone.name,
            heading = v.zone.h,
            debugPoly = false,
            minZ = v.zone.minZ,
            maxZ = v.zone.maxZ
        }
    )

    impounds[k].type = v.type

    if v.ped then
        impoundPeds[v.ped] = true
    end

    impounds[k]:onPlayerInOut(function(isPointInside, point)
        local model = v.ped or Config.DefaultImpoundPed
        local heading = type(v.pedCoords) == 'vector4' and v.pedCoords.w or v.pedCoords.h
        if isPointInside then

            lib.requestModel(model)

            ped = CreatePed(0, model, v.pedCoords.x, v.pedCoords.y, v.pedCoords.z, heading, false, true)
            SetEntityAlpha(ped, 0, false)
            Wait(50)
            SetEntityAlpha(ped, 255, false)

            SetPedFleeAttributes(ped, 2)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedCanRagdollFromPlayerImpact(ped, false)
            SetPedDiesWhenInjured(ped, false)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetPedCanPlayAmbientAnims(ped, false)
        else
            DeletePed(ped)
        end
    end)
end

local pedsArr = {}
for ped, _ in pairs(impoundPeds) do
    pedsArr[#pedsArr+1] = ped
end
exports.ox_target:addModel(pedsArr, {
    {
        name = 'open_impound',
        icon = 'fa-solid fa-key',
        label = Locale('access_impound'),
        event = 'orp_garage:GetImpoundedVehicles',
        canInteract = function(entity)
            hasChecked = false
            if isInsideZone('impound', entity) and not hasChecked then
                hasChecked = true
                return true
            end
        end,
        distance = 2.5
    }
})

AddStateBagChangeHandler('vehicleData', nil, function(bagName, key, value, _unused, replicated)
    if not value then return end
    local entNet = bagName:gsub('entity:', '')
    local timer = GetGameTimer()
    while not NetworkDoesEntityExistWithNetworkId(tonumber(entNet)) do
	    Wait(0)
	    if GetGameTimer() - timer > 10000 then
	        return
	    end
    end
    local vehicle = NetToVeh(tonumber(entNet))
    local timer = GetGameTimer()
    while NetworkGetEntityOwner(vehicle) ~= PlayerId() do
        Wait(0)
	    if GetGameTimer() - timer > 10000 then
	        return
	    end
    end
    lib.setVehicleProperties(vehicle, json.decode(value.vehicle))
    TriggerServerEvent('orp_garage:ChangeStored', value.plate)
    Entity(vehicle).state:set('vehicleData', nil, true)
end)

RegisterNetEvent('orp_garage:GetImpoundedVehicles', function()
    local vehicles = lib.callback.await('orp_garage:GetImpound', false, currentImpound.type)
    local options = {}

    if not vehicles or #vehicles == 0 then
        lib.registerContext({
            id = 'orp_garage:ImpoundMenu',
            title = currentImpound.label or Locale(currentImpound.type) .. ' ' .. Locale('impound'),
            options = {
                [Locale('no_vehicles_impound')] = {}
            }
        })

        return lib.showContext('orp_garage:ImpoundMenu')
    end

    for i = 1, #vehicles do
        local data = vehicles[i]
        local vehicleMake = GetLabelText(GetMakeNameFromVehicleModel(data.vehicle.model))
        local vehicleModel = GetLabelText(GetDisplayNameFromVehicleModel(data.vehicle.model))
        local vehicleTitle = vehicleMake .. ' ' .. vehicleModel

        options[i] = {
            title = vehicleTitle,
            event = 'orp_garage:ImpoundVehicleMenu',
            arrow = true,
            description = Locale('plate') .. ': ' .. data.plate, -- Single item so no need to use metadata
            args = {
                name = vehicleTitle,
                plate = data.plate,
                model = vehicleModel,
                vehicle = data.vehicle,
                price = Config.ImpoundPrices[GetVehicleClassFromName(vehicleModel)]
            }
        }
    end
    lib.registerContext({
        id = 'orp_garage:ImpoundMenu',
        title = currentImpound.label or Locale(currentImpound.type) .. ' ' .. Locale('impound'),
        options = options
    })

    lib.showContext('orp_garage:ImpoundMenu')
end)

RegisterNetEvent('orp_garage:GetOwnedVehicles', function()
    local vehicles = lib.callback.await('orp_garage:GetVehicles', false, currentGarage.type, currentGarage.job)
    local options = {}

    if not vehicles then
        lib.registerContext({
            id = 'orp_garage:GarageMenu',
            title = Config.SplitGarages == true and currentGarage.label or Locale(currentGarage.type) .. ' ' .. Locale('garage'),
            options = {
                [Locale('no_vehicles_garage')] = {}
            }
        })

        return lib.showContext('orp_garage:GarageMenu')
    end

    for i = 1, #vehicles do
        local data = vehicles[i]
        local vehicleMake = GetLabelText(GetMakeNameFromVehicleModel(data.vehicle.model))
        local vehicleModel = GetLabelText(GetDisplayNameFromVehicleModel(data.vehicle.model))
        local vehicleTitle = vehicleMake .. ' ' .. vehicleModel
        local locale, stored = isVehicleInGarage(data.garage, data.stored)
        options[i] = {
            title = vehicleTitle,
            event = stored and 'orp_garage:VehicleMenu' or nil,
            arrow = stored and true or false,
            args = {name = vehicleTitle, plate = data.plate, model = vehicleModel, vehicle = data.vehicle},
            metadata = {
                [Locale('plate')] = data.plate,
                [Locale("status")] = locale
            }
        }
    end

    lib.registerContext({
        id = 'orp_garage:GarageMenu',
        title = Config.SplitGarages == true and currentGarage.label or Locale(currentGarage.type) .. ' ' .. Locale('garage'),
        options = options
    })

    lib.showContext('orp_garage:GarageMenu')
end)

RegisterNetEvent('orp_garage:ImpoundVehicleMenu', function(data)
    lib.registerContext({
        id = 'orp_garage:ImpoundVehicleMenu',
        title = data.name,
        menu = 'orp_garage:ImpoundMenu',
        options = {
            [Locale('take_out_vehicle_impound')] = {
                metadata = {
                    [Locale('plate')] = data.plate,
                    [Locale('price')] = Locale('$') .. data.price
                },
                event = 'orp_garage:RequestVehicle',
                args = {
                    vehicle = data.vehicle,
                    price = data.price,
                    type = 'impound'
                }
            }
        }
    })

    lib.showContext('orp_garage:ImpoundVehicleMenu')
end)

RegisterNetEvent('orp_garage:VehicleMenu', function(data)
    lib.registerContext({
        id = 'orp_garage:VehicleMenu',
        title = data.name,
        menu = 'orp_garage:GarageMenu',
        options = {
            [Locale('take_out_vehicle')] = {
                event = 'orp_garage:RequestVehicle',
                args = {
                    vehicle = data.vehicle,
                    type = 'garage'
                }
            }
        }
    })

    lib.showContext('orp_garage:VehicleMenu')
end)

RegisterNetEvent('orp_garage:RequestVehicle', function(data)
    local spawn = nil

    if data.type == 'garage' then
        spawn = currentGarage.spawns
    else
        spawn = currentImpound.spawns
    end

    for i = 1, #spawn do
        if ESX.Game.IsSpawnPointClear(vector3(spawn[i].x, spawn[i].y, spawn[i].z), 1.0) then
            return spawnVehicle(data, spawn[i], data.type == 'impound' and data.price or nil)
        end
        if i == #spawn then ESX.ShowNotification(Locale('no_spawn_spots')) end
    end
end)

RegisterNetEvent('orp_garage:StoreVehicle', function(target)
    local vehicle = target.entity
    local vehPlate = GetVehicleNumberPlateText(vehicle)
    local vehProps = lib.getVehicleProperties(vehicle)

    local doesOwn, isInvalid = lib.callback.await('orp_garage:CheckOwnership', false, vehPlate, vehProps.model, currentGarage)
    if doesOwn then
       if isInvalid then return ESX.ShowNotification(Locale('garage_cant_store')) end
        TriggerServerEvent('orp_garage:SaveVehicle', vehProps, vehPlate, VehToNet(vehicle), currentGarage.zone.name)
    else
        ESX.ShowNotification(Locale('no_ownership'))
    end

end)

RegisterNetEvent('esx:setJob', function(job)
    for i = 1, #jobBlips do RemoveBlip(jobBlips[i]) end
    for i = 1, #Config.Garages do
        local garage = Config.Garages[i]
        if garage.job then
            if type(garage.job) == 'string' then
                if garage.job == job.name then JobGarageBlip(garage) end
            else
                for jobName, _ in pairs(garage.job) do
                    if jobName == job.name then
                        JobGarageBlip(garage)
                        break
                    end
                end
            end
        end
    end
end)