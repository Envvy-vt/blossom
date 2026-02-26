bot.command(:levelup, description: 'Enable or disable level-up messages for this server (Admin only)', category: 'Developer') do |event, state|
  unless event.server
    send_embed(event, title: "#{EMOJIS['developer']} Level-Up Settings", description: 'This command can only be used in a server.')
    next
  end

  perms = event.user.permission? :manage_server, event.channel
  unless perms
    send_embed(event, title: "#{EMOJIS['developer']} Level-Up Settings", description: 'You need the Manage Server permission to change this setting.')
    next
  end

  sid = event.server.id

  case state&.downcase
  when 'on', 'enable', 'enabled'
    DB.set_levelup(sid, true)
    send_embed(event, title: "#{EMOJIS['developer']} Level-Up Settings", description: 'Level-up messages are now **enabled** in this server.')
  when 'off', 'disable', 'disabled'
    DB.set_levelup(sid, false)
    send_embed(event, title: "#{EMOJIS['developer']} Level-Up Settings", description: 'Level-up messages are now **disabled** in this server.')
  else
    current = DB.levelup_enabled?(sid) ? 'enabled' : 'disabled'
    send_embed(event, title: "#{EMOJIS['developer']} Level-Up Settings", description: "Usage: `!levelup on` or `!levelup off`\nCurrently **#{current}**.")
  end
  nil
end

bot.command(:setlevel, description: 'Set a user\'s server level (Admin Only)', min_args: 2, category: 'Developer') do |event, mention, level|
  unless event.server
    event.respond("#{EMOJIS['x_']} This command can only be used inside a server!")
    next
  end

  unless event.user.permission?(:administrator, event.channel) || event.user.id == DEV_ID
    event.respond("#{EMOJIS['x_']} You need Administrator permissions to use this command!")
    next
  end

  target_user = event.message.mentions.first
  new_level = level.to_i

  if target_user.nil? || new_level < 1
    event.respond("Usage: `#{PREFIX}setlevel @user <level>`")
    next
  end

  sid = event.server.id
  uid = target_user.id
  user = DB.get_user_xp(sid, uid)

  DB.update_user_xp(sid, uid, user['xp'], new_level, user['last_xp_at'])

  send_embed(event, title: "#{EMOJIS['developer']} Admin Override", description: "Successfully set #{target_user.mention}'s level to **#{new_level}**.")
  nil
end

bot.command(:addxp, description: 'Add or remove server XP from a user (Admin Only)', min_args: 2, category: 'Developer') do |event, mention, amount|
  unless event.server
    event.respond("#{EMOJIS['x_']} This command can only be used inside a server!")
    next
  end

  unless event.user.permission?(:administrator, event.channel) || event.user.id == DEV_ID
    event.respond("#{EMOJIS['x_']} You need Administrator permissions to use this command!")
    next
  end

  target_user = event.message.mentions.first
  amount = amount.to_i

  if target_user.nil?
    event.respond("Usage: `#{PREFIX}addxp @user <amount>`\n*(Tip: Use a negative number to remove XP!)*")
    next
  end

  sid = event.server.id
  uid = target_user.id
  user = DB.get_user_xp(sid, uid)
  
  new_xp = user['xp'] + amount
  new_xp = 0 if new_xp < 0
  new_level = user['level']

  needed = new_level * 100
  while new_xp >= needed
    new_xp -= needed
    new_level += 1
    needed = new_level * 100
  end

  DB.update_user_xp(sid, uid, new_xp, new_level, user['last_xp_at'])

  send_embed(event, title: "#{EMOJIS['developer']} Admin Override", description: "Successfully added **#{amount}** XP to #{target_user.mention}.\nThey are now **Level #{new_level}** with **#{new_xp}** XP.")
  nil
end

bot.command(:addcoins, description: 'Add or remove coins from a user (Dev Only)', min_args: 2, category: 'Developer') do |event, mention, amount|
  unless event.user.id == DEV_ID
    event.respond("#{EMOJIS['x_']} Only the bot developer can use this command!")
    next
  end

  target_user = event.message.mentions.first
  amount = amount.to_i

  if target_user.nil?
    event.respond("Usage: `#{PREFIX}addcoins @user <amount>`\n*(Tip: Use a negative number to remove coins!)*")
    next
  end

  uid = target_user.id
  DB.add_coins(uid, amount)

  send_embed(event, title: "#{EMOJIS['developer']} Developer Override", description: "Successfully added **#{amount}** #{EMOJIS['s_coin']} to #{target_user.mention}.\nTheir new balance is **#{DB.get_coins(uid)}**.")
  nil
end

bot.command(:setcoins, description: 'Set a user\'s balance to an exact amount (Dev Only)', min_args: 2, category: 'Developer') do |event, mention, amount|
  unless event.user.id == DEV_ID
    event.respond("#{EMOJIS['x_']} Only the bot developer can use this command!")
    next
  end

  target_user = event.message.mentions.first
  amount = amount.to_i

  if target_user.nil? || amount < 0
    event.respond("Usage: `#{PREFIX}setcoins @user <amount>`")
    next
  end

  uid = target_user.id
  DB.set_coins(uid, amount)

  send_embed(event, title: "#{EMOJIS['developer']} Developer Override", description: "#{target_user.mention}'s balance has been forcefully set to **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}.")
  nil
end

bot.command(:enablebombs, description: 'Enable random bomb drops in a specific channel (Admin Only)', min_args: 1, category: 'Developer') do |event, channel_mention|
  unless event.user.permission?(:administrator, event.channel) || event.user.id == DEV_ID
    event.respond("#{EMOJIS['x_']} You need Administrator permissions to set this up!")
    next
  end

  channel_id = channel_mention.gsub(/[<#>]/, '').to_i
  target_channel = bot.channel(channel_id, event.server)

  if target_channel.nil?
    event.respond("#{EMOJIS['x_']} Please mention a valid channel! Usage: `#{PREFIX}enablebombs #channel-name`")
    next
  end

  sid = event.server.id
  server_bomb_configs[sid] ||= {}
  server_bomb_configs[sid].merge!({
    'enabled' => true,
    'channel_id' => channel_id,
    'message_count' => 0,
    'last_user_id' => nil,
    'threshold' => rand(BOMB_MIN_MESSAGES..BOMB_MAX_MESSAGES)
  })

  send_embed(event, title: "#{EMOJIS['bomb']} Bomb Drops Enabled!", description: "I will now randomly drop bombs in <##{channel_id}> as people chat!")
  nil
end

bot.command(:disablebombs, description: 'Disable random bomb drops (Admin Only)', category: 'Developer') do |event|
  unless event.user.permission?(:administrator, event.channel) || event.user.id == DEV_ID
    event.respond("#{EMOJIS['x_']} You need Administrator permissions!")
    next
  end
  
  sid = event.server.id
  if server_bomb_configs[sid]
    server_bomb_configs[sid]['enabled'] = false
  end
  
  event.respond("#{EMOJIS['x_']} Random bomb drops have been successfully disabled.")
  nil
end