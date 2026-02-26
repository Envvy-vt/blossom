# =========================
# PLAYER TRADING SYSTEM
# =========================

bot.command(:trade, description: 'Trade a character with someone (Usage: !trade @user <My Char> for <Their Char>)', category: 'Gacha') do |event, *args|
  target_user = event.message.mentions.first
  
  if target_user.nil? || target_user.id == event.user.id
    send_embed(
      event, 
      title: "#{EMOJIS['confused']} Invalid Trade", 
      description: "You must ping the person you want to trade with!\n**Usage:** `#{PREFIX}trade @user <Your Character> for <Their Character>`"
    )
    next
  end

  full_text = args.join(' ')
  clean_text = full_text.gsub(/<@!?#{target_user.id}>/, '').strip
  parts = clean_text.split(/ for /i)
  
  if parts.size != 2
    send_embed(
      event, 
      title: "#{EMOJIS['error']} Trade Formatting", 
      description: "Please format it exactly like this:\n`#{PREFIX}trade @user Gawr Gura for Filian`"
    )
    next
  end

  my_char_search = parts[0].strip.downcase
  their_char_search = parts[1].strip.downcase

  uid_a = event.user.id
  uid_b = target_user.id

  coll_a = DB.get_collection(uid_a)
  coll_b = DB.get_collection(uid_b)

  my_char_real = coll_a.keys.find { |k| k.downcase == my_char_search }
  their_char_real = coll_b.keys.find { |k| k.downcase == their_char_search }

  if my_char_real.nil? || coll_a[my_char_real]['count'] < 1
    send_embed(event, title: "#{EMOJIS['x_']} Missing Character", description: "You don't own **#{parts[0].strip}** to trade!")
    next
  end

  if their_char_real.nil? || coll_b[their_char_real]['count'] < 1
    send_embed(event, title: "#{EMOJIS['x_']} Missing Character", description: "#{target_user.mention} doesn't own **#{parts[1].strip}**!")
    next
  end

  expire_time = Time.now + 120
  trade_id = "trade_#{expire_time.to_i}_#{rand(1000)}"

  ACTIVE_TRADES[trade_id] = {
    user_a: uid_a,
    user_b: uid_b,
    char_a: my_char_real,
    char_b: their_char_real,
    expires: expire_time
  }

  embed = Discordrb::Webhooks::Embed.new(
    title: '🤝 Trade Offer!',
    description: "#{target_user.mention}, #{event.user.mention} wants to trade with you!\n\nThey are offering **#{my_char_real}** in exchange for your **#{their_char_real}**.\n\nDo you accept? (Offer expires <t:#{expire_time.to_i}:R>)",
    color: NEON_COLORS.sample
  )

  view = Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "#{trade_id}_accept", label: 'Accept', style: :success, emoji: '✅')
      r.button(custom_id: "#{trade_id}_decline", label: 'Decline', style: :danger, emoji: '❌')
    end
  end

  msg = event.channel.send_message(nil, false, embed, nil, nil, event.message, view)

  Thread.new do
    sleep 120
    if ACTIVE_TRADES.key?(trade_id)
      ACTIVE_TRADES.delete(trade_id)
      failed_embed = Discordrb::Webhooks::Embed.new(title: '⏳ Trade Expired', description: 'The trade offer timed out.', color: 0x808080)
      msg.edit(nil, failed_embed, Discordrb::Components::View.new)
    end
  end

  nil
end

bot.button(custom_id: /^trade_\d+_\d+_(accept|decline)$/) do |event|
  match_data = event.custom_id.match(/^(trade_\d+_\d+)_(accept|decline)$/)
  trade_id = match_data[1]
  action   = match_data[2]

  unless ACTIVE_TRADES.key?(trade_id)
    event.respond(content: 'This trade has expired or already been processed!', ephemeral: true)
    next
  end

  trade_data = ACTIVE_TRADES[trade_id]

  if event.user.id != trade_data[:user_b]
    event.respond(content: "Only the person receiving the trade offer can click this!", ephemeral: true)
    next
  end

  ACTIVE_TRADES.delete(trade_id)

  if action == 'decline'
    declined_embed = Discordrb::Webhooks::Embed.new(title: '🚫 Trade Declined', description: "#{event.user.mention} rejected the trade offer.", color: 0xFF0000)
    event.update_message(content: nil, embeds: [declined_embed], components: Discordrb::Components::View.new)
    next
  end

  uid_a = trade_data[:user_a]
  uid_b = trade_data[:user_b]
  char_a = trade_data[:char_a]
  char_b = trade_data[:char_b]

  coll_a = DB.get_collection(uid_a)
  coll_b = DB.get_collection(uid_b)

  if coll_a[char_a].nil? || coll_a[char_a]['count'] < 1 || coll_b[char_b].nil? || coll_b[char_b]['count'] < 1
    error_embed = Discordrb::Webhooks::Embed.new(title: '❌ Trade Failed', description: "Someone no longer has the character they offered! The trade has been cancelled.", color: 0xFF0000)
    event.update_message(content: nil, embeds: [error_embed], components: Discordrb::Components::View.new)
    next
  end

  rarity_a = coll_a[char_a]['rarity']
  rarity_b = coll_b[char_b]['rarity']

  DB.remove_character(uid_a, char_a, 1)
  DB.remove_character(uid_b, char_b, 1)

  DB.add_character(uid_a, char_b, rarity_b, 1)
  DB.add_character(uid_b, char_a, rarity_a, 1)

  success_embed = Discordrb::Webhooks::Embed.new(
    title: '🎉 Trade Successful!',
    description: "The trade was a success!\n\n<@#{uid_a}> received **#{char_b}**.\n<@#{uid_b}> received **#{char_a}**.",
    color: 0x00FF00
  )
  
  event.update_message(content: nil, embeds: [success_embed], components: Discordrb::Components::View.new)
end