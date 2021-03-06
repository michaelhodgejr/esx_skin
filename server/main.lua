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
    'INSERT INTO skins(`skin`, `identifier`, `active`, `loadout`)VALUES(@skin, @identifier, 1, @loadout)', {
      ['@skin']       = json.encode(skin),
      ['@identifier'] = xPlayer.identifier,
      ['@loadout']    = '[]'
    }
  )

  -- Get active skin and update users table with active_char_id 
  MySQL.Async.fetchAll('SELECT id FROM skins WHERE `active` = 1 AND `identifier` = @identifier', {
    ['@identifier'] = xPlayer.identifier
  }, function(skin)
        active_char_id = skin[1].id

        MySQL.Async.execute("UPDATE `users` SET `active_char_id` = @id WHERE identifier = @identifier",
          {
            ['@id'] = active_char_id,
            ['@identifier'] = xPlayer.identifier
          }
        )


        -- A little cleanup here. With new accounts inventory is created with null values so we want to update those to
        -- have the correct skin ID
        MySQL.Async.execute("UPDATE character_inventory SET `skin_id` = @skin_id WHERE identifier = @identifier AND skin_id IS NULL",
        {
            ['@skin_id'] = active_char_id,
            ['@identifier'] = xPlayer.identifier
          }
        )
   end)


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

  -- Get current Skin Id
	MySQL.Async.fetchAll('SELECT active_char_id FROM users WHERE identifier = @identifier', {
					['@identifier'] = xPlayer.identifier
                },
          function(user)
            active_char_id = user[1].active_char_id
            saveAndResetInventory(xPlayer, active_char_id)
            saveLoadoutAndJob(xPlayer, active_char_id)

            -- Make Skin Active
            MySQL.Sync.execute("UPDATE `skins` SET `active` = 1 WHERE id = @id",
              {
                ['@id'] = skin.id
              }
            )

            -- Set the active skin id on the user table
            MySQL.Sync.execute("UPDATE `users` SET `active_char_id` = @id WHERE identifier = @identifier",
              {
                ['@id'] = skin.id,
                ['@identifier'] = xPlayer.identifier
              }
            )

            -- Make all other skins inactive
            MySQL.Sync.execute("UPDATE `skins` SET `active` = 0 WHERE (id <> @id) AND (identifier = @identifier)",
              {
                ['@id'] = skin.id,
                ['@identifier'] = xPlayer.identifier
              }
            )

            -- Set skin entry on the users table
            -- This is to ensure as much compatability with other plugins as possible
            MySQL.Sync.execute("UPDATE `users` SET `skin` = @skin WHERE identifier = @identifier",
              {
                ['@skin'] = json.encode(skin.skin),
                ['@identifier'] = xPlayer.identifier
              }
            )

            -- Load users inventory for this particular skin
            reloadUsersInventory(xPlayer, skin.id)

            -- Load users loadout for this skin
            loadLoadout(xPlayer, skin.id)

            -- Set the job and the job grade for the user
            setJob(xPlayer, skin.id)

            -- Save again to get new character inventory changes
            saveAndResetInventory(xPlayer, skin.id)


        end
   )


  cb()
end)


function setJob(xPlayer, skin_id)
  MySQL.Async.fetchAll(
    'SELECT job, job_grade FROM skins WHERE id = @skin_id',
    {
      ['@skin_id'] = skin_id
    },
    function(skins)
      job = skins[1].job
      job_grade = skins[1].job_grade

      xPlayer.setJob(job, job_grade);
    end)
end


function loadLoadout(xPlayer, skin_id)

  -- Remove old loadout items from the user
  for _, weapon in pairs(xPlayer.getLoadout()) do
    xPlayer.removeWeapon(weapon.name)
  end

  -- Add in characters weapons 
  MySQL.Async.fetchAll(
    'SELECT loadout FROM skins WHERE id = @skin_id',
    {
      ['@skin_id'] = skin_id
    },
    function(skins)
      loadout = json.decode(skins[1].loadout)

      for _, weapon in pairs(loadout) do
        xPlayer.addWeapon(weapon.name, weapon.ammo)
      end
    end)
end

function saveLoadoutAndJob(xPlayer, skin_id)
  loadout = json.encode(xPlayer.loadout);

  MySQL.Async.execute('UPDATE skins SET loadout = @loadout, job = @job, job_grade = @job_grade WHERE id = @skin_id',
    {
      ['@loadout'] = loadout,
      ['@job']        = xPlayer.job.name,
      ['@job_grade']  = xPlayer.job.grade,
      ['@skin_id'] = skin_id
  })
end

function saveAndResetInventory(xPlayer, skin_id)

    ---print("RESETTING INVENTORY FOR SKIN ID " .. skin_id)
    MySQL.Sync.execute('DELETE FROM character_inventory WHERE skin_id = @skin_id AND identifier = @identifier', {
      ['@skin_id'] = skin_id,
      ['@identifier'] = xPlayer.identifier
    }) 


    for _, item in pairs(xPlayer.getInventory()) do
      ---print("INSERTING ITEM: " .. item.name .. "| Count: " .. item.count .. " | Skin Id: " .. skin_id)
      MySQL.Sync.execute('INSERT INTO character_inventory(identifier, item, count, skin_id)VALUES(@identifier, @item, @count, @skin_id)',
        {
          ['@identifier'] = xPlayer.identifier,
          ['@count']      = item.count,
          ['@item']       = item.name,
          ['@skin_id']    = skin_id 
        }
      )
    end
end

function reloadUsersInventory(xPlayer, id)

  -- Remove old inventory items from the user
  for _, item in pairs(xPlayer.getInventory()) do
    xPlayer.removeInventoryItem(item.name, item.count)
  end

  -- Add in characters inventory items
  MySQL.Async.fetchAll(
    'SELECT * FROM character_inventory WHERE identifier = @identifier AND skin_id = @skin_id',
    {
      ['@identifier'] = xPlayer.identifier,
      ['@skin_id'] = id
    },
    function(items)
      for _, item in pairs(items) do
        xPlayer.addInventoryItem(item.item, item.count)
      end
    end)
end

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
