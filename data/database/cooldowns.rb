# ==========================================
# MODULE: Database Cooldowns
# DESCRIPTION: Handles daily claims, streaks, and reminders.
# ==========================================

module DatabaseCooldowns
  # Force all methods below this to be accessible by the bot
  public 

  # --- DAILY INFO & CLAIM ---
  def get_daily_info(uid)
    row = @db.exec_params("SELECT daily_at, daily_streak, reminder_channel, reminder_sent FROM global_users WHERE user_id = $1", [uid]).first
    if row
      {
        'at' => row['daily_at'] ? Time.parse(row['daily_at']) : nil,
        'streak' => row['daily_streak'].to_i,
        'channel' => row['reminder_channel'] ? row['reminder_channel'].to_i : nil,
        'sent' => row['reminder_sent'].to_i == 1
      }
    else
      { 'at' => nil, 'streak' => 0, 'channel' => nil, 'sent' => false }
    end
  end

  def update_daily_claim(uid, streak, time_obj)
    time_str = time_obj.iso8601
    @db.exec_params(
      "INSERT INTO global_users (user_id, coins, daily_streak, reminder_sent, daily_at) 
       VALUES ($1, 0, $2, 0, $3) 
       ON CONFLICT (user_id) DO UPDATE 
       SET daily_streak = $2, reminder_sent = 0, daily_at = $3", 
      [uid, streak, time_str]
    )
  end

  # --- GENERAL COOLDOWNS ---
  VALID_COOLDOWN_TYPES = %w[daily work stream post collab summon spin fish].freeze

  def get_cooldown(uid, type)
    raise ArgumentError, "Invalid cooldown type: #{type}" unless VALID_COOLDOWN_TYPES.include?(type.to_s)
    column = "#{type}_at"
    row = @db.exec_params("SELECT #{column} FROM global_users WHERE user_id = $1", [uid]).first
    return nil unless row && row[column]
    Time.parse(row[column])
  end

  def set_cooldown(uid, type, time_obj)
    raise ArgumentError, "Invalid cooldown type: #{type}" unless VALID_COOLDOWN_TYPES.include?(type.to_s)
    column = "#{type}_at"
    time_str = time_obj ? time_obj.iso8601 : nil
    @db.exec_params("INSERT INTO global_users (user_id, coins) VALUES ($1, 0) ON CONFLICT DO NOTHING", [uid])
    @db.exec_params("UPDATE global_users SET #{column} = $2 WHERE user_id = $1", [uid, time_str])
  end

  # --- DAILY REMINDERS ---
  def get_pending_daily_reminders
    rows = @db.exec(
      "SELECT user_id, reminder_channel, daily_at FROM global_users
       WHERE reminder_channel IS NOT NULL
       AND reminder_sent = 0"
    ).to_a

    now = Time.now
    rows.select { |row| daily_cooldown_ready?(row['daily_at'], now) }
        .map { |row| { 'user_id' => row['user_id'], 'reminder_channel' => row['reminder_channel'] } }
  end

  def mark_reminder_sent(uid)
    @db.exec_params("UPDATE global_users SET reminder_sent = 1 WHERE user_id = $1", [uid])
  end

  def toggle_daily_reminder(uid, channel_id)
    row = @db.exec_params("SELECT reminder_channel FROM global_users WHERE user_id = $1", [uid]).first

    if row && row['reminder_channel'] && channel_id.nil?
      @db.exec_params("UPDATE global_users SET reminder_channel = NULL, reminder_sent = 0 WHERE user_id = $1", [uid])
      return false
    else
      @db.exec_params("INSERT INTO global_users (user_id, coins) VALUES ($1, 0) ON CONFLICT DO NOTHING", [uid])
      @db.exec_params("UPDATE global_users SET reminder_channel = $2, reminder_sent = 0 WHERE user_id = $1", [uid, channel_id])
      return true
    end
  end

  # --- DAILY CALENDAR ---
  def add_calendar_claim(uid, date)
    date_str = date.is_a?(String) ? date : date.strftime('%Y-%m-%d')
    @db.exec_params(
      "INSERT INTO daily_calendar (user_id, claim_date) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      [uid, date_str]
    )
  end

  def get_calendar_claims(uid, year, month)
    rows = @db.exec_params(
      "SELECT EXTRACT(DAY FROM claim_date)::int AS day FROM daily_calendar WHERE user_id = $1 AND EXTRACT(YEAR FROM claim_date) = $2 AND EXTRACT(MONTH FROM claim_date) = $3",
      [uid, year, month]
    )
    rows.map { |r| r['day'].to_i }
  end

  def get_monthly_claim_count(uid, year, month)
    row = @db.exec_params(
      "SELECT COUNT(*) AS cnt FROM daily_calendar WHERE user_id = $1 AND EXTRACT(YEAR FROM claim_date) = $2 AND EXTRACT(MONTH FROM claim_date) = $3",
      [uid, year, month]
    ).first
    row ? row['cnt'].to_i : 0
  end

  # --- AUTO-CLAIM DAILY ---
  def get_autoclaim(uid)
    row = @db.exec_params("SELECT autoclaim_daily FROM global_users WHERE user_id = $1", [uid]).first
    row ? row['autoclaim_daily'].to_i == 1 : false
  end

  def toggle_autoclaim(uid)
    @db.exec_params("INSERT INTO global_users (user_id, autoclaim_daily) VALUES ($1, 1) ON CONFLICT (user_id) DO UPDATE SET autoclaim_daily = CASE WHEN global_users.autoclaim_daily = 1 THEN 0 ELSE 1 END", [uid])
    get_autoclaim(uid)
  end

  def get_autoclaim_users
    rows = @db.exec(
      "SELECT user_id, daily_at FROM global_users WHERE autoclaim_daily = 1"
    ).to_a

    now = Time.now
    rows.select { |row| daily_cooldown_ready?(row['daily_at'], now) }
        .map { |row| { 'user_id' => row['user_id'] } }
  end

  # One round-trip: daily row + marriage + neon sign inventory (autoclaim path).
  def fetch_autoclaim_context(uid)
    row = @db.exec_params(
      <<~SQL,
        SELECT gu.daily_at,
               COALESCE(gu.daily_streak, 0) AS daily_streak,
               EXISTS(SELECT 1 FROM marriages WHERE user_a = $1 OR user_b = $1) AS married,
               COALESCE((SELECT SUM(count) FROM inventory WHERE user_id = $1 AND item_name = 'neon sign'), 0) AS neon_sign_count
        FROM (SELECT $1::bigint AS uid) x
        LEFT JOIN global_users gu ON gu.user_id = x.uid
      SQL
      [uid]
    ).first

    {
      'at' => row['daily_at'] ? Time.parse(row['daily_at'].to_s) : nil,
      'streak' => row['daily_streak'].to_i,
      'married' => row['married'] == true || row['married'].to_s == 't',
      'neon_sign_count' => row['neon_sign_count'].to_i
    }
  end

  # Atomically grants daily coins (+EXCLUDED additive upsert), streak/timer shift,
  # calendar row, optional Prisma subscriber bonus — replaces split award_coins /
  # update_daily / add_calendar / add_prisma ordering gaps.
  def commit_daily_claim_atomic(uid, coin_grant, prisma_grant, new_streak, time_obj, claim_date_str)
    cg = coin_grant.to_i
    pg = prisma_grant.to_i
    streak = new_streak.to_i
    time_str = time_obj.iso8601
    date_str = claim_date_str.is_a?(String) ? claim_date_str : claim_date_str.strftime('%Y-%m-%d')

    balance = nil
    @db.transaction do |conn|
      row = conn.exec_params(
        <<~SQL,
          INSERT INTO global_users (user_id, coins, daily_streak, reminder_sent, daily_at)
          VALUES ($1, $2, $3, 0, $4)
          ON CONFLICT (user_id) DO UPDATE SET
            coins = global_users.coins + EXCLUDED.coins,
            daily_streak = EXCLUDED.daily_streak,
            reminder_sent = 0,
            daily_at = EXCLUDED.daily_at
          RETURNING coins
        SQL
        [uid, cg, streak, time_str]
      ).first
      balance = row['coins'].to_i

      conn.exec_params(
        'INSERT INTO daily_calendar (user_id, claim_date) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [uid, date_str]
      )

      unless pg <= 0
        conn.exec_params(
          'INSERT INTO user_prisma (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = user_prisma.balance + $3',
          [uid, pg, pg]
        )
      end
    end

    balance
  end
end