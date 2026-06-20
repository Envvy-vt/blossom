# ==========================================
# EVENT: Background Economy Loops
# DESCRIPTION: Houses the threads for hourly lotteries,
# daily reminders, birthdays, happy hours, and auto-claim.
# ==========================================

$bot.ready do |event|

  # $bot.ready runs on initial connect AND every websocket resume — never spawn duplicate daemons.
  next if $blossom_background_threads_started
  $blossom_background_threads_started = true

  # --- GLOBAL HOURLY LOTTERY DRAW ---
  Thread.new do
    loop do
      now = Time.now.to_i
      sleep_time = 3600 - (now % 3600)
      sleep(sleep_time)

      entries = DB.get_lottery_entries
      next if entries.nil? || entries.empty?

      DB.clear_lottery

      begin
        winner_id = entries.sample
        jackpot = 100 + (entries.size * 100)

        DB.add_coins(winner_id, jackpot)
        check_achievement(nil, winner_id, 'lottery_win', silent: true)

        winner_user = event.bot.user(winner_id)
        if winner_user
          begin
            winner_user.pm("#{EMOJI_STRINGS['neonsparkle']} **NO WAY — JACKPOT!** You just pulled **#{jackpot}** #{EMOJI_STRINGS['s_coin']} from the Hourly Lottery! Lucky you~ \u{1F338}")
          rescue
          end
        end
      rescue => e
        puts "[LOTTERY ERROR] #{e.message}"
      end
    end
  end

  # --- DAILY REMINDER PING ---
  Thread.new do
    loop do
      sleep(60)

      begin
        pending_reminders = DB.get_pending_daily_reminders

        pending_reminders.each do |row|
          uid = row['user_id'].to_i
          chan_id = row['reminder_channel'].to_i

          channel = event.bot.channel(chan_id)
          if channel
            begin
              channel.send_message("\u{1F514} <@#{uid}>, your `#{PREFIX}daily` is up! Don't break the streak or I WILL judge you. \u{1F338}")
            rescue
            end
          end
          DB.mark_reminder_sent(uid)
        end
      rescue => e
        puts "[REMINDER ERROR] #{e.message}"
      end
    end
  end

  # --- TOP.GG VOTE REMINDER DM ---
  Thread.new do
    loop do
      sleep(120)
      next unless ENV['TOPGG_WEBHOOK_SECRET']

      begin
        now_iso = Time.now.getutc.iso8601
        rows = DB.topgg_users_ready_for_reminder(now_iso)
        url = TopggWebhook.vote_page_url

        rows.each do |row|
          uid = row['user_id'].to_i
          next if uid.zero?

          u = event.bot.user(uid)
          next unless u

          body = "#{EMOJI_STRINGS['neonsparkle']} **Vote cooldown's up!** You can hit top.gg again and rake in more #{EMOJI_STRINGS['prisma']}.\n**Vote:** #{url}\n\n_Streak stays alive if you keep voting within 28 hours._"
          begin
            u.pm(body)
          rescue StandardError => e
            Discordrb::LOGGER.warn("[VOTE REMINDER] DM failed uid=#{uid}: #{e.class}: #{e.message}")
          end

          DB.mark_topgg_vote_reminder_sent(uid)
        end
      rescue => e
        puts "[VOTE REMINDER ERROR] #{e.message}"
      end
    end
  end

  # --- DAILY BIRTHDAY CHECK ---
  Thread.new do
    last_checked_date = nil
    loop do
      sleep(60)
      today = Time.now.strftime('%Y-%m-%d')
      next if today == last_checked_date

      last_checked_date = today
      begin
        birthday_uids = DB.get_todays_birthdays
        birthday_uids.each do |uid|
          DB.add_coins(uid, BIRTHDAY_REWARD)
          user = event.bot.user(uid)
          next unless user

          if is_premium?(event.bot, uid)
            begin
              user.pm("## \u{1F382} HAPPY BIRTHDAY!! #{EMOJI_STRINGS['neonsparkle']}\n\nIt's YOUR day, #{user.name}!! The Neon Arcade is throwing confetti in your honor! " \
                       "Here's **#{BIRTHDAY_REWARD}** #{EMOJI_STRINGS['s_coin']} as a birthday gift from yours truly~ \u{1F338}\n\n*\u2014 Love, Blossom* #{EMOJI_STRINGS['hearts']}")
            rescue
            end
          end
        end
      rescue => e
        puts "[BIRTHDAY ERROR] #{e.message}"
      end
    end
  end

  # --- HAPPY HOUR (Random Coin Multiplier Events) ---
  Thread.new do
    loop do
      now = Time.now.to_i
      # Align to top of each hour
      sleep_time = 3600 - (now % 3600)
      sleep(sleep_time)

      begin
        # Skip if a happy hour is already active
        next if happy_hour_active?

        # Roll for happy hour (HAPPY_HOUR_CHANCE% per hour)
        if rand(100) < HAPPY_HOUR_CHANCE
          $happy_hour = {
            multiplier: HAPPY_HOUR_MULTIPLIER,
            ends_at: Time.now + HAPPY_HOUR_DURATION
          }
        end
      rescue => e
        puts "[HAPPY HOUR ERROR] #{e.message}"
      end
    end
  end

  # --- AUTO-CLAIM DAILY (Premium Feature) ---
  Thread.new do
    loop do
      sleep(120) # Check every 2 minutes

      begin
        autoclaim_users = DB.get_autoclaim_users

        autoclaim_users.each do |row|
          uid = row['user_id'].to_i

          # Verify still premium — disable if lapsed
          unless is_premium?(event.bot, uid)
            DB.toggle_autoclaim(uid) # Turns off
            next
          end

          now = Time.now
          today = Date.today

          ctx = DB.fetch_autoclaim_context(uid)

          last_used = ctx['at']
          current_streak = ctx['streak'].to_i

          # Verify cooldown is actually up (same helper as /daily and remindme)
          next unless daily_cooldown_ready?(last_used, now)

          new_streak, streak_kind = resolve_daily_streak(event.bot, uid, last_used, now, current_streak)
          streak_note = streak_kind == :insurance ? "\n*(Subscriber Streak Guard saved your streak!)*" : ""

          # Base reward + streak
          reward = DAILY_REWARD + (new_streak * DAILY_STREAK_BONUS)

          # Marriage bonus
          reward += MARRIAGE_DAILY_BONUS if ctx['married']

          # Neon sign boost
          reward *= 2 if ctx['neon_sign_count'].positive?

          # Prisma reward (premium autoclaim users only — loop already gates premium)
          base_prisma = rand(1..3)
          streak_multiplier = 1 + (new_streak / 7)
          prisma_reward = base_prisma * streak_multiplier

          # Same multiplier chain as interactive daily
          final_coin_payout = calculate_coin_payout(event.bot, uid, reward)

          prior_claims_month = DB.get_monthly_claim_count(uid, today.year, today.month)
          predict_claim_count = prior_claims_month + 1

          milestone_14_pay = 0
          milestone_28_pay = 0
          milestone_msg = ""
          mb14 = CALENDAR_MILESTONE_14_PREMIUM
          mb28 = CALENDAR_MILESTONE_28_PREMIUM

          if predict_claim_count == CALENDAR_MILESTONE_14
            milestone_14_pay = calculate_coin_payout(event.bot, uid, mb14)
            milestone_msg += "\n\u2B50 **14-Day Milestone Bonus:** +#{mb14} coins!"
          end
          if predict_claim_count == CALENDAR_MILESTONE_28
            milestone_28_pay = calculate_coin_payout(event.bot, uid, mb28)
            milestone_msg += "\n\u{1F31F} **28-Day Milestone Bonus:** +#{mb28} coins + #{CALENDAR_MILESTONE_28_PRISMA} Prisma!"
          end

          prisma_milestone_extra = predict_claim_count == CALENDAR_MILESTONE_28 ? CALENDAR_MILESTONE_28_PRISMA : 0
          coin_grant_total = final_coin_payout + milestone_14_pay + milestone_28_pay
          prisma_grant_total = prisma_reward + prisma_milestone_extra

          DB.commit_daily_claim_atomic(uid, coin_grant_total, prisma_grant_total, new_streak, now, today)
          grant_crew_xp_for_coin_payout(uid, final_coin_payout, event.bot)
          grant_crew_xp_for_coin_payout(uid, milestone_14_pay, event.bot) if milestone_14_pay.positive?
          grant_crew_xp_for_coin_payout(uid, milestone_28_pay, event.bot) if milestone_28_pay.positive?
          final_reward = final_coin_payout

          # Calendar count for DM (post-commit; matches predict_claim_count when insert succeeded)
          claim_count = DB.get_monthly_claim_count(uid, today.year, today.month)

          # Achievement checks (silent)
          check_achievement(nil, uid, 'streak_7', silent: true)   if new_streak == 7
          check_achievement(nil, uid, 'streak_30', silent: true)  if new_streak == 30
          check_achievement(nil, uid, 'streak_69', silent: true)  if new_streak == 69
          check_achievement(nil, uid, 'streak_100', silent: true) if new_streak == 100
          check_achievement(nil, uid, 'streak_365', silent: true) if new_streak == 365
          track_challenge(uid, 'daily_claims', 1)

          # DM the user
          user = event.bot.user(uid)
          if user
            begin
              user.pm("## #{EMOJI_STRINGS['checkmark']} Auto-Claimed Daily!\n\n" \
                       "I grabbed your daily for you! \u{1F338}\n\n" \
                       "**Reward:** #{final_reward} #{EMOJI_STRINGS['s_coin']} + #{prisma_reward} #{EMOJI_STRINGS['prisma']}\n" \
                       "\u{1F525} **Streak:** #{new_streak} days#{streak_note}\n" \
                       "**Calendar:** #{claim_count}/#{Date.new(today.year, today.month, -1).day} this month#{milestone_msg}\n\n" \
                       "Balance: **#{DB.get_coins(uid)}** #{EMOJI_STRINGS['s_coin']}")
            rescue
              # DMs closed
            end
          end
        end
      rescue => e
        puts "[AUTOCLAIM ERROR] #{e.message}"
      end
    end
  end

  # --- DAILY TIP / FUN FACT ---
  Thread.new do
    last_tip_date = nil
    loop do
      sleep(300) # Check every 5 minutes
      today = Time.now.strftime('%Y-%m-%d')
      next if today == last_tip_date

      # Post tips at ~10 AM (hour 10)
      next unless Time.now.hour >= 10

      last_tip_date = today
      begin
        tip = BLOSSOM_TIPS.sample
        tip_channels = DB.get_all_tip_channels

        tip_channels.each do |row|
          chan_id = row['tip_channel'].to_i
          next if chan_id == 0

          channel = event.bot.channel(chan_id)
          next unless channel

          begin
            channel.send_message("## \u{1F4A1} Blossom's Tip of the Day\n\n#{tip}\n\n*\u2014 Your friendly Neon Arcade manager \u{1F338}*")
          rescue
          end
        end
      rescue => e
        puts "[DAILY TIP ERROR] #{e.message}"
      end
    end
  end

  # --- WEEKLY CHALLENGE GENERATION ---
  Thread.new do
    loop do
      sleep(600) # Check every 10 minutes

      begin
        CACHE.sweep_expired!
        week_start = current_week_start
        existing = DB.get_weekly_challenges(week_start)
        unless existing
          challenges = generate_weekly_challenges
          DB.set_weekly_challenges(week_start, challenges)
          puts "[CHALLENGES] Generated weekly challenges for week of #{week_start}"
        end
      rescue => e
        puts "[CHALLENGE GEN ERROR] #{e.message}"
      end
    end
  end

  # --- HOURLY HEIST EVENTS ---
  Thread.new do
    loop do
      now = Time.now.to_i
      # Align to top of each hour (offset by 30 min so it doesn't collide with lottery)
      sleep_time = 3600 - (now % 3600) + 1800
      sleep_time -= 3600 if sleep_time > 3600
      sleep_time = [sleep_time, 60].max
      sleep(sleep_time)

      begin
        heist_configs = DB.get_all_heist_channels

        heist_configs.each do |row|
          begin
            sid = row['server_id'].to_i
            chan_id = row['heist_channel'].to_i

            if chan_id == 0
              next
            end

            if ACTIVE_HEISTS[sid]
              next
            end

            vault_amount = HEIST_BASE_VAULT + (HEIST_PER_PLAYER_VAULT * 5) # Preview with 5 players

            # Send heist announcement with join button via raw API (no channel cache needed)
            body = {
              content: '', flags: CV2_FLAG,
              components: [{
                type: 17, accent_color: 0xFFD700,
                components: [
                  { type: 10, content: "## \u{1F3E6} HEIST ALERT! #{EMOJI_STRINGS['neonsparkle']}" },
                  { type: 14, spacing: 1 },
                  { type: 10, content: "A vault in the Neon Arcade is vulnerable! Assemble a crew to crack it open!\n\n\u{1F4B0} **Estimated Vault:** #{vault_amount}+ #{EMOJI_STRINGS['s_coin']} (scales with crew size)\n\u{1F465} **Min Crew:** #{HEIST_MIN_PLAYERS} players\n\u23F0 **Join Window:** 5 minutes\n\u{1F451} Premium hackers add +#{HEIST_PREMIUM_BONUS}% success rate!\n\nClick below to join the crew!" },
                  { type: 14, spacing: 1 },
                  { type: 1, components: [
                    { type: 2, style: 3, label: "\u{1F3AD} Join the Heist!", custom_id: "heist_join_#{sid}" }
                  ]}
                ]
              }],
              allowed_mentions: { parse: [] }
            }.to_json

            response = Discordrb::API.request(
              :channels_cid_messages_mid, chan_id, :post,
              "#{Discordrb::API.api_base}/channels/#{chan_id}/messages",
              body, Authorization: $bot.token, content_type: :json
            )
            raw_body = response.respond_to?(:body) ? response.body : response.to_s
            msg_data = JSON.parse(raw_body)

            ACTIVE_HEISTS[sid] = {
              message_id: msg_data['id'].to_i,
              participants: [],
              started_at: Time.now,
              channel_id: chan_id
            }

            # Schedule heist execution after join window
            Thread.new do
              sleep(HEIST_JOIN_WINDOW)
              execute_heist_result($bot, sid)
            end
          rescue Discordrb::Errors::UnknownChannel
            begin
              DB.set_heist_channel(sid, nil)
            rescue StandardError
              # ignore DB clear failure
            end
          rescue Discordrb::Errors::NoPermission
            # still configured; admin must fix channel perms
          rescue StandardError
            # ignore per-server heist errors
          end
        end
      rescue StandardError
        # ignore outer heist loop errors
      end
    end
  end

end

# --- HEIST RESULT EXECUTION (called after join window) ---
def execute_heist_result(bot, sid)
  heist = ACTIVE_HEISTS.delete(sid)
  unless heist
    return
  end

  chan_id = heist[:channel_id]
  players = heist[:participants]

  if players.size < HEIST_MIN_PLAYERS
    # Not enough players — send via raw API
    begin
      body = { content: "## \u{1F3E6} Heist Cancelled #{EMOJI_STRINGS['nervous']}\n\n" \
        "Only **#{players.size}** showed up... needed **#{HEIST_MIN_PLAYERS}**. The vault lives another day. Skill issue, chat." }.to_json
      Discordrb::API.request(
        :channels_cid_messages_mid, chan_id, :post,
        "#{Discordrb::API.api_base}/channels/#{chan_id}/messages",
        body, Authorization: bot.token, content_type: :json
      )
    rescue StandardError
      # ignore cancel message failure
    end
    return
  end

  # Calculate success chance
  base_chance = HEIST_BASE_CHANCE + (players.size * HEIST_PER_PLAYER)
  premium_count = players.count { |uid| is_premium?(bot, uid) }
  bonus_chance = premium_count * HEIST_PREMIUM_BONUS
  total_chance = [base_chance + bonus_chance, HEIST_MAX_CHANCE].min

  success = rand(100) < total_chance
  vault = HEIST_BASE_VAULT + (players.size * HEIST_PER_PLAYER_VAULT)
  player_mentions = players.map { |uid| "<@#{uid}>" }.join(', ')

  if success
    split = (vault.to_f / players.size).round
    players.each { |uid| DB.add_coins(uid, split) }

    msg = "## \u{1F4B0} HEIST SUCCESSFUL! #{EMOJI_STRINGS['rich']}\n\n" \
      "The crew cracked the vault! **#{vault}** #{EMOJI_STRINGS['s_coin']} split among **#{players.size}** players!\n\n" \
      "**Each player earned:** #{split} #{EMOJI_STRINGS['s_coin']}\n" \
      "**Success rate was:** #{total_chance}%#{premium_count > 0 ? " (#{premium_count} hacker#{premium_count > 1 ? 's' : ''} helped!)" : ""}\n\n" \
      "\u{1F465} Crew: #{player_mentions}\n\nGG, chat! \u{1F338}"
  else
    msg = "## \u{1F6A8} HEIST FAILED! #{EMOJI_STRINGS['error']}\n\n" \
      "The alarm went off! The crew scattered with NOTHING!\n\n" \
      "**Success rate was:** #{total_chance}% \u2014 bad luck!\n\n" \
      "\u{1F465} Crew: #{player_mentions}\n\nBetter luck next hour... \u{1F338}"
  end

  begin
    body = { content: msg }.to_json
    Discordrb::API.request(
      :channels_cid_messages_mid, chan_id, :post,
      "#{Discordrb::API.api_base}/channels/#{chan_id}/messages",
      body, Authorization: bot.token, content_type: :json
    )
  rescue StandardError
    # ignore result message failure
  end
end
