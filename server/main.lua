ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_skin:save')
AddEventHandler('esx_skin:save', function(skin)
  local xPlayer = ESX.GetPlayerFromId(source)
  UpdateSkinInDB(xPlayer, skin)
end)

RegisterServerEvent('esx_skin:create')
AddEventHandler('esx_skin:create', function(skin)
  local xPlayer = ESX.GetPlayerFromId(source)

  -- Make all player skins inactive
  MySQL.Sync.execute("UPDATE `skins` SET `active` = 0 WHERE (identifier = @identifier)",
    {
      ['@identifier'] = xPlayer.identifier
    }
  )

  MySQL.Sync.execute(
    'INSERT INTO skins(`skin`, `identifier`, `active`)VALUES(@skin, @identifier, 1)',
    {
      ['@skin']       = json.encode(skin),
      ['@identifier'] = xPlayer.identifier
    }
  )

  -- This is to ensure as much compatability with other plugins as possible
  MySQL.Sync.execute("UPDATE `users` SET `skin` = @skin WHERE identifier = @identifier",
    {
      ['@skin'] = json.encode(skin),
      ['@identifier'] = xPlayer.identifier
    }
  )

end)

RegisterServerEvent('esx_skin:responseSaveSkin')
AddEventHandler('esx_skin:responseSaveSkin', function(skin)
  local file = io.open('resources/[esx]/esx_skin/skins.txt', "a")

  file:write(json.encode(skin) .. "\n\n")
  file:flush()
  file:close()
end)

ESX.RegisterServerCallback('esx_skin:getPlayerSkin', function(source, cb)

  local xPlayer = ESX.GetPlayerFromId(source)

  MySQL.Async.fetchAll(
    'SELECT * FROM users WHERE identifier = @identifier',
    {
      ['@identifier'] = xPlayer.identifier
    },
    function(users)

      local user = users[1]
      local skin = nil

      local jobSkin = {
        skin_male   = xPlayer.job.skin_male,
        skin_female = xPlayer.job.skin_female
      }

      if user.skin ~= nil then
        skin = json.decode(user.skin)
      end

      cb(skin, jobSkin)
    end
  )
end)

ESX.RegisterServerCallback('esx_skin:getPlayerSkins', function(source, cb)
  local xPlayer = ESX.GetPlayerFromId(source)
  local skins = {}

  MySQL.Async.fetchAll(
    'SELECT * FROM skins WHERE identifier = @identifier',
    {
      ['@identifier'] = xPlayer.identifier
    },
    function(user_skins)
      for _, skin in pairs(user_skins) do

        if skin.active == 0 then
          isActive = false
        else
          isActive = true
        end

        table.insert(skins, {id = skin.id, skin = json.decode(skin.skin), name = skin.name, active = isActive})
      end

      cb(skins)
    end
  )
end)

ESX.RegisterServerCallback('esx_skin:setSkinLabel', function(source, cb, skinId, label)
  MySQL.Sync.execute("UPDATE `skins` SET `name` = @name WHERE id = @id",
    {
      ['@name'] = label,
      ['@id'] = skinId
    }
  )

  cb()
end)

ESX.RegisterServerCallback('esx_skin:setSkinActive', function(source, cb, skin)
  local xPlayer = ESX.GetPlayerFromId(source)

  MySQL.Sync.execute("UPDATE `skins` SET `active` = 1 WHERE id = @id",
    {
      ['@id'] = skin.id
    }
  )

  MySQL.Sync.execute("UPDATE `skins` SET `active` = 0 WHERE (id <> @id) AND (identifier = @identifier)",
    {
      ['@id'] = skin.id,
      ['@identifier'] = xPlayer.identifier
    }
  )

  -- This is to ensure as much compatability with other plugins as possible
  MySQL.Sync.execute("UPDATE `users` SET `skin` = @skin WHERE identifier = @identifier",
    {
      ['@skin'] = json.encode(skin.skin),
      ['@identifier'] = xPlayer.identifier
    }
  )

  cb()
end)

ESX.RegisterServerCallback('esx_skin:deleteSkin', function(source, cb, skinId)
  MySQL.Sync.execute("DELETE FROM `skins` WHERE id = @id",
    {
      ['@id'] = skinId
    }
  )

  cb()
end)

ESX.RegisterServerCallback('esx_skin:getActivePlayerSkin', function(source, cb)

  local xPlayer = ESX.GetPlayerFromId(source)

  MySQL.Async.fetchAll(
    'SELECT * FROM skins WHERE active = 1 AND identifier = @identifier LIMIT 1',
    {
      ['@identifier'] = xPlayer.identifier
    },
    function(user_skins)
      local skin = nil

      local jobSkin = {
        skin_male   = xPlayer.job.skin_male,
        skin_female = xPlayer.job.skin_female
      }

      for _, user_skin in pairs(user_skins) do
        if user_skin.skin ~= nil then
          skin = json.decode(user_skin.skin)
        end
      end

      cb(skin, jobSkin)
    end
  )

end)

function UpdateSkinInDB(xPlayer, skin)
  MySQL.Sync.execute(
    'UPDATE `skins` SET `skin` = @skin WHERE active = 1 AND identifier = @identifier',
    {
      ['@skin']       = json.encode(skin),
      ['@identifier'] = xPlayer.identifier
    }
  )
end

-- Commands
TriggerEvent('es:addGroupCommand', 'skin', 'admin', function(source, args, user)
  TriggerClientEvent('esx_skin:openSaveableMenu', source)
end, function(source, args, user)
  TriggerClientEvent('chatMessage', source, "SYSTEM", {255, 0, 0}, 'Insufficient permissions!')
end, {help = _U('skin')})

TriggerEvent('es:addGroupCommand', 'charmenu', 'user', function(source, args, user)
  TriggerClientEvent('esx_skin:openSelectSkinMenu', source)
end, function(source, args, user)
  TriggerClientEvent('chatMessage', source, "SYSTEM", {255, 0, 0}, 'Insufficient permissions!')
end, {help = _U('skin')})

TriggerEvent('es:addGroupCommand', 'skinsave', 'admin', function(source, args, user)
  TriggerClientEvent('esx_skin:requestSaveSkin', source)
end, function(source, args, user)
  TriggerClientEvent('chatMessage', source, "SYSTEM", {255, 0, 0}, "Insufficient Permissions.")
end, {help = _U('saveskin')})
