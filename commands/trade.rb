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

  # Split the remaining text by the word "for" (ignoring uppercase/lowercase)
  full_text = args.join(' ')
  # Remove the @mention from the string so it doesn't mess up the character name
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

  # Find exact names in collections
  my_char_real = (collections[uid_a] || {}).keys.find { |k| k.downcase == my_char_search }
  their_char_real = (collections[uid_b] || {}).keys.find { |k| k.downcase == their_char_search }

  if my_char_real.nil? || collections[uid_a][my_char_real]['count'] < 1
    send_embed(event, title: "#{EMOJIS['x_']} Missing Character", description: "You don't own **#{parts[0].strip}** to trade!")
    next
  end

  if their_char_real.nil? || collections[uid_b][their_char_real]['count'] < 1
    send_embed(event, title: "#{EMOJIS['x_']} Missing Character", description: "#{target_user.mention} doesn't own **#{parts[1].strip}**!")
    next
  end

  # Generate a unique trade ID
  expire_time = Time.now + 120 # 2 minutes
  trade_id = "trade_#{expire_time.to_i}_#{rand(1000)}"

  # Store the data in escrow
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

  # Auto-expire thread
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

# Listener for Trade Buttons
bot.button(custom_id: /^trade_\d+_\d+_(accept|decline)$/) do |event|
  match_data = event.custom_id.match(/^(trade_\d+_\d+)_(accept|decline)$/)
  trade_id = match_data[1]
  action   = match_data[2]

  unless ACTIVE_TRADES.key?(trade_id)
    event.respond(content: 'This trade has expired or already been processed!', ephemeral: true)
    next
  end

  trade_data = ACTIVE_TRADES[trade_id]

  # Only the target (User B) can press the buttons!
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

  # ==============================
  # DOUBLE CHECK INVENTORY IN CASE THEY SOLD IT
  # ==============================
  uid_a = trade_data[:user_a]
  uid_b = trade_data[:user_b]
  char_a = trade_data[:char_a]
  char_b = trade_data[:char_b]

  if collections[uid_a][char_a]['count'] < 1 || collections[uid_b][char_b]['count'] < 1
    error_embed = Discordrb::Webhooks::Embed.new(title: '❌ Trade Failed', description: "Someone no longer has the character they offered! The trade has been cancelled.", color: 0xFF0000)
    event.update_message(content: nil, embeds: [error_embed], components: Discordrb::Components::View.new)
    next
  end

  # ==============================
  # SWAP THE CHARACTERS!
  # ==============================
  collections[uid_a][char_a]['count'] -= 1
  collections[uid_b][char_b]['count'] -= 1

  # Grab rarity from the original to ensure it carries over
  rarity_a = collections[uid_a][char_a]['rarity']
  rarity_b = collections[uid_b][char_b]['rarity']

  collections[uid_a][char_b] ||= { 'rarity' => rarity_b, 'count' => 0 }
  collections[uid_a][char_b]['count'] += 1

  collections[uid_b][char_a] ||= { 'rarity' => rarity_a, 'count' => 0 }
  collections[uid_b][char_a]['count'] += 1

  success_embed = Discordrb::Webhooks::Embed.new(
    title: '🎉 Trade Successful!',
    description: "The trade was a success!\n\n<@#{uid_a}> received **#{char_b}**.\n<@#{uid_b}> received **#{char_a}**.",
    color: 0x00FF00
  )
  
  event.update_message(content: nil, embeds: [success_embed], components: Discordrb::Components::View.new)
end