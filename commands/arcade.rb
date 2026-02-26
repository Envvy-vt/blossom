# =========================
# ARCADE GAMES
# =========================

bot.command(:coinflip, description: 'Bet your stream revenue on a coinflip!', category: 'Arcade') do |event, amount_str, choice|
  if amount_str.nil? || choice.nil?
    send_embed(event, title: "#{EMOJIS['confused']} Missing Arguments", description: "You need to tell me how much to bet and what side you want!\n\n**Usage:** `#{PREFIX}coinflip <amount> <heads/tails>`\n**Example:** `#{PREFIX}coinflip 50 heads`")
    next
  end

  uid = event.user.id
  amount = amount_str.to_i
  choice = choice.downcase

  if amount <= 0
    send_embed(event, title: "#{EMOJIS['error']} Invalid Bet", description: "You must bet at least 1 #{EMOJIS['s_coin']}.")
    next
  end

  if DB.get_coins(uid) < amount
    send_embed(event, title: "#{EMOJIS['nervous']} Insufficient Funds", description: "You don't have enough coins to cover that bet!\nYou currently have **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}.")
    next
  end

  unless ['heads', 'tails'].include?(choice)
    send_embed(event, title: "#{EMOJIS['error']} Invalid Choice", description: "Please pick either `heads` or `tails`.")
    next
  end

  result = ['heads', 'tails'].sample
  DB.add_coins(uid, -amount)
  
  if choice == result
    DB.add_coins(uid, amount * 2)
    send_embed(event, title: "🪙 Coinflip: #{result.capitalize}!", description: "You won! You doubled your bet and earned **#{amount}** #{EMOJIS['s_coin']}.\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  else
    send_embed(event, title: "🪙 Coinflip: #{result.capitalize}!", description: "You lost... **#{amount}** #{EMOJIS['s_coin']} down the drain.\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  end
  nil
end

bot.command(:slots, description: 'Spin the neon slots!', category: 'Arcade') do |event, amount_str|
  if amount_str.nil?
    send_embed(event, title: "#{EMOJIS['confused']} Missing Arguments", description: "You need to drop some coins into the machine first!\n\n**Usage:** `#{PREFIX}slots <amount>`\n**Example:** `#{PREFIX}slots 100`")
    next
  end

  uid = event.user.id
  amount = amount_str.to_i

  if amount <= 0 || DB.get_coins(uid) < amount
    send_embed(event, title: "#{EMOJIS['error']} Invalid Bet", description: "You don't have enough coins or entered an invalid amount!\nYou currently have **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}.")
    next
  end

  DB.add_coins(uid, -amount)

  slot_icons = ['🍒', '🍋', '🔔', '💎', '7️⃣']
  spin = [slot_icons.sample, slot_icons.sample, slot_icons.sample]

  if spin.uniq.size == 1
    winnings = amount * 5
    DB.add_coins(uid, winnings)
    send_embed(event, title: "🎰 Neon Slots", description: "[ #{spin.join(' | ')} ]\n\n**JACKPOT!** #{EMOJIS['sparkle']}\nYou won **#{winnings}** #{EMOJIS['s_coin']}!\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  elsif spin.uniq.size == 2
    winnings = amount * 2
    DB.add_coins(uid, winnings)
    send_embed(event, title: "🎰 Neon Slots", description: "[ #{spin.join(' | ')} ]\n\nNice! You matched two and won **#{winnings}** #{EMOJIS['s_coin']}!\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  else
    send_embed(event, title: "🎰 Neon Slots", description: "[ #{spin.join(' | ')} ]\n\nYou lost your bet... Better luck next spin. #{EMOJIS['worktired']}\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  end
  nil
end

bot.command(:roulette, description: 'Bet on the roulette wheel!', category: 'Arcade') do |event, amount_str, bet_str|
  if amount_str.nil? || bet_str.nil?
    send_embed(event, title: "#{EMOJIS['confused']} Missing Arguments", description: "Place your bets!\n\n**Usage:** `#{PREFIX}roulette <amount> <bet>`\n**Valid Bets:** `red`, `black`, `even`, `odd`, or a number `0-36`.\n**Examples:**\n> `#{PREFIX}roulette 100 red`\n> `#{PREFIX}roulette 50 17`")
    next
  end

  uid = event.user.id
  amount = amount_str.to_i
  bet = bet_str.downcase

  if amount <= 0 || DB.get_coins(uid) < amount
    send_embed(event, title: "#{EMOJIS['error']} Invalid Bet", description: "You don't have enough coins or entered an invalid amount!")
    next
  end

  red_numbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
  valid_bets = ['red', 'black', 'even', 'odd'] + (0..36).map(&:to_s)

  unless valid_bets.include?(bet)
    send_embed(event, title: "#{EMOJIS['error']} Invalid Bet Type", description: "You can only bet on `red`, `black`, `even`, `odd`, or a number from `0` to `36`.")
    next
  end

  DB.add_coins(uid, -amount)
  spin = rand(0..36)
  
  spin_color = 'green'
  if red_numbers.include?(spin)
    spin_color = 'red'
  elsif spin != 0
    spin_color = 'black'
  end

  is_even = (spin != 0 && spin.even?) ? 'even' : nil
  is_odd = (spin != 0 && spin.odd?) ? 'odd' : nil

  win = false
  payout = 0

  if bet == spin.to_s
    win = true; payout = amount * 36
  elsif bet == spin_color || bet == is_even || bet == is_odd
    win = true; payout = amount * 2 
  end

  color_emoji = spin_color == 'red' ? '🔴' : (spin_color == 'black' ? '⚫' : '🟢')

  if win
    DB.add_coins(uid, payout)
    send_embed(event, title: "🎰 Roulette Spin", description: "The dealer spins the wheel... It lands on **#{color_emoji} #{spin}**!\n\nYou bet on **#{bet}** and won **#{payout}** #{EMOJIS['s_coin']}!\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  else
    send_embed(event, title: "🎰 Roulette Spin", description: "The dealer spins the wheel... It lands on **#{color_emoji} #{spin}**.\n\nYou bet on **#{bet}** and lost **#{amount}** #{EMOJIS['s_coin']}.\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  end
  nil
end

bot.command(:scratch, description: 'Buy a neon scratch-off ticket for 500 coins!', category: 'Arcade') do |event|
  uid = event.user.id
  ticket_price = 500

  if DB.get_coins(uid) < ticket_price
    send_embed(event, title: "#{EMOJIS['nervous']} Insufficient Funds", description: "You need **#{ticket_price}** #{EMOJIS['s_coin']} to buy a scratch-off ticket.")
    next
  end

  DB.add_coins(uid, -ticket_price)

  pool = ['💀', '💀', '💀', '🍒', '🍒', '🍋', '🍋', '💎', '🌟']
  result = [pool.sample, pool.sample, pool.sample]

  if result.uniq.size == 1
    payout = case result[0]
             when '🌟' then 10000 
             when '💎' then 5000  
             when '🍋' then 2500  
             when '🍒' then 1000  
             when '💀' then 500   
             else 0
             end

    DB.add_coins(uid, payout)
    send_embed(event, title: "🎫 Scratch-Off Ticket", description: "**[ #{result.join(' | ')} ]**\n\n**WINNER!** You matched three **#{result[0]}** and won **#{payout}** #{EMOJIS['s_coin']}!\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  else
    send_embed(event, title: "🎫 Scratch-Off Ticket", description: "**[ #{result.join(' | ')} ]**\n\nNo match... Better luck next ticket. #{EMOJIS['worktired']}\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  end
  nil
end

bot.command(:dice, description: 'Roll 2d6! Bet on high (8-12), low (2-6), or 7.', category: 'Arcade') do |event, amount_str, bet|
  if amount_str.nil? || bet.nil?
    send_embed(event, title: "#{EMOJIS['confused']} Missing Arguments", description: "Place your bets on the dice!\n\n**Usage:** `#{PREFIX}dice <amount> <high/low/7>`")
    next
  end

  uid = event.user.id
  amount = amount_str.to_i
  bet = bet.downcase

  if amount <= 0 || DB.get_coins(uid) < amount
    send_embed(event, title: "#{EMOJIS['error']} Invalid Bet", description: "You don't have enough coins or entered an invalid amount!")
    next
  end

  unless ['high', 'low', '7'].include?(bet)
    send_embed(event, title: "#{EMOJIS['error']} Invalid Bet Type", description: "You can only bet on `high`, `low`, or `7`.")
    next
  end

  DB.add_coins(uid, -amount)
  die1 = rand(1..6)
  die2 = rand(1..6)
  total = die1 + die2

  actual_result = total < 7 ? 'low' : (total > 7 ? 'high' : '7')

  if bet == actual_result
    payout = (bet == '7') ? (amount * 4) : (amount * 2)
    DB.add_coins(uid, payout)
    send_embed(event, title: "🎲 High Roller Dice", description: "The dice roll... **#{die1}** and **#{die2}**! (Total: **#{total}**)\n\nYou correctly bet on **#{bet}** and won **#{payout}** #{EMOJIS['s_coin']}!\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  else
    send_embed(event, title: "🎲 High Roller Dice", description: "The dice roll... **#{die1}** and **#{die2}**! (Total: **#{total}**)\n\nYou bet on **#{bet}** and lost **#{amount}** #{EMOJIS['s_coin']}.\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  end
  nil
end

bot.command(:cups, description: 'Guess which cup hides the coin (1, 2, or 3)!', category: 'Arcade') do |event, amount_str, guess_str|
  if amount_str.nil? || guess_str.nil?
    send_embed(event, title: "#{EMOJIS['confused']} Missing Arguments", description: "Keep your eye on the cup!\n\n**Usage:** `#{PREFIX}cups <amount> <1/2/3>`")
    next
  end

  uid = event.user.id
  amount = amount_str.to_i
  guess = guess_str.to_i

  if amount <= 0 || DB.get_coins(uid) < amount
    send_embed(event, title: "#{EMOJIS['error']} Invalid Bet", description: "You don't have enough coins or entered an invalid amount!")
    next
  end

  unless [1, 2, 3].include?(guess)
    send_embed(event, title: "#{EMOJIS['error']} Invalid Cup", description: "You must pick cup `1`, `2`, or `3`.")
    next
  end

  DB.add_coins(uid, -amount)
  winning_cup = [1, 2, 3].sample
  cups_display = [1, 2, 3].map { |c| c == winning_cup ? '🪙' : '🥤' }.join('   ')

  if guess == winning_cup
    payout = amount * 3
    DB.add_coins(uid, payout)
    send_embed(event, title: "🥤 The Shell Game", description: "Blossom lifts cup ##{winning_cup}...\n\n**#{cups_display}**\n\nYou found it! You won **#{payout}** #{EMOJIS['s_coin']}!\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  else
    send_embed(event, title: "🥤 The Shell Game", description: "Blossom lifts cup ##{guess}...\nEmpty! The coin was under cup ##{winning_cup}.\n\n**#{cups_display}**\n\nYou lost **#{amount}** #{EMOJIS['s_coin']}.\nNew Balance: **#{DB.get_coins(uid)}** #{EMOJIS['s_coin']}")
  end
  nil
end