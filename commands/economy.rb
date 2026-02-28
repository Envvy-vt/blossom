# =========================
# ECONOMY COMMANDS
# =========================

bot.command(:balance, description: 'Show a user\'s coin balance, gacha stats, and inventory', category: 'Economy') do |event|
  target_user = event.message.mentions.first || event.user
  uid = target_user.id

  if uid == event.bot.profile.id
    setup_text = ""
    consumables_text = ""

    BLACK_MARKET_ITEMS.each do |key, data|
      if data[:type] == 'upgrade'
        setup_text += "#{data[:name]} (x7)\n"
      elsif data[:type] == 'consumable'
        consumables_text += "#{data[:name]} (x7)\n"
      end
    end

    fields = [
      { name: "#{EMOJIS['rich']} Bank Account", value: "**7,777,777** #{EMOJIS['s_coin']}", inline: false },
      { name: '🖥️ Stream Setup', value: setup_text, inline: true },
      { name: '🎒 Consumables', value: consumables_text, inline: true },
      { name: "\u200B", value: "\u200B", inline: false }, 
      { name: '⭐ Commons', value: "Owned: **All / #{TOTAL_UNIQUE_CHARS['common']}**\nAscended: **All** #{EMOJIS['neonsparkle']}", inline: true },
      { name: '✨ Rares', value: "Owned: **All / #{TOTAL_UNIQUE_CHARS['rare']}**\nAscended: **All** #{EMOJIS['neonsparkle']}", inline: true },
      { name: "\u200B", value: "\u200B", inline: false }, 
      { name: '🌟 Legendaries', value: "Owned: **All / #{TOTAL_UNIQUE_CHARS['legendary']}**\nAscended: **All** #{EMOJIS['neonsparkle']}", inline: true }
    ]
    
    if TOTAL_UNIQUE_CHARS['goddess'] && TOTAL_UNIQUE_CHARS['goddess'] > 0
      fields << { name: '💎 Goddess', value: "Owned: **All / #{TOTAL_UNIQUE_CHARS['goddess']}**\nAscended: **All** #{EMOJIS['neonsparkle']}", inline: true }
    end

    send_embed(
      event,
      title: "🌸 Blossom's Admin Profile",
      description: "Wait, you're checking *my* pockets? I'm the one running the arcade! I have exactly 7 of every item and a fully maxed out, shiny character collection... don't ask why.",
      fields: fields
    )
    next
  end

  user_collection = DB.get_collection(uid)
  
  common_owned    = user_collection.values.count { |c| c['rarity'] == 'common' && (c['count'] > 0 || c['ascended'] > 0) }
  rare_owned      = user_collection.values.count { |c| c['rarity'] == 'rare' && (c['count'] > 0 || c['ascended'] > 0) }
  legendary_owned = user_collection.values.count { |c| c['rarity'] == 'legendary' && (c['count'] > 0 || c['ascended'] > 0) }
  goddess_owned   = user_collection.values.count { |c| c['rarity'] == 'goddess' && (c['count'] > 0 || c['ascended'] > 0) }

  common_asc      = user_collection.values.count { |c| c['rarity'] == 'common' && c['ascended'] > 0 }
  rare_asc        = user_collection.values.count { |c| c['rarity'] == 'rare' && c['ascended'] > 0 }
  legendary_asc   = user_collection.values.count { |c| c['rarity'] == 'legendary' && c['ascended'] > 0 }
  goddess_asc     = user_collection.values.count { |c| c['rarity'] == 'goddess' && c['ascended'] > 0 }

  user_inv = DB.get_inventory(uid)
  
  setup_text = ""
  ['headset', 'keyboard', 'mic', 'neon sign', 'gacha pass'].each do |item_key|
    if user_inv[item_key] && user_inv[item_key] > 0
      setup_text += "#{BLACK_MARKET_ITEMS[item_key][:name]}\n"
    end
  end
  setup_text = "None" if setup_text.empty?

  consumables_text = ""
  ['rng manipulator', 'gamer fuel', 'stamina pill'].each do |item_key|
    if user_inv[item_key] && user_inv[item_key] > 0
      consumables_text += "#{BLACK_MARKET_ITEMS[item_key][:name]} (x#{user_inv[item_key]})\n"
    end
  end
  consumables_text = "None" if consumables_text.empty?

  fields = [
    { name: "#{EMOJIS['rich']} Bank Account", value: "**#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}", inline: false },
    { name: '🖥️ Stream Setup', value: setup_text, inline: true },
    { name: '🎒 Consumables', value: consumables_text, inline: true },
    { name: "\u200B", value: "\u200B", inline: false }, 
    { name: '⭐ Commons', value: "Owned: **#{common_owned} / #{TOTAL_UNIQUE_CHARS['common']}**\nAscended: **#{common_asc}** #{EMOJIS['neonsparkle']}", inline: true },
    { name: '✨ Rares', value: "Owned: **#{rare_owned} / #{TOTAL_UNIQUE_CHARS['rare']}**\nAscended: **#{rare_asc}** #{EMOJIS['neonsparkle']}", inline: true },
    { name: "\u200B", value: "\u200B", inline: false }, 
    { name: '🌟 Legendaries', value: "Owned: **#{legendary_owned} / #{TOTAL_UNIQUE_CHARS['legendary']}**\nAscended: **#{legendary_asc}** #{EMOJIS['neonsparkle']}", inline: true }
  ]

  if TOTAL_UNIQUE_CHARS['goddess'] && TOTAL_UNIQUE_CHARS['goddess'] > 0
    fields << { name: '💎 Goddess', value: "Owned: **#{goddess_owned} / #{TOTAL_UNIQUE_CHARS['goddess']}**\nAscended: **#{goddess_asc}** #{EMOJIS['neonsparkle']}", inline: true }
  end

  dev_badge = (uid == DEV_ID) ? "\n\n#{EMOJIS['developer']} **Verified Bot Developer**" : ""

  send_embed(
    event,
    title: "#{target_user.display_name}'s Profile",
    description: "Here are #{target_user.display_name}'s current economy and gacha stats!#{dev_badge}",
    fields: fields
  )
  nil
end

bot.command(:daily, description: 'Claim your daily coin reward', category: 'Economy') do |event|
  uid = event.user.id
  now = Time.now
  last_used = DB.get_cooldown(uid, 'daily')
  is_sub = is_premium?(event.bot, uid)

  if last_used && (now - last_used) < DAILY_COOLDOWN
    remaining = DAILY_COOLDOWN - (now - last_used)
    send_embed(event, title: "#{EMOJIS['coin']} Daily Reward", description: "You already claimed your daily #{EMOJIS['worktired']}\nTry again in **#{format_time_delta(remaining)}**.")
  else
    reward = DAILY_REWARD
    bonus_text = ""
    inv = DB.get_inventory(uid)
    
    if inv['neon sign'] && inv['neon sign'] > 0
      reward *= 2
      bonus_text += "\n*(✨ Neon Sign Boost: x2 Payout!)*"
    end

    bonus_text += "\n*(💎 Subscriber Bonus: +10%)*" if is_sub

    final_reward = award_coins(event.bot, uid, reward)
    DB.set_cooldown(uid, 'daily', now)
    send_embed(event, title: "#{EMOJIS['coin']} Daily Reward", description: "You claimed **#{final_reward}** #{EMOJIS['s_coin']}!#{bonus_text}\nNew balance: **#{DB.get_coins(uid)}**.")
  end
  nil
end

bot.command(:work, description: 'Work for some coins', category: 'Economy') do |event|
  uid = event.user.id
  now = Time.now
  last_used = DB.get_cooldown(uid, 'work')
  is_sub = is_premium?(event.bot, uid)
  
  active_cd = is_sub ? (WORK_COOLDOWN / 2) : WORK_COOLDOWN

  if last_used && (now - last_used) < active_cd
    remaining = active_cd - (now - last_used)
    send_embed(event, title: "#{EMOJIS['work']} Work", description: "You are tired #{EMOJIS['worktired']}\nTry working again in **#{format_time_delta(remaining)}**.")
  else
    amount = rand(WORK_REWARD_RANGE)
    bonus_text = ""
    inv = DB.get_inventory(uid)

    if inv['keyboard'] && inv['keyboard'] > 0
      amount = (amount * 1.25).to_i
      bonus_text += "\n*(⌨️ Keyboard Boost: +25%)*"
    end

    bonus_text += "\n*(💎 Subscriber Bonus: +10%)*" if is_sub

    final_amount = award_coins(event.bot, uid, amount)
    DB.set_cooldown(uid, 'work', now)
    send_embed(event, title: "#{EMOJIS['work']} Work", description: "You worked hard and earned **#{final_amount}** #{EMOJIS['s_coin']}!#{bonus_text}\nNew balance: **#{DB.get_coins(uid)}**.")
  end
  nil
end

bot.command(:stream, description: 'Go live and earn some coins!', category: 'Economy') do |event|
  uid = event.user.id
  now = Time.now
  last_used = DB.get_cooldown(uid, 'stream')
  is_sub = is_premium?(event.bot, uid)

  active_cd = is_sub ? (STREAM_COOLDOWN / 2) : STREAM_COOLDOWN

  if last_used && (now - last_used) < active_cd
    remaining = active_cd - (now - last_used)
    send_embed(event, title: "#{EMOJIS['stream']} Stream Offline", description: "You just finished streaming! Your voice needs a break #{EMOJIS['drink']}\nTry going live again in **#{format_time_delta(remaining)}**.")
  else
    reward = rand(STREAM_REWARD_RANGE)
    game = STREAM_GAMES.sample
    bonus_text = ""
    inv = DB.get_inventory(uid)
    
    if inv['mic'] && inv['mic'] > 0
      reward = (reward * 1.10).to_i
      bonus_text += "\n*(🎙️ Studio Mic Boost: +10%)*"
    end

    bonus_text += "\n*(💎 Subscriber Bonus: +10%)*" if is_sub

    final_reward = award_coins(event.bot, uid, reward)
    DB.set_cooldown(uid, 'stream', now)
    send_embed(event, title: "#{EMOJIS['stream']} Stream Ended", description: "You had a great stream playing **#{game}** and earned **#{final_reward}** #{EMOJIS['s_coin']}!#{bonus_text}\nNew balance: **#{DB.get_coins(uid)}**.")
  end
  nil
end

bot.command(:post, description: 'Post on social media for some quick coins!', category: 'Economy') do |event|
  uid = event.user.id
  now = Time.now
  last_used = DB.get_cooldown(uid, 'post')
  is_sub = is_premium?(event.bot, uid)

  active_cd = is_sub ? (POST_COOLDOWN / 2) : POST_COOLDOWN

  if last_used && (now - last_used) < active_cd
    remaining = active_cd - (now - last_used)
    send_embed(event, title: "#{EMOJIS['error']} Social Media Break", description: "You're posting too fast! Don't get shadowbanned #{EMOJIS['nervous']}\nTry posting again in **#{format_time_delta(remaining)}**.")
  else
    reward = rand(POST_REWARD_RANGE)
    platform = POST_PLATFORMS.sample
    bonus_text = ""
    inv = DB.get_inventory(uid)

    if inv['headset'] && inv['headset'] > 0
      reward = (reward * 1.25).to_i
      bonus_text += "\n*(🎧 Headset Boost: +25%)*"
    end

    bonus_text += "\n*(💎 Subscriber Bonus: +10%)*" if is_sub

    final_reward = award_coins(event.bot, uid, reward)
    DB.set_cooldown(uid, 'post', now)
    send_embed(event, title: "#{EMOJIS['like']} New Post Uploaded!", description: "Your latest post on **#{platform}** got a lot of engagement! You earned **#{final_reward}** #{EMOJIS['s_coin']}.#{bonus_text}\nNew balance: **#{DB.get_coins(uid)}**.")
  end
  nil
end

bot.command(:collab, description: 'Ask the server to do a collab stream! (30m cooldown)', category: 'Economy') do |event|
  uid = event.user.id
  now = Time.now
  last_used = DB.get_cooldown(uid, 'collab')

  if last_used && (now - last_used) < COLLAB_COOLDOWN
    remaining = COLLAB_COOLDOWN - (now - last_used)
    send_embed(event, title: "#{EMOJIS['worktired']} Collab Burnout", description: "You're collaborating too much! Rest your voice.\nTry again in **#{format_time_delta(remaining)}**.")
    next
  end

  DB.set_cooldown(uid, 'collab', now)
  expire_time = Time.now + 180 
  discord_timestamp = "<t:#{expire_time.to_i}:R>"
  
  collab_id = "collab_#{expire_time.to_i}_#{rand(10000)}"
  ACTIVE_COLLABS[collab_id] = uid 

  embed = Discordrb::Webhooks::Embed.new(
    title: "#{EMOJIS['stream']} Collab Request!",
    description: "#{event.user.mention} is looking for someone to do a collab stream with!\n\nPress the button below to join them! Request expires **#{discord_timestamp}**.",
    color: NEON_COLORS.sample
  )

  view = Discordrb::Components::View.new do |v|
    v.row { |r| r.button(custom_id: collab_id, label: 'Accept Collab', style: :success, emoji: '🤝') }
  end

  msg = event.channel.send_message(nil, false, embed, nil, nil, event.message, view)

  Thread.new do
    sleep 180
    if ACTIVE_COLLABS.key?(collab_id)
      ACTIVE_COLLABS.delete(collab_id)
      failed_embed = Discordrb::Webhooks::Embed.new(
        title: "#{EMOJIS['x_']} Collab Cancelled",
        description: "Nobody was available to collab with #{event.user.mention} this time #{EMOJIS['confused']}...",
        color: 0x808080
      )
      msg.edit(nil, failed_embed, Discordrb::Components::View.new)
    end
  end
  nil
end

bot.button(custom_id: /^collab_/) do |event|
  collab_id = event.custom_id

  if ACTIVE_COLLABS.key?(collab_id)
    author_id = ACTIVE_COLLABS[collab_id]

    if event.user.id == author_id
      event.respond(content: "You can't accept your own collab request!", ephemeral: true)
      next
    end

    ACTIVE_COLLABS.delete(collab_id)
    
    author_final = award_coins(event.bot, author_id, COLLAB_REWARD)
    user_final = award_coins(event.bot, event.user.id, COLLAB_REWARD)

    author_user = event.bot.user(author_id)
    author_mention = author_user ? author_user.mention : "<@#{author_id}>"

    success_embed = Discordrb::Webhooks::Embed.new(
      title: "#{EMOJIS['neonsparkle']} Collab Stream Started!",
      description: "#{event.user.mention} accepted the collab with #{author_mention}!\n\nBoth streamers got a baseline of **#{COLLAB_REWARD}** #{EMOJIS['s_coin']} for an awesome stream! *(Subscribers received a 10% bonus!)*",
      color: 0x00FF00
    )

    event.update_message(content: nil, embeds: [success_embed], components: Discordrb::Components::View.new)
  else
    event.respond(content: 'This collab request has already expired or been accepted!', ephemeral: true)
  end
end

bot.command(:cooldowns, description: 'Check your active timers for economy commands', category: 'Economy') do |event|
  uid = event.user.id
  inv = DB.get_inventory(uid)
  is_sub = is_premium?(event.bot, uid)
  
  check_cd = ->(type, cooldown_duration) do
    last_used = DB.get_cooldown(uid, type)
    if last_used && (Time.now - last_used) < cooldown_duration
      ready_time = last_used + cooldown_duration
      "Ready <t:#{ready_time.to_i}:R>"
    else
      "**Ready!**"
    end
  end

  work_cd = is_sub ? (WORK_COOLDOWN / 2) : WORK_COOLDOWN
  stream_cd = is_sub ? (STREAM_COOLDOWN / 2) : STREAM_COOLDOWN
  post_cd = is_sub ? (POST_COOLDOWN / 2) : POST_COOLDOWN
  summon_duration = (inv['gacha pass'] && inv['gacha pass'] > 0) ? 300 : 600

  cd_fields = [
    { name: '!daily', value: check_cd.call('daily', DAILY_COOLDOWN), inline: true },
    { name: '!work', value: check_cd.call('work', work_cd), inline: true },
    { name: '!stream', value: check_cd.call('stream', stream_cd), inline: true },
    { name: '!post', value: check_cd.call('post', post_cd), inline: true },
    { name: '!collab', value: check_cd.call('collab', COLLAB_COOLDOWN), inline: true },
    { name: '!summon', value: check_cd.call('summon', summon_duration), inline: true } 
  ]

  send_embed(
    event,
    title: "#{EMOJIS['info']} #{event.user.display_name}'s Cooldowns",
    description: "Here are your current economy timers:",
    fields: cd_fields
  )
  nil
end

# =========================
# CHAT BOMB DROPS
# =========================

bot.command(:bomb, description: 'Plant a bomb that explodes in 5 minutes (Admin only)', category: 'Fun') do |event|
  unless event.user.permission?(:administrator, event.channel) || event.user.id == DEV_ID
    send_embed(event, title: "#{EMOJIS['x_']} Permission Denied", description: 'You need Administrator permissions to plant a bomb!')
    next
  end

  expire_time = Time.now + 300
  discord_timestamp = "<t:#{expire_time.to_i}:R>"
  
  bomb_id = "bomb_#{expire_time.to_i}_#{rand(10000)}"
  ACTIVE_BOMBS[bomb_id] = true

  embed = Discordrb::Webhooks::Embed.new(
    title: "#{EMOJIS['bomb']} Bomb Planted!",
    description: "An admin has planted a bomb! It will explode **#{discord_timestamp}**!\nQuick, press the button to defuse it and earn a reward!",
    color: NEON_COLORS.sample
  )

  view = Discordrb::Components::View.new do |v|
    v.row { |r| r.button(custom_id: bomb_id, label: 'Defuse', style: :danger, emoji: '✂️') }
  end

  msg = event.channel.send_message(nil, false, embed, nil, nil, event.message, view)

  Thread.new do
    sleep 300
    if ACTIVE_BOMBS[bomb_id]
      ACTIVE_BOMBS.delete(bomb_id)
      exploded_embed = Discordrb::Webhooks::Embed.new(
        title: "#{EMOJIS['bomb']} BOOM!",
        description: 'Nobody defused it in time... The bomb exploded!',
        color: 0x000000 
      )
      msg.edit(nil, exploded_embed, Discordrb::Components::View.new)
    end
  end
  nil
end

bot.message do |event|
  next unless event.server
  next if event.author.bot_account?

  sid = event.server.id
  config = server_bomb_configs[sid]
  next unless config && config['enabled']

  uid = event.author.id

  if config['last_user_id'] != uid
    config['message_count'] += 1
    config['last_user_id'] = uid

    DB.save_bomb_config(sid, true, config['channel_id'], config['threshold'], config['message_count'])

    if config['message_count'] >= config['threshold']
      target_channel = bot.channel(config['channel_id'], event.server)
      
      if target_channel
        embed = Discordrb::Webhooks::Embed.new(
          title: "#{EMOJIS['bomb']} INCOMING BOMB!",
          description: "A rogue bomb just dropped into the chat!\nQuick, click the button below to defuse it and steal the coins inside!",
          color: 0xFF0000
        )
        
        view = Discordrb::Components::View.new do |v|
          v.row { |r| r.button(custom_id: "defuse_drop_#{sid}", label: 'Cut the Wire!', style: :danger, emoji: '✂️') }
        end
        
        target_channel.send_message(nil, false, embed, nil, nil, nil, view)
      end

      config['message_count'] = 0
      config['last_user_id'] = nil
      config['threshold'] = rand(BOMB_MIN_MESSAGES..BOMB_MAX_MESSAGES)
      
      DB.save_bomb_config(sid, true, config['channel_id'], config['threshold'], 0)
    end
  end
end

bot.button(custom_id: /^bomb_/) do |event|
  bomb_id = event.custom_id

  if ACTIVE_BOMBS[bomb_id]
    ACTIVE_BOMBS.delete(bomb_id)
    reward = rand(50..150)
    final_reward = award_coins(event.bot, event.user.id, reward)

    defused_embed = Discordrb::Webhooks::Embed.new(
      title: "#{EMOJIS['surprise']} Bomb Defused!",
      description: "The bomb was successfully defused by #{event.user.mention}!\nThey earned **#{final_reward}** #{EMOJIS['s_coin']} for their bravery.",
      color: 0x00FF00 
    )
    event.update_message(content: nil, embeds: [defused_embed], components: Discordrb::Components::View.new)
  else
    event.respond(content: 'This bomb has already exploded or been defused!', ephemeral: true)
  end
end

bot.button(custom_id: /^defuse_drop_(\d+)$/) do |event|
  uid = event.user.id
  reward = rand(100..500)
  final_reward = award_coins(event.bot, uid, reward)

  embed = Discordrb::Webhooks::Embed.new(
    title: "#{EMOJIS['coins']} Bomb Defused!",
    description: "#{event.user.mention} successfully cut the wire!\nThey looted **#{final_reward}** #{EMOJIS['s_coin']} from the casing.",
    color: 0x00FF00
  )
  event.update_message(content: nil, embeds: [embed], components: [])
end

bot.command(:coinlb, description: 'Show the richest users globally', category: 'Economy') do |event|
  raw_top = DB.get_top_coins(50) 

  active_humans = []
  raw_top.each do |row|
    user_obj = event.bot.user(row['user_id'])
    if user_obj && !user_obj.bot_account?
      active_humans << row
      break if active_humans.size >= 10
    end
  end

  if active_humans.empty?
    send_embed(event, title: "#{EMOJIS['rich']} Wealth Leaderboard", description: 'The bank is currently empty!')
  else
    desc = active_humans.each_with_index.map do |row, index|
      user_obj = event.bot.user(row['user_id'])
      name = user_obj ? user_obj.display_name : "User #{row['user_id']}"
      "##{index + 1} — **#{name}**: **#{row['coins']}** #{EMOJIS['s_coin']}"
    end.join("\n")

    send_embed(event, title: "#{EMOJIS['rich']} Global Wealth Leaderboard", description: desc)
  end
  nil
end