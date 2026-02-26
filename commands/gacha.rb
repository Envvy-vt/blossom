# =========================
# GACHA COMMANDS
# =========================

bot.command(:summon, description: 'Roll the gacha!', category: 'Gacha') do |event|
  uid = event.user.id

  if summon_cooldowns[uid] && Time.now < summon_cooldowns[uid]
    ready_time = summon_cooldowns[uid].to_i
    embed = Discordrb::Webhooks::Embed.new(
      title: "#{EMOJIS['drink']} Portal Recharging",
      description: "Your gacha energy is depleted!\nThe portal will be ready <t:#{ready_time}:R>.",
      color: 0xFF0000 
    )
    event.channel.send_message(nil, false, embed, nil, nil, event.message)
    next
  end

  if coins[uid] < SUMMON_COST
    send_embed(
      event,
      title: "#{EMOJIS['info']} Summon",
      description: "You need **#{SUMMON_COST}** #{EMOJIS['s_coin']} to summon.\nYou currently have **#{coins[uid]}**."
    )
    next
  end

  coins[uid] -= SUMMON_COST

  active_banner = get_current_banner
  rarity = roll_rarity
  pulled_char = active_banner[:characters][rarity].sample
  
  name = pulled_char[:name]
  gif_url = pulled_char[:gif]
  
  collections[uid][name] ||= { 'rarity' => rarity.to_s, 'count' => 0 }
  collections[uid][name]['count'] += 1

  rarity_label = rarity.to_s.capitalize
  emoji = case rarity
          when :goddess   then '💎'
          when :legendary then '🌟'
          when :rare      then '✨'
          else '⭐'
          end

  send_embed(
    event,
    title: "#{EMOJIS['sparkle']} Summon Result: #{active_banner[:name]}",
    description: "#{emoji} You summoned **#{name}** (#{rarity_label})!\nYou now own **#{collections[uid][name]['count']}** of them.",
    fields: [
      { name: 'Remaining Balance', value: "#{coins[uid]} #{EMOJIS['s_coin']}", inline: true }
    ],
    image: gif_url
  )

  summon_cooldowns[uid] = Time.now + 600
  nil
end

bot.command(:collection, description: 'View your vtuber collection', category: 'Fun') do |event|
  target_user = event.user
  embed = generate_collection_page(target_user, collections, 'common')
  view  = collection_view(target_user.id, 'common', collections) 
  
  event.channel.send_message(nil, false, embed, nil, { replied_user: false }, event.message, view)
  nil
end

bot.command(:banner, description: 'Check which characters are in the gacha pool this week!', category: 'Gacha') do |event|
  active_banner = get_current_banner
  chars = active_banner[:characters]

  week_number = Time.now.to_i / 604_800 
  available_pools = CHARACTER_POOLS.keys
  next_key = available_pools[(week_number + 1) % available_pools.size]
  next_banner = CHARACTER_POOLS[next_key]
  next_rotation_time = (week_number + 1) * 604_800

  fields = [
    { name: '🌟 Legendaries (5%)', value: chars[:legendary].map { |c| c[:name] }.join(', '), inline: false },
    { name: '✨ Rares (25%)', value: chars[:rare].map { |c| c[:name] }.join(', '), inline: false },
    { name: '⭐ Commons (69%)', value: chars[:common].map { |c| c[:name] }.join(', '), inline: false }
  ]

  desc = "Here are the VTubers you can pull this week!\n\n"
  desc += "**Next Rotation:** <t:#{next_rotation_time}:R>\n"
  desc += "**Up Next:** #{next_banner[:name]}"

  send_embed(
    event,
    title: "#{EMOJIS['neonsparkle']} Current Gacha: #{active_banner[:name]}",
    description: desc,
    fields: fields
  )
  nil
end

bot.button(custom_id: /^coll_(common|rare|legendary|goddess)_(\d+)$/) do |event|
  match_data = event.custom_id.match(/^coll_(common|rare|legendary|goddess)_(\d+)$/)
  requested_page = match_data[1]
  target_uid     = match_data[2].to_i
  
  if event.user.id != target_uid
    event.respond(content: "You can only flip the pages of your own collection! Use `!collection` to view yours.", ephemeral: true)
    next
  end

  target_user = event.user
  new_embed = generate_collection_page(target_user, collections, requested_page)
  new_view  = collection_view(target_uid, requested_page, collections)
  
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

bot.command(:shop, description: 'View the character shop and direct-buy prices!', category: 'Gacha') do |event|
  embed, view = build_shop_home(event.user.id)
  event.channel.send_message(nil, false, embed, nil, { replied_user: false }, event.message, view)
  nil
end

bot.command(:buy, description: 'Buy a character or tech upgrade (Usage: !buy <Name>)', min_args: 1, category: 'Gacha') do |event, *name_args|
  uid = event.user.id
  search_name = name_args.join(' ').downcase

  if BLACK_MARKET_ITEMS.key?(search_name)
    item_data = BLACK_MARKET_ITEMS[search_name]
    price = item_data[:price]

    if coins[uid] < price
      send_embed(event, title: "#{EMOJIS['nervous']} Insufficient Funds", description: "You need **#{price}** #{EMOJIS['s_coin']} to buy the #{item_data[:name]}.\nYou currently have **#{coins[uid]}** #{EMOJIS['s_coin']}.")
      next
    end

    if item_data[:type] == 'upgrade' && inventory[uid] && inventory[uid][search_name] && inventory[uid][search_name] >= 1
      send_embed(event, title: "#{EMOJIS['confused']} Already Owned", description: "You already have the **#{item_data[:name]}** equipped in your setup!")
      next
    end

    coins[uid] -= price
    inventory[uid] ||= {}
    inventory[uid][search_name] ||= 0
    inventory[uid][search_name] += 1

    if search_name == 'gamer fuel'
      inventory[uid][search_name] -= 1 
      economy_cooldowns[uid]['stream_at'] = nil
      economy_cooldowns[uid]['post_at'] = nil
      economy_cooldowns[uid]['collab_at'] = nil
      
      # FIX: Removed the custom color tag here!
      send_embed(event, title: "🥫 Gamer Fuel Consumed!", description: "You cracked open a cold one and chugged it.\n**ALL your content creation cooldowns have been reset!** Get back to the grind.")
      next
    end

    send_embed(event, title: "🛒 Item Purchased!", description: "You successfully bought the **#{item_data[:name]}** for **#{price}** #{EMOJIS['s_coin']}!\nIt has been added to your inventory/setup.")
    next
  end

  result = find_character_in_pools(search_name)
  
  unless result
    send_embed(
      event,
      title: "#{EMOJIS['error']} Shop Error",
      description: "I couldn't find a character or item named **#{name_args.join(' ')}**. Check your spelling!"
    )
    next
  end

  char_data = result[:char]
  rarity    = result[:rarity]
  price     = SHOP_PRICES[rarity]

  if price.nil?
    send_embed(
      event,
      title: "#{EMOJIS['x_']} Black Market Locked",
      description: "You cannot directly purchase **#{char_data[:name]}**. She can only be obtained through the gacha portal."
    )
    next
  end

  if coins[uid] < price
    send_embed(
      event,
      title: "#{EMOJIS['nervous']} Insufficient Funds",
      description: "You need **#{price}** #{EMOJIS['s_coin']} to buy a #{rarity.capitalize} character.\nYou currently have **#{coins[uid]}** #{EMOJIS['s_coin']}."
    )
    next
  end

  coins[uid] -= price
  
  name = char_data[:name]
  gif_url = char_data[:gif]

  collections[uid][name] ||= { 'rarity' => rarity, 'count' => 0 }
  collections[uid][name]['count'] += 1

  emoji = case rarity
          when 'goddess'   then '💎'
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end

  send_embed(
    event,
    title: "#{EMOJIS['coins']} Purchase Successful!",
    description: "#{emoji} You directly purchased **#{name}** for **#{price}** #{EMOJIS['s_coin']}!\nYou now own **#{collections[uid][name]['count']}** of them.",
    fields: [
      { name: 'Remaining Balance', value: "#{coins[uid]} #{EMOJIS['s_coin']}", inline: true }
    ],
    image: gif_url
  )
  
  nil
end

bot.command(:view, description: 'Look at a specific character you own', min_args: 1, category: 'Gacha') do |event, *name_args|
  uid = event.user.id
  search_name = name_args.join(' ')
  user_chars = collections[uid] || {}
  
  owned_name = user_chars.keys.find { |k| k.downcase == search_name.downcase }
  
  unless owned_name && (user_chars[owned_name]['count'] > 0 || user_chars[owned_name]['ascended'].to_i > 0)
    send_embed(
      event,
      title: "#{EMOJIS['confused']} Character Not Found",
      description: "You don't own **#{search_name}** yet!\nUse `#{PREFIX}summon` to roll for them, or `#{PREFIX}buy` to get them from the shop."
    )
    next
  end
  
  result = find_character_in_pools(owned_name)
  char_data = result[:char]
  rarity    = result[:rarity]
  count     = user_chars[owned_name]['count']
  ascended  = user_chars[owned_name]['ascended'].to_i
  
  emoji = case rarity
          when 'goddess'   then '💎'
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end
          
  desc = "You currently own **#{count}** standard copies of this character.\n"
  desc += "✨ **You own #{ascended} Shiny Ascended copies!** ✨" if ascended > 0

  send_embed(
    event,
    title: "#{emoji} #{owned_name} (#{rarity.capitalize})",
    description: desc,
    image: char_data[:gif]
  )
  nil
end

bot.command(:ascend, description: 'Fuse 5 duplicate characters into a Shiny Ascended version!', min_args: 1, category: 'Gacha') do |event, *name_args|
  uid = event.user.id
  search_name = name_args.join(' ').downcase
  user_chars = collections[uid] || {}
  
  owned_name = user_chars.keys.find { |k| k.downcase == search_name }

  unless owned_name
    send_embed(event, title: "#{EMOJIS['error']} Ascension Failed", description: "You don't own any copies of **#{name_args.join(' ')}**!")
    next
  end

  if user_chars[owned_name]['count'] < 5
    send_embed(event, title: "#{EMOJIS['nervous']} Not Enough Copies", description: "You need **5 copies** of #{owned_name} to ascend them. You only have **#{user_chars[owned_name]['count']}**.")
    next
  end

  ascension_cost = 5000
  if coins[uid] < ascension_cost
    send_embed(event, title: "#{EMOJIS['nervous']} Insufficient Funds", description: "The ritual costs **#{ascension_cost}** #{EMOJIS['s_coin']}. You currently have **#{coins[uid]}** #{EMOJIS['s_coin']}.")
    next
  end

  # Perform the Ritual
  coins[uid] -= ascension_cost
  user_chars[owned_name]['count'] -= 5
  user_chars[owned_name]['ascended'] ||= 0
  user_chars[owned_name]['ascended'] += 1

  # FIX: Removed the custom color tag here!
  send_embed(
    event,
    title: "✨ Ascension Complete! ✨",
    description: "You paid **#{ascension_cost}** #{EMOJIS['s_coin']} and fused 5 copies of **#{owned_name}** together!\n\nThey have been reborn as a **Shiny Ascended** character. View them in your `!collection`!"
  )
  nil
end

bot.button(custom_id: /^shop_catalog_(\d+)_(\d+)$/) do |event|
  match_data = event.custom_id.match(/^shop_catalog_(\d+)_(\d+)$/)
  uid  = match_data[1].to_i
  page = match_data[2].to_i
  
  if event.user.id != uid
    event.respond(content: "You cannot use someone else's shop menu! Type `!shop` to open your own.", ephemeral: true)
    next
  end

  new_embed, new_view = build_shop_catalog(uid, page)
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

bot.button(custom_id: /^shop_home_(\d+)$/) do |event|
  uid = event.custom_id.match(/^shop_home_(\d+)$/)[1].to_i
  
  if event.user.id != uid
    event.respond(content: "You cannot use someone else's shop menu!", ephemeral: true)
    next
  end

  new_embed, new_view = build_shop_home(uid)
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

bot.button(custom_id: /^shop_sell_(\d+)$/) do |event|
  uid = event.custom_id.match(/^shop_sell_(\d+)$/)[1].to_i
  
  if event.user.id != uid
    event.respond(content: "You cannot sell someone else's characters!", ephemeral: true)
    next
  end

  user_collection = collections[uid] || {}
  total_earned = 0
  dupes_sold = 0

  user_collection.each do |name, data|
    if data['count'] > 1
      sell_amount = data['count'] - 1
      rarity = data['rarity']
      coins_earned = sell_amount * SELL_PRICES[rarity]
      
      total_earned += coins_earned
      dupes_sold += sell_amount
      data['count'] = 1 
    end
  end

  embed = Discordrb::Webhooks::Embed.new
  view = Discordrb::Components::View.new do |v|
    v.row { |r| r.button(custom_id: "shop_home_#{uid}", label: 'Back to Shop', style: :secondary, emoji: '🔙') }
  end

  if dupes_sold > 0
    coins[uid] += total_earned
    embed.title = "#{EMOJIS['rich']} Duplicates Sold!"
    embed.description = "You converted **#{dupes_sold}** duplicate characters into **#{total_earned}** #{EMOJIS['s_coin']}!\n\nNew Balance: **#{coins[uid]}** #{EMOJIS['s_coin']}."
    embed.color = 0x00FF00
  else
    embed.title = "#{EMOJIS['confused']} No Duplicates"
    embed.description = "You don't have any duplicate characters to sell right now! You currently have 1 or 0 copies of everyone."
    embed.color = 0xFF0000 
  end

  event.update_message(content: nil, embeds: [embed], components: view)
end

# =========================
# TECH SHOP LISTENER
# =========================
bot.button(custom_id: /^shop_blackmarket_(\d+)$/) do |event|
  begin
    puts ">>> [DEBUG] Black Market button clicked!"
    uid = event.custom_id.match(/^shop_blackmarket_(\d+)$/)[1].to_i
    
    if event.user.id != uid
      event.respond(content: "You cannot use someone else's shop menu!", ephemeral: true)
      next
    end

    new_embed, new_view = build_blackmarket_page(uid)
    event.update_message(content: nil, embeds: [new_embed], components: new_view)
    puts ">>> [DEBUG] Black Market menu successfully rendered!"
    
  rescue => e
    puts "!!! [CRITICAL ERROR] in Black Market Button !!!"
    puts e.message
    puts e.backtrace
  end
end