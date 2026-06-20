# ==========================================
# HELPER: Economy & Gacha Engine
# DESCRIPTION: Premium role checks, coin multipliers, 
# and character pool mathematics.
# ==========================================

# Server IDs => Role IDs 
PREMIUM_SERVERS = {
  1125196330646638592 => 1125222184533639338,
  1499998845873033316 => 1500326377780547604
}

# Idempotent: used after verified Ko‑fi membership webhook (when caller has discord_user_id).
# Grants each PREMIUM_SERVERS role where the bot is present and member is in-guild (skips if already role).
def grant_premium_roles_after_kofi(bot, discord_user_id)
  uid = discord_user_id.to_i
  return unless uid.positive?

  PREMIUM_SERVERS.each do |guild_id, role_id|
    server = bot&.servers&.[](guild_id)
    unless server
      puts "[KOFI] Role sync skip — bot not connected to guild #{guild_id}"
      next
    end

    begin
      member = server.member(uid)
    rescue StandardError => e
      puts "[KOFI] Role sync skip — member #{uid} guild #{guild_id}: #{e.class}: #{e.message}"
      next
    end
    next unless member

    begin
      if member.roles.any? { |r| r.id == role_id }
        puts "[KOFI] Subscriber role #{role_id} already on #{uid} (#{guild_id})"
      else
        member.add_role(role_id)
        puts "[KOFI] Granted subscriber role #{role_id} to #{uid} (#{guild_id})"
      end
    rescue StandardError => e
      puts "[KOFI] add_role failed guild #{guild_id} role #{role_id} uid #{uid}: #{e.class}: #{e.message}"
    end
  end

  CACHE.invalidate(:premium, uid)
end

def is_premium?(bot, user_id)
  CACHE.fetch(:premium, user_id, ttl: CACHE_TTL_PREMIUM) do
    next true if DB.is_lifetime_premium?(user_id)

    result = false
    PREMIUM_SERVERS.each do |server_id, role_id|
      server = bot.servers[server_id]
      next unless server

      begin
        member = server.member(user_id)
      rescue
        next
      end
      next unless member

      if member.roles.any? { |role| role.id == role_id }
        result = true
        break
      end
    end
    result
  end
end

def happy_hour_active?
  $happy_hour && Time.now < $happy_hour[:ends_at]
end

# Same payout math as `award_coins` / daily claims — Premium + happy-hour + crew
# multipliers applied to raw `amount`, no DB writes. Used before atomic commits.
def calculate_coin_payout(bot, user_id, raw_amount)
  final_amount = raw_amount.to_f

  if happy_hour_active?
    multiplier = is_premium?(bot, user_id) ? 3 : HAPPY_HOUR_MULTIPLIER
    final_amount = (raw_amount.to_f * multiplier).round.to_f
  elsif is_premium?(bot, user_id)
    final_amount = (raw_amount.to_f * 1.10).round.to_f
  else
    final_amount = raw_amount.to_f.round.to_f
  end

  crew = DB.get_user_crew(user_id)
  final_amount = (final_amount * (1 + CREW_COIN_BONUS)).round.to_f if crew

  final_amount.to_i
end

# Awards crew XP derived from coins actually credited (matches legacy tier math).
def grant_crew_xp_for_coin_payout(user_id, coin_payout, bot = nil)
  crew = DB.get_user_crew(user_id)
  return unless crew

  crew_xp_gain = [coin_payout / 50, 1].max
  b = bot || (defined?($bot) ? $bot : nil)
  if b && is_premium?(b, user_id)
    crew_xp_gain = (crew_xp_gain * PREMIUM_CREW_XP_MULT).round
  end
  award_crew_xp(crew['id'], crew_xp_gain)
rescue => e
  puts "[CREW BONUS ERROR] #{e.message}"
end

# True when /daily (and remindme pings) may fire — same rolling window as the daily command.
def daily_cooldown_ready?(last_used, now = Time.now)
  return true unless last_used

  last = last_used.is_a?(Time) ? last_used : Time.parse(last_used.to_s)
  (now - last) >= DAILY_COOLDOWN
end

def daily_cooldown_remaining(last_used, now = Time.now)
  return 0 unless last_used

  last = last_used.is_a?(Time) ? last_used : Time.parse(last_used.to_s)
  rem = DAILY_COOLDOWN - (now - last)
  rem.positive? ? rem : 0
end

# Daily streak: >48h gap normally resets; subscribers with /autoclaim on keep once per ISO week via insurance.
def resolve_daily_streak(bot, uid, last_used, now, current_streak)
  if last_used.nil? || (now - last_used) > (DAILY_COOLDOWN * 2)
    can_save = current_streak >= 1 && is_premium?(bot, uid) && DB.get_autoclaim(uid) && DB.can_use_streak_insurance?(uid)
    if can_save
      DB.consume_streak_insurance(uid)
      [current_streak + 1, :insurance]
    else
      [1, :reset]
    end
  else
    [current_streak + 1, :continued]
  end
end

def award_coins(bot, user_id, amount)
  payout = calculate_coin_payout(bot, user_id, amount)
  grant_crew_xp_for_coin_payout(user_id, payout, bot)

  DB.add_coins(user_id, payout)
  payout
end

# Award XP to a crew and handle level-up
def award_crew_xp(crew_id, amount)
  DB.add_crew_xp(crew_id, amount)
  crew = DB.get_crew(crew_id)
  return unless crew

  # Check for level-up (XP threshold scales per level)
  xp_needed = crew['crew_level'] * CREW_XP_PER_LEVEL
  if crew['crew_xp'] >= xp_needed
    new_level = crew['crew_level'] + 1
    DB.set_crew_level(crew_id, new_level)
    # Reset XP overflow (keep remainder)
    overflow = crew['crew_xp'] - xp_needed
    DB.add_crew_xp(crew_id, -xp_needed) if overflow >= 0
  end
rescue => e
  puts "[CREW XP ERROR] #{e.message}"
end

def calculate_investment_value(principal, invested_at)
  hours_elapsed = (Time.now - invested_at) / 3600.0
  return { principal: principal, profit: 0, total: principal, hours: 0 } if hours_elapsed < 0

  raw_profit = (principal * ((1 + INVEST_RATE_PER_HOUR) ** hours_elapsed) - principal).round
  max_profit = (principal * INVEST_PROFIT_CAP).round
  profit = [raw_profit, max_profit].min
  { principal: principal, profit: profit, total: principal + profit, hours: hours_elapsed }
end

def roll_rarity(premium = false)
  roll = rand(100)
  premium_table = { common: 55, rare: 36, legendary: 7, goddess: 2 }
  active_table = premium ? premium_table : RARITY_TABLE
  
  total = 0
  active_table.each do |(rarity, weight)|
    total += weight
    return rarity if roll < total
  end
  :common
end

def get_current_banner
  base_pool = Marshal.load(Marshal.dump(UNIVERSAL_POOL))

  if Time.now.month == SPRING_CARNIVAL[:month]
    SPRING_CARNIVAL[:characters].each do |rarity, chars|
      base_pool[:characters][rarity] ||= []
      base_pool[:characters][rarity].concat(chars)
    end
  end
  base_pool
end

# Returns the active banner for a user: custom banner if active, otherwise universal
def get_user_banner(uid)
  custom = DB.get_custom_banner(uid)
  if custom
    return custom
  end
  get_current_banner
end

def find_character_in_pools(search_name, include_event: false)
  if include_event || Time.now.month == SPRING_CARNIVAL[:month]
    SPRING_CARNIVAL[:characters].each do |rarity, char_list|
      found = char_list.find { |c| c[:name].downcase == search_name.downcase }
      return { char: found, rarity: rarity.to_s } if found
    end
  end

  UNIVERSAL_POOL[:characters].each do |rarity, char_list|
    found = char_list.find { |c| c[:name].downcase == search_name.downcase }
    return { char: found, rarity: rarity.to_s } if found
  end
  nil
end

def is_event_character?(search_name)
  SPRING_CARNIVAL[:characters].values.flatten.any? do |char|
    char[:name].downcase == search_name.downcase
  end
end

def find_character_banner(search_name)
  if is_event_character?(search_name)
    return { banner: SPRING_CARNIVAL[:name], event: true }
  end

  UNIVERSAL_POOL[:characters].each do |_rarity, char_list|
    found = char_list.find { |c| c[:name].downcase == search_name.downcase }
    return { banner: UNIVERSAL_POOL[:name], event: false } if found
  end
  nil
end