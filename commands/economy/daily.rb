# ==========================================
# COMMAND: daily
# DESCRIPTION: Claim daily rewards with a visual monthly login calendar.
# CATEGORY: Economy
# ==========================================

require 'date'

# ------------------------------------------
# HELPER: Render Monthly Calendar Grid
# ------------------------------------------
def render_calendar(year, month, claimed_days, today_day)
  month_name = Date::MONTHNAMES[month]
  first_day = Date.new(year, month, 1)
  days_in_month = Date.new(year, month, -1).day
  # Monday = 0, Sunday = 6 (ISO week)
  start_offset = first_day.cwday - 1

  header = "#{month_name} #{year}"
  grid = "```\n#{header.center(27)}\nMo  Tu  We  Th  Fr  Sa  Su\n"

  # Leading blanks
  grid += "    " * start_offset

  (1..days_in_month).each do |day|
    if claimed_days.include?(day)
      cell = " \u2588\u2588" # Filled block = claimed
    elsif day == today_day
      cell = " \u25B6\u25B6" # Arrow = today (claimable)
    elsif day < today_day
      cell = " \u00B7\u00B7" # Dot = missed
    else
      cell = "  --" # Dash = future
    end
    grid += cell

    col = (start_offset + day) % 7
    grid += "\n" if col == 0 && day < days_in_month
  end

  grid += "\n```"
  grid
end

# ------------------------------------------
# LOGIC: Daily Reward Execution
# ------------------------------------------
def execute_daily(event)
  uid = event.user.id
  now = Time.now
  today = Date.today
  is_sub = is_premium?(event.bot, uid)
  bonus_text = ""

  # Fetch current daily info (streak, last claim time)
  daily_info = DB.get_daily_info(uid)
  last_used = daily_info['at'] ? Time.parse(daily_info['at'].to_s) : nil
  current_streak = daily_info['streak'].to_i

  # Cooldown check (24-hour gate)
  unless daily_cooldown_ready?(last_used, now)
    remaining = daily_cooldown_remaining(last_used, now)

    # Show calendar even on cooldown
    claimed_days = DB.get_calendar_claims(uid, today.year, today.month)
    claim_count = claimed_days.size
    calendar_grid = render_calendar(today.year, today.month, claimed_days, today.day)

    # Milestone progress
    m14 = [claim_count, CALENDAR_MILESTONE_14].min
    m28 = [claim_count, CALENDAR_MILESTONE_28].min
    milestone_text = "**Milestones:** #{m14}/#{CALENDAR_MILESTONE_14} (\u2605 Bonus) \u2502 #{m28}/#{CALENDAR_MILESTONE_28} (\u2605\u2605 Mega Bonus)"

    components = [{
      type: 17, accent_color: 0xFF0000,
      components: [
        { type: 10, content: "## #{EMOJI_STRINGS['s_coin']} Daily Login Calendar" },
        { type: 14, spacing: 1 },
        { type: 10, content: "You already grabbed your bag today, chill! Come back in **#{format_time_delta(remaining)}**." },
        { type: 14, spacing: 1 },
        { type: 10, content: calendar_grid },
        { type: 10, content: milestone_text }
      ]
    }]
    return send_cv2(event, components)
  end

  # Streak calculation (reset if > 48h since last claim; subscribers with /autoclaim get weekly insurance)
  new_streak, streak_kind = resolve_daily_streak(event.bot, uid, last_used, now, current_streak)
  streak_msg = case streak_kind
               when :continued
                 "\u{1F525} **Streak:** #{new_streak} days!"
               when :insurance
                 "\u{1F525} **Streak:** #{new_streak} days! *(Subscriber Streak Guard — /autoclaim was on.)*"
               else
                 "*(Streak gone, skill issue. Claim within 48h next time!)*"
               end

  # Base reward + streak bonus
  reward = DAILY_REWARD + (new_streak * DAILY_STREAK_BONUS)

  # Marriage bonus
  marriage = DB.get_marriage(uid)
  if marriage
    reward += MARRIAGE_DAILY_BONUS
    bonus_text += "\n*(#{EMOJI_STRINGS['rainbowheart']} Marriage Bonus: +#{MARRIAGE_DAILY_BONUS} coins!)*"
  end

  # Happy hour indicator
  if happy_hour_active?
    hh_mult = is_sub ? '3x' : '2x'
    bonus_text += "\n*(#{EMOJI_STRINGS['neonsparkle']} HAPPY HOUR: #{hh_mult} Coin Boost Active!)*"
  end

  # Inventory boosts (Neon Sign = x2)
  inv_array = DB.get_inventory(uid)
  inv = inv_array.each_with_object({}) { |item, h| h[item['item_id']] = item['quantity'] }
  if inv['neon sign'] && inv['neon sign'].positive?
    reward *= 2
    bonus_text += "\n*(#{EMOJI_STRINGS['neonsparkle']} Neon Sign Boost: x2 Payout!)*"
  end

  # Subscriber Prisma (rolled here; applied in commit_daily_claim_atomic with coins)
  prisma_reward = 0
  if is_sub
    base_prisma = rand(1..3)
    streak_multiplier = 1 + (new_streak / 7)
    prisma_reward = base_prisma * streak_multiplier
    bonus_text += "\n*(#{EMOJI_STRINGS['prisma']} Subscriber Bonus: +10% Coins & +#{prisma_reward} Prisma!)*"
  end

  # Final payout math (+ premium/happy-hour/crew); calendar milestones predicted from pre-claim count
  final_coin_payout = calculate_coin_payout(event.bot, uid, reward)

  prior_claims_this_month = DB.get_monthly_claim_count(uid, today.year, today.month)
  predict_claim_count = prior_claims_this_month + 1

  milestone_14_pay = 0
  milestone_28_pay = 0
  milestone_msg = ""
  if predict_claim_count == CALENDAR_MILESTONE_14
    raw_m = is_sub ? CALENDAR_MILESTONE_14_PREMIUM : CALENDAR_MILESTONE_14_REWARD
    milestone_14_pay = calculate_coin_payout(event.bot, uid, raw_m)
    milestone_msg += "\n\n\u2B50 **14-Day Milestone!** Bonus: **+#{raw_m}** #{EMOJI_STRINGS['s_coin']}!"
  end
  if predict_claim_count == CALENDAR_MILESTONE_28
    raw_m = is_sub ? CALENDAR_MILESTONE_28_PREMIUM : CALENDAR_MILESTONE_28_REWARD
    milestone_28_pay = calculate_coin_payout(event.bot, uid, raw_m)
    milestone_msg += "\n\n\u{1F31F} **28-Day Milestone!** Bonus: **+#{raw_m}** #{EMOJI_STRINGS['s_coin']}!"
    if is_sub
      milestone_msg += " *(+#{CALENDAR_MILESTONE_28_PRISMA} #{EMOJI_STRINGS['prisma']}!)*"
    end
  end

  prisma_milestone_bonus = predict_claim_count == CALENDAR_MILESTONE_28 && is_sub ? CALENDAR_MILESTONE_28_PRISMA : 0
  coin_grant_total = final_coin_payout + milestone_14_pay + milestone_28_pay
  prisma_grant_total = prisma_reward + prisma_milestone_bonus

  DB.commit_daily_claim_atomic(uid, coin_grant_total, prisma_grant_total, new_streak, now, today)
  grant_crew_xp_for_coin_payout(uid, final_coin_payout, event.bot)
  grant_crew_xp_for_coin_payout(uid, milestone_14_pay, event.bot) if milestone_14_pay.positive?
  grant_crew_xp_for_coin_payout(uid, milestone_28_pay, event.bot) if milestone_28_pay.positive?

  final_reward = final_coin_payout

  # Calendar data for this month
  claimed_days = DB.get_calendar_claims(uid, today.year, today.month)
  claim_count = claimed_days.size
  calendar_grid = render_calendar(today.year, today.month, claimed_days, today.day)

  # Milestone progress bar
  m14 = [claim_count, CALENDAR_MILESTONE_14].min
  m28 = [claim_count, CALENDAR_MILESTONE_28].min
  milestone_progress = "**Milestones:** #{m14}/#{CALENDAR_MILESTONE_14} (\u2605 Bonus) \u2502 #{m28}/#{CALENDAR_MILESTONE_28} (\u2605\u2605 Mega Bonus)"

  # Achievement checks
  check_achievement(event.channel, uid, 'streak_7')   if new_streak == 7
  check_achievement(event.channel, uid, 'streak_30')  if new_streak == 30
  check_achievement(event.channel, uid, 'streak_69')  if new_streak == 69
  check_achievement(event.channel, uid, 'streak_100') if new_streak == 100
  check_achievement(event.channel, uid, 'streak_365') if new_streak == 365
  check_wealth_achievements(event.channel, uid)
  track_challenge(uid, 'daily_claims', 1)

  # Build response
  components = [{
    type: 17, accent_color: 0x00FF00,
    components: [
      { type: 10, content: "## #{EMOJI_STRINGS['checkmark']} Daily Login Calendar" },
      { type: 14, spacing: 1 },
      { type: 10, content: "GG, chat! You snagged **#{final_reward}** #{EMOJI_STRINGS['s_coin']}!\n#{streak_msg}#{bonus_text}" },
      { type: 14, spacing: 1 },
      { type: 10, content: calendar_grid },
      { type: 10, content: "#{milestone_progress}#{milestone_msg}" },
      { type: 14, spacing: 1 },
      { type: 10, content: "Balance: **#{DB.get_coins(uid)}** #{EMOJI_STRINGS['s_coin']}.#{family_remark(uid, 'economy')}" }
    ]
  }]
  send_cv2(event, components)
end

# ------------------------------------------
# TRIGGER: Prefix Command (b!daily)
# ------------------------------------------
$bot.command(:daily, aliases: [:d],
  description: 'Claim your daily coin reward',
  category: 'Economy'
) do |event|
  execute_daily(event)
  nil
end

# ------------------------------------------
# TRIGGER: Slash Command (/daily)
# ------------------------------------------
$bot.application_command(:daily) do |event|
  execute_daily(event)
end
