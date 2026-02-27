# =========================
# LEVELING SYSTEM
# =========================

bot.message do |event|
  next if event.user.bot_account?
  next unless event.server 

  sid  = event.server.id
  uid  = event.user.id
  user = DB.get_user_xp(sid, uid)

  now = Time.now
  if user['last_xp_at'] && (now - user['last_xp_at']) < MESSAGE_COOLDOWN
    next
  end

  new_xp = user['xp'] + XP_PER_MESSAGE
  new_level = user['level']
  DB.add_coins(uid, COINS_PER_MESSAGE)

  needed = new_level * 100
  if new_xp >= needed
    new_xp -= needed
    new_level += 1

    # 1. EXCLUSIVE SERVER ROLE LOGIC
    if sid == 1472509438010065070
      member = event.server.member(uid)
      
      if member
        level_roles = {
          100 => 1473524725127970817,
          75  => 1473524687593013259,
          50  => 1473524652629430530,
          40  => 1473524612032757964,
          30  => 1473524563299012731,
          20  => 1473524496773288071,
          10  => 1473524452875833465,
          5   => 1473524374970568967
        }

        earned_role_id = nil
        level_roles.each do |req_level, role_id|
          if new_level >= req_level
            earned_role_id = role_id
            break 
          end
        end

        if earned_role_id
          roles_to_remove = level_roles.values - [earned_role_id]
          begin
            roles_to_remove.each do |role_id|
              member.remove_role(role_id) if member.role?(role_id)
            end
            member.add_role(earned_role_id) unless member.role?(earned_role_id)
          rescue Discordrb::Errors::NoPermission
            puts "!!! [WARNING] Role hierarchy error for #{member.display_name}"
          end
        end
      end
    end

    # 2. LEVEL UP MESSAGE ROUTING
    config = DB.get_levelup_config(sid)

    if config[:enabled]
      embed = Discordrb::Webhooks::Embed.new(
        title: "🎉 Level Up!",
        description: "Congratulations #{event.user.mention}! You just advanced to **Level #{new_level}**!",
        color: NEON_COLORS.sample
      )
      
      embed.add_field(name: 'XP Remaining', value: "#{new_xp}/#{new_level * 100}", inline: true)
      embed.add_field(name: 'Coins', value: "#{DB.get_coins(uid)} #{EMOJIS['s_coin']}", inline: true)

      if config[:channel]
        target_channel = event.bot.channel(config[:channel])
        if target_channel
          target_channel.send_message(nil, false, embed)
        else
          event.channel.send_message(nil, false, embed, nil, nil, event.message)
        end
      else
        event.channel.send_message(nil, false, embed, nil, nil, event.message)
      end
    end
  end
  
  DB.update_user_xp(sid, uid, new_xp, new_level, now)
end

bot.member_leave do |event|
  DB.remove_user_xp(event.server.id, event.user.id)
end

bot.command(:level, description: 'Show a user\'s level and XP for this server', category: 'Utility') do |event|
  unless event.server
    event.respond("#{EMOJIS['x_']} This command can only be used in a server!")
    next
  end

  target_user = event.message.mentions.first || event.user
  sid  = event.server.id
  uid  = target_user.id
  user = DB.get_user_xp(sid, uid)
  needed = user['level'] * 100

  dev_badge = (uid == DEV_ID) ? "#{EMOJIS['developer']} **Verified Bot Developer**" : ""

  send_embed(
    event,
    title: "#{EMOJIS['crown']} #{target_user.display_name}'s Server Level",
    description: dev_badge, 
    fields: [
      { name: 'Level', value: user['level'].to_s, inline: true },
      { name: 'XP', value: "#{user['xp']}/#{needed}", inline: true },
      { name: 'Coins', value: "#{DB.get_coins(uid)} #{EMOJIS['s_coin']}", inline: true }
    ]
  )
  nil
end

bot.command(:leaderboard, description: 'Show top users by level and XP for this server', category: 'Fun') do |event|
  unless event.server
    event.respond("#{EMOJIS['x_']} This command can only be used in a server!")
    next
  end

  sid = event.server.id
  current_member_ids = event.server.members.map(&:id)
  
  active_users = []
  DB.get_top_users(sid, 100).each do |row|
    if current_member_ids.include?(row['user_id'])
      active_users << row
      break if active_users.size >= 10
    end
  end

  if active_users.empty?
    send_embed(event, title: "#{EMOJIS['crown']} Server Leaderboard", description: 'Nobody has gained any XP here yet.')
  else
    desc = active_users.each_with_index.map do |row, index|
      user_obj = event.bot.user(row['user_id'])
      name = user_obj ? user_obj.display_name : "User #{row['user_id']}"
      "##{index + 1} — **#{name}**: Level #{row['level']} | **#{DB.get_coins(row['user_id'])}** #{EMOJIS['s_coin']}"
    end.join("\n")

    send_embed(event, title: "#{EMOJIS['crown']} Server Leaderboard", description: desc)
  end
  nil
end

bot.command(:levelup, description: 'Configure where level-up messages go', category: 'Admin') do |event, arg|
  unless event.user.id == DEV_ID || event.user.permission?(:administrator, event.channel)
    send_embed(event, title: "❌ Access Denied", description: "You need administrator permissions to configure this.")
    next
  end

  if arg.nil? || arg.downcase == 'on'
    DB.set_levelup_config(event.server.id, nil, true)
    send_embed(event, title: "✅ Level-Ups Enabled", description: "Level-up messages will now be sent as a direct reply to the user.")
  elsif arg.downcase == 'off'
    DB.set_levelup_config(event.server.id, nil, false)
    send_embed(event, title: "🔇 Level-Ups Disabled", description: "Level-up messages have been completely turned off for this server.")
  elsif arg =~ /<#(\d+)>/
    channel_id = $1.to_i
    channel = event.bot.channel(channel_id, event.server)
    
    if channel
      DB.set_levelup_config(event.server.id, channel_id, true)
      send_embed(event, title: "📣 Level-Up Channel Set", description: "Level-up messages will now be automatically sent to #{channel.mention}!")
    else
      send_embed(event, title: "⚠️ Error", description: "I couldn't find that channel in this server.")
    end
  else
    send_embed(event, title: "⚠️ Invalid Usage", description: "Usage:\n`#{PREFIX}levelup #channel` - Send to a specific channel\n`#{PREFIX}levelup off` - Turn off completely\n`#{PREFIX}levelup on` - Default replies")
  end
  nil
end