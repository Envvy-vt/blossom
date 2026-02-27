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

  # Extract ID from mention
  channel_id = channel_mention.gsub(/[<#>]/, '').to_i
  target_channel = bot.channel(channel_id, event.server)

  if target_channel.nil?
    event.respond("#{EMOJIS['x_']} Please mention a valid channel! Usage: `#{PREFIX}enablebombs #channel-name`")
    next
  end

  sid = event.server.id
  threshold = rand(BOMB_MIN_MESSAGES..BOMB_MAX_MESSAGES)

  # Update the live memory
  server_bomb_configs[sid] = {
    'enabled' => true,
    'channel_id' => channel_id,
    'message_count' => 0,
    'last_user_id' => nil,
    'threshold' => threshold
  }

  # PERSISTENCE: Save to database
  DB.save_bomb_config(sid, true, channel_id, threshold, 0)

  send_embed(event, title: "#{EMOJIS['bomb']} Bomb Drops Enabled!", description: "I will now randomly drop bombs in <##{channel_id}> as people chat!")
  nil
end

bot.command(:disablebombs, category: 'Developer') do |event|
  sid = event.server.id
  if server_bomb_configs[sid]
    server_bomb_configs[sid]['enabled'] = false
    # Save disabled state to DB (passing false for enabled)
    DB.save_bomb_config(sid, false, server_bomb_configs[sid]['channel_id'], 0, 0)
    event.respond "💣 Bomb drops disabled for this server."
  end
end

bot.command(:blacklist, description: 'Toggle blacklist for a user (Dev Only)', min_args: 1, category: 'Developer') do |event, mention|
  unless event.user.id == DEV_ID
    event.respond("#{EMOJIS['x_']} Only the bot developer can use this command!")
    next
  end

  target_user = event.message.mentions.first
  if target_user.nil?
    event.respond("Usage: `#{PREFIX}blacklist @user`")
    next
  end

  uid = target_user.id
  
  if uid == DEV_ID
    event.respond("#{EMOJIS['x_']} You cannot blacklist yourself!")
    next
  end

  # Toggle them in the DB and check their new status
  is_now_blacklisted = DB.toggle_blacklist(uid)

  if is_now_blacklisted
    event.bot.ignore_user(uid) # Tells discordrb to go completely deaf to this user
    send_embed(event, title: "🚫 User Blacklisted", description: "#{target_user.mention} has been added to the blacklist. I will now ignore all messages and commands from them.")
  else
    event.bot.unignore_user(uid) # Tells discordrb to listen to them again
    send_embed(event, title: "✅ User Forgiven", description: "#{target_user.mention} has been removed from the blacklist. They are free to interact again.")
  end
  nil
end

bot.command(:card, min_args: 3, description: 'Manage user cards (Dev Only)', usage: '!card <add/remove/giveascended/takeascended> @user <Character Name>') do |event, action, target, *char_name|
  # 1. Security Check
  unless event.user.id == DEV_ID
    send_embed(event, title: "❌ Access Denied", description: "This command is restricted to the Bot Developer.")
    next
  end

  # 2. Parse User and Character
  target_user = event.message.mentions.first
  name_query = char_name.join(' ')
  
  unless target_user
    send_embed(event, title: "⚠️ Error", description: "You must mention a user to modify their collection.")
    next
  end

  found_data = find_character_in_pools(name_query)
  unless found_data
    send_embed(event, title: "⚠️ Character Not Found", description: "I couldn't find `#{name_query}` in the pools.")
    next
  end

  real_name = found_data[:char][:name]
  rarity = found_data[:rarity]
  uid = target_user.id

  case action.downcase
  when 'add', 'give'
    DB.add_character(uid, real_name, rarity, 1)
    send_embed(event, title: "🎁 Card Added", description: "Added **#{real_name}** to #{target_user.mention}'s collection!")

  when 'remove', 'take'
    DB.remove_character(uid, real_name, 1)
    send_embed(event, title: "🗑️ Card Removed", description: "Removed one copy of **#{real_name}** from #{target_user.mention}.")

  # NEW: Give an Ascended version directly
  when 'giveascended', 'give✨', 'addascended'
    # We use a direct SQL update here since add_character usually handles base copies
    DB.instance_variable_get(:@db).execute(
      "INSERT INTO collections (user_id, character_name, rarity, count, ascended) 
       VALUES (?, ?, ?, 0, 1) 
       ON CONFLICT(user_id, character_name) 
       DO UPDATE SET ascended = ascended + 1", 
      [uid, real_name, rarity]
    )
    send_embed(
      event, 
      title: "✨ Ascended Card Granted", 
      description: "Successfully granted an **Ascended #{real_name}** to #{target_user.mention}!"
    )

  # NEW: Take an Ascended version
  when 'takeascended', 'take✨', 'removeascended'
    DB.instance_variable_get(:@db).execute(
      "UPDATE collections SET ascended = MAX(0, ascended - 1) 
       WHERE user_id = ? AND character_name = ?", 
      [uid, real_name]
    )
    send_embed(event, title: "♻️ Ascended Card Removed", description: "Removed one ✨ star from #{target_user.mention}'s **#{real_name}**.")

  else
    send_embed(event, title: "⚠️ Invalid Action", description: "Use `add`, `remove`, `giveascended`, or `takeascended`.")
  end
  nil
end

bot.command(:backup, description: 'Developer Only') do |event|
  # 1. Security Check
  unless event.user.id == DEV_ID
    send_embed(event, title: "❌ Access Denied", description: "This command is restricted to the Bot Developer.")
    next
  end

  begin
    # 2. Find the DB file using the base execution directory
    # This looks for blossom.db in the main blossom-bot folder
    db_file = "blossom.db" 

    if File.exist?(db_file)
      # 3. Send to your DMs
      event.user.pm("🌸 **Blossom Database Backup**\nGenerated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
      
      # We open the file in binary mode ('rb') to ensure it doesn't get corrupted
      File.open(db_file, 'rb') do |file|
        event.user.send_file(file)
      end
      
      # 4. Confirm in the channel
      send_embed(event, title: "📂 Backup Successful", description: "I've sent the latest `blossom.db` to your DMs, Eve!")
    else
      # If it's not in the base folder, let's show exactly where she is looking
      current_path = Dir.pwd
      send_embed(event, title: "⚠️ File Not Found", description: "I'm looking in `#{current_path}`, but `blossom.db` isn't there.")
    end
  rescue => e
    send_embed(event, title: "❌ Backup Failed", description: "An error occurred: #{e.message}")
    puts "Backup Error: #{e.message}\n#{e.backtrace.first}"
  end
  nil
end