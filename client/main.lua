ESX                  = nil
local FirstSpawn     = true
local LastSkin       = nil
local PlayerLoaded   = false
local cam            = nil
local isCameraActive = false
local zoomOffset     = 0.0
local camOffset      = 0.0
local heading        = 90.0

Citizen.CreateThread(function()
  while ESX == nil do
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    Citizen.Wait(0)
  end
end)

function OpenMenu(submitCb, cancelCb, restrict)

  local playerPed = GetPlayerPed(-1)

  TriggerEvent('skinchanger:getSkin', function(skin)
    LastSkin = skin
  end)

  TriggerEvent('skinchanger:getData', function(components, maxVals)

    local elements    = {}
    local _components = {}

    -- Restrict menu
    if restrict == nil then
      for i=1, #components, 1 do
        _components[i] = components[i]
      end
    else
      for i=1, #components, 1 do

        local found = false

        for j=1, #restrict, 1 do
          if components[i].name == restrict[j] then
            found = true
          end
        end

        if found then
          table.insert(_components, components[i])
        end

      end
    end

    -- Insert elements
    for i=1, #_components, 1 do

      local value       = _components[i].value
      local componentId = _components[i].componentId

      if componentId == 0 then
        value = GetPedPropIndex(playerPed,  _components[i].componentId)
      end

      local data = {
        label     = _components[i].label,
        name      = _components[i].name,
        value     = value,
        min       = _components[i].min,
        textureof = _components[i].textureof,
        zoomOffset= _components[i].zoomOffset,
        camOffset = _components[i].camOffset,
        type      = 'slider'
      }

      for k,v in pairs(maxVals) do
        if k == _components[i].name then
          data.max = v
        end
      end

      table.insert(elements, data)

    end

    CreateSkinCam()
    zoomOffset = _components[1].zoomOffset
    camOffset = _components[1].camOffset

    ESX.UI.Menu.Open(
      'default', GetCurrentResourceName(), 'skin',
      {
        title = _U('skin_menu'),
        align = 'top-right',
        elements = elements
      },
      function(data, menu)

        TriggerEvent('skinchanger:getSkin', function(skin)
          LastSkin = skin
        end)

        submitCb(data, menu)
        DeleteSkinCam()
      end, function(data, menu)
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_escape', {
			title = _U('confirm_escape'),
			align = 'top-right',
			elements = {
				{label = _U('no'),  value = 'no'},
				{label = _U('yes'), value = 'yes'}
			}
		}, function(data2, menu2)
			if data2.current.value == 'yes' then
				menu.close()
				DeleteSkinCam()
				TriggerEvent('skinchanger:loadSkin', LastSkin)
			end
			menu2.close()
		end)

		if cancelCb ~= nil then
			cancelCb(data, menu)
		end
      end,function(data, menu)
        TriggerEvent('skinchanger:getSkin', function(skin)

          zoomOffset = data.current.zoomOffset
          camOffset = data.current.camOffset

          if skin[data.current.name] ~= data.current.value then

            -- Change skin element
            TriggerEvent('skinchanger:change', data.current.name, data.current.value)

            -- Update max values
            TriggerEvent('skinchanger:getData', function(components, maxVals)

              for i=1, #elements, 1 do

                local newData = {}

                newData.max = maxVals[elements[i].name]

                if elements[i].textureof ~= nil and data.current.name == elements[i].textureof then
                  newData.value = 0
                end

                menu.update({name = elements[i].name}, newData)

              end

              menu.refresh()

            end)

          end

        end)

      end,
      function()
        DeleteSkinCam()
      end
    )

  end)

end

function CreateSkinCam()
  if not DoesCamExist(cam) then
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
  end
  SetCamActive(cam, true)
  RenderScriptCams(true, true, 500, true, true)
  isCameraActive = true
  SetCamRot(cam, 0.0, 0.0, 270.0, true)
  SetEntityHeading(playerPed, 90.0)
end

function DeleteSkinCam()
  isCameraActive = false
  SetCamActive(cam, false)
  RenderScriptCams(false, true, 500, true, true)
  cam = nil
end

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    if isCameraActive then
      DisableControlAction(2, 30, true)
      DisableControlAction(2, 31, true)
      DisableControlAction(2, 32, true)
      DisableControlAction(2, 33, true)
      DisableControlAction(2, 34, true)
      DisableControlAction(2, 35, true)

      DisableControlAction(0, 25,   true) -- Input Aim
        DisableControlAction(0, 24,   true) -- Input Attack

      local playerPed = GetPlayerPed(-1)
      local coords    = GetEntityCoords(playerPed)

      local angle = heading * math.pi / 180.0
      local theta = {
        x = math.cos(angle),
        y = math.sin(angle)
      }
      local pos = {
        x = coords.x + (zoomOffset * theta.x),
        y = coords.y + (zoomOffset * theta.y),
      }

      local angleToLook = heading - 140.0
      if angleToLook > 360 then
        angleToLook = angleToLook - 360
      elseif angleToLook < 0 then
        angleToLook = angleToLook + 360
      end
      angleToLook = angleToLook * math.pi / 180.0
      local thetaToLook = {
        x = math.cos(angleToLook),
        y = math.sin(angleToLook)
      }
      local posToLook = {
        x = coords.x + (zoomOffset * thetaToLook.x),
        y = coords.y + (zoomOffset * thetaToLook.y),
      }

      SetCamCoord(cam, pos.x, pos.y, coords.z + camOffset)
      PointCamAtCoord(cam, posToLook.x, posToLook.y, coords.z + camOffset)

      SetTextComponentFormat("STRING")
      AddTextComponentString(_U('use_rotate_view'))
      DisplayHelpTextFromStringLabel(0, 0, 0, -1)
    end
  end
end)

Citizen.CreateThread(function()
  local angle = 90
  while true do
    Citizen.Wait(0)
    if isCameraActive then
      if IsControlPressed(0, 108) then
        angle = angle - 1
      elseif IsControlPressed(0, 109) then
        angle = angle + 1
      end
      if angle > 360 then
        angle = angle - 360
      elseif angle < 0 then
        angle = angle + 360
      end
      heading = angle + 0.0
    end
  end
end)

function OpenSaveableMenu(submitCb, cancelCb, restrict)

  TriggerEvent('skinchanger:getSkin', function(skin)
    LastSkin = skin
  end)

  OpenMenu(function(data, menu)

    menu.close()

    DeleteSkinCam()

    TriggerEvent('skinchanger:getSkin', function(skin)
      -- Create Skin Database Entry with active flag
      TriggerServerEvent('esx_skin:create', skin)

      if submitCb ~= nil then
        submitCb(data, menu)
      end

    end)

  end, cancelCb, restrict)
end

AddEventHandler('playerSpawned', function()
  Citizen.CreateThread(function()
    while not PlayerLoaded do
      Citizen.Wait(0)
    end

    if FirstSpawn then
      getAndLoadActiveSkin()
      FirstSpawn = false
    end
  end)
end)

function getAndLoadActiveSkin()
  ESX.TriggerServerCallback('esx_skin:getActivePlayerSkin', function(skin, jobSkin)
      if skin == nil then
        skin = {sex = 0}
        TriggerEvent('skinchanger:loadSkin', skin)
        OpenSaveableMenu()
      else
        TriggerEvent('skinchanger:loadSkin', skin)
        LastSkin = skin
      end
    end)
end

function openSkinSelectionMenu()
  ESX.UI.Menu.CloseAll()

  local elements = {
    {label = "Create Ped", value = "create_ped"},
    {label = "Select Ped", value = "select_ped"},
  }

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'skin_changer',
    {
      title    = 'Select A Option',
      align    = 'top-right',
      elements = elements,
    },
    function(data, menu)
      menu.close()

      if(data.current.value == 'create_ped') then
        TriggerEvent('esx_skin:openSaveableMenu')
      end

      if(data.current.value == 'select_ped') then
        SelectSkinMenu()
      end
    end,
    function (data, menu)
      menu.close()
    end
 )
end

function SelectSkinMenu()
  local elements = {}
  ESX.UI.Menu.CloseAll()

  ESX.TriggerServerCallback('esx_skin:getPlayerSkins', function(skins)
    for index, skin in pairs(skins) do
      name = skin.name

      if not skin.name then
        name = "Ped #" .. index;
      end

      if skin.active then
        name = name .. " [ACTIVE]"
      end

      table.insert(elements, {label = name, value = skin.id, skinData = skin})
    end

    table.insert(elements, {label = 'Go Back', value='go_back'})

    ESX.UI.Menu.Open(
      'default', GetCurrentResourceName(), 'skin_changer_skin_list',
      {
        title    = 'Select A Ped',
        align    = 'top-right',
        elements = elements,
      },
      function(data, menu)
        menu.close()
        if data.current.value == 'go_back' then
          openSkinSelectionMenu()
        else
          loadIndividualSkinMenu(data.current.skinData, data.current.label)
        end
      end,
      function(data, menu)
        menu.close()
      end
    )

  end)

end

function loadIndividualSkinMenu(skin, skinName)
  local elements = {
    {label = "Rename Ped", value = "rename_ped"}
  }

  if not skin.active then
    table.insert(elements, {label = "Delete Ped", value = "delete_ped"})
    table.insert(elements, {label = "Make Ped Active", value = "activate_ped"})
  end

  table.insert(elements, {label = "Go Back", value = "go_back"})

  ESX.UI.Menu.CloseAll()

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'skin_changer',
    {
      title    = "Options for " .. skinName,
      align    = 'top-right',
      elements = elements,
    },
    function(data, menu)
      menu.close()

      if(data.current.value == 'activate_ped') then
        -- Load Skin on Ped
        TriggerEvent('skinchanger:loadSkin', skin.skin)

        LastSkin = skin.skin

        -- Make Skin Active
        ESX.TriggerServerCallback('esx_skin:setSkinActive', function()
          ESX.ShowNotification('You are now ' .. skinName .. '!')
        end, skin)

      end

      if(data.current.value == 'rename_ped') then
        SkinDialog(skin.id)
      end

      if(data.current.value == 'delete_ped') then
        confirmationMenu(skin, skinName)
      end

      if(data.current.value == 'go_back') then
        SelectSkinMenu()
      end

    end,
    function(data, menu)
      menu.close()
    end
  )

end

function confirmationMenu(skin, skinName)
  local elements = {
    {label = "Yes", value = "yes"},
    {label = "No", value = "no"},
  }

  ESX.UI.Menu.CloseAll()

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'skin_changer_confirmation_menu',
    {
      title    = "Are you sure you wish to delete ped " .. skinName .. "?",
      align    = 'top-right',
      elements = elements,
    },
    function(data, menu)
      menu.close()

      if(data.current.value == 'yes') then
        deleteSkin(skin.id)
      end

      if(data.current.value == 'no') then
        loadIndividualSkinMenu(skin, skinName)
      end
    end
  )
end

function SkinDialog(skinId)
  Citizen.CreateThread(function()
    DisplayOnscreenKeyboard(false, "", "", "", "", "", "", 20)

    while true do
      if (UpdateOnscreenKeyboard() == 1) then
        local label = GetOnscreenKeyboardResult()

        if (string.len(label) > 0) then
            SkinSetLabel(skinId, label)
            break
          else
            DisplayOnscreenKeyboard(false, "", "", "", "", "", "", 20)
          end
      elseif (UpdateOnscreenKeyboard() == 2) then
        break
      end

      Citizen.Wait(0)
    end
  end)
end

function SkinSetLabel(skinId, label)
  ESX.TriggerServerCallback('esx_skin:setSkinLabel', function()
    ESX.ShowNotification('Your ped has been renamed!')
    SelectSkinMenu()
  end, skinId, label)

end

function deleteSkin(skinId)
  ESX.TriggerServerCallback('esx_skin:deleteSkin', function()
    ESX.ShowNotification('Your ped has been deleted!')
    SelectSkinMenu()
  end, skinId)
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerLoaded = true
end)

AddEventHandler('esx_skin:getLastSkin', function(cb)
  cb(LastSkin)
end)

AddEventHandler('esx_skin:setLastSkin', function(skin)
  LastSkin = skin
end)

RegisterNetEvent('esx_skin:openMenu')
AddEventHandler('esx_skin:openMenu', function(submitCb, cancelCb)
  OpenMenu(submitCb, cancelCb, nil)
end)

RegisterNetEvent('esx_skin:openRestrictedMenu')
AddEventHandler('esx_skin:openRestrictedMenu', function(submitCb, cancelCb, restrict)
  OpenMenu(submitCb, cancelCb, restrict)
end)

RegisterNetEvent('esx_skin:openSaveableMenu')
AddEventHandler('esx_skin:openSaveableMenu', function(submitCb, cancelCb)
  OpenSaveableMenu(submitCb, cancelCb, nil)
end)

--[[
  @TODO REMOVE THIS
]]
RegisterNetEvent('esx_skin:openSelectSkinMenu')
AddEventHandler('esx_skin:openSelectSkinMenu', function(submitCb, cancelCb)
  openSkinSelectionMenu()
end)

RegisterNetEvent('esx_skin:openSaveableRestrictedMenu')
AddEventHandler('esx_skin:openSaveableRestrictedMenu', function(submitCb, cancelCb, restrict)
  OpenSaveableMenu(submitCb, cancelCb, restrict)
end)

RegisterNetEvent('esx_skin:requestSaveSkin')
AddEventHandler('esx_skin:requestSaveSkin', function()
  TriggerEvent('skinchanger:getSkin', function(skin)
    TriggerServerEvent('esx_skin:responseSaveSkin', skin)
  end)
end)
