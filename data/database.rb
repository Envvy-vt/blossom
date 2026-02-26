require 'sqlite3'
require 'time'

class BotDatabase
  def initialize
    @db = SQLite3::Database.new("blossom.db")
    @db.results_as_hash = true
    
    # Create a table for Server Settings (like level-up messages)
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS server_settings (
        server_id INTEGER PRIMARY KEY,
        levelup_enabled INTEGER DEFAULT 1
      );
    SQL

    # Create a table for the Blacklist
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS blacklist (
        user_id INTEGER PRIMARY KEY
      );
    SQL
  end

  # =========================
  # ECONOMY
  # =========================
  def get_coins(uid)
    row = @db.get_first_row("SELECT coins FROM global_users WHERE user_id = ?", [uid])
    row ? row['coins'] : 0
  end

  def add_coins(uid, amount)
    @db.execute("INSERT INTO global_users (user_id, coins) VALUES (?, ?) ON CONFLICT(user_id) DO UPDATE SET coins = coins + ?", [uid, amount, amount])
  end

  def set_coins(uid, amount)
    @db.execute("INSERT INTO global_users (user_id, coins) VALUES (?, ?) ON CONFLICT(user_id) DO UPDATE SET coins = ?", [uid, amount, amount])
  end

  def get_total_users
    row = @db.get_first_row("SELECT COUNT(user_id) AS total FROM global_users")
    row ? row['total'] : 0
  end

  # =========================
  # COOLDOWNS
  # =========================
  def get_cooldown(uid, type)
    row = @db.get_first_row("SELECT #{type}_at FROM global_users WHERE user_id = ?", [uid])
    return nil unless row && row["#{type}_at"]
    Time.parse(row["#{type}_at"])
  end

  def set_cooldown(uid, type, time_obj)
    time_str = time_obj ? time_obj.iso8601 : nil
    @db.execute("INSERT OR IGNORE INTO global_users (user_id, coins) VALUES (?, 0)", [uid])
    @db.execute("UPDATE global_users SET #{type}_at = ? WHERE user_id = ?", [time_str, uid])
  end

  # =========================
  # INVENTORY
  # =========================
  def get_inventory(uid)
    rows = @db.execute("SELECT item_name, count FROM inventory WHERE user_id = ?", [uid])
    inv = {}
    rows.each { |r| inv[r['item_name']] = r['count'] }
    inv
  end

  def add_inventory(uid, item_name, amount = 1)
    @db.execute("INSERT INTO inventory (user_id, item_name, count) VALUES (?, ?, ?) ON CONFLICT(user_id, item_name) DO UPDATE SET count = count + ?", [uid, item_name, amount, amount])
  end

  def remove_inventory(uid, item_name, amount = 1)
    @db.execute("UPDATE inventory SET count = count - ? WHERE user_id = ? AND item_name = ?", [amount, uid, item_name])
  end

  # =========================
  # GACHA COLLECTIONS
  # =========================
  def get_collection(uid)
    rows = @db.execute("SELECT character_name, rarity, count, ascended FROM collections WHERE user_id = ?", [uid])
    col = {}
    rows.each do |r|
      col[r['character_name']] = { 'rarity' => r['rarity'], 'count' => r['count'], 'ascended' => r['ascended'] }
    end
    col
  end

  def add_character(uid, name, rarity, amount = 1)
    @db.execute("INSERT INTO collections (user_id, character_name, rarity, count, ascended) VALUES (?, ?, ?, ?, 0) ON CONFLICT(user_id, character_name) DO UPDATE SET count = count + ?", [uid, name, rarity, amount, amount])
  end
  
  def remove_character(uid, name, amount = 1)
    @db.execute("UPDATE collections SET count = count - ? WHERE user_id = ? AND character_name = ?", [amount, uid, name])
  end

  def ascend_character(uid, name)
    @db.execute("UPDATE collections SET count = count - 5, ascended = ascended + 1 WHERE user_id = ? AND character_name = ?", [uid, name])
  end

  # =========================
  # LEVELING & XP
  # =========================
  def get_user_xp(sid, uid)
    row = @db.get_first_row("SELECT xp, level, last_xp_at FROM server_xp WHERE server_id = ? AND user_id = ?", [sid, uid])
    if row
      { 'xp' => row['xp'], 'level' => row['level'], 'last_xp_at' => (row['last_xp_at'] ? Time.parse(row['last_xp_at']) : nil) }
    else
      { 'xp' => 0, 'level' => 1, 'last_xp_at' => nil }
    end
  end

  def update_user_xp(sid, uid, xp, level, last_xp_at)
    time_str = last_xp_at ? last_xp_at.iso8601 : nil
    @db.execute("INSERT INTO server_xp (server_id, user_id, xp, level, last_xp_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(server_id, user_id) DO UPDATE SET xp = ?, level = ?, last_xp_at = ?", [sid, uid, xp, level, time_str, xp, level, time_str])
  end

  def remove_user_xp(sid, uid)
    @db.execute("DELETE FROM server_xp WHERE server_id = ? AND user_id = ?", [sid, uid])
  end
  
  def get_top_users(sid, limit = 10)
    @db.execute("SELECT user_id, xp, level FROM server_xp WHERE server_id = ? ORDER BY level DESC, xp DESC LIMIT ?", [sid, limit])
  end

  # =========================
  # INTERACTIONS
  # =========================
  def get_interactions(uid)
    row = @db.get_first_row("SELECT * FROM interactions WHERE user_id = ?", [uid])
    if row
      {
        'hug' => { 'sent' => row['hug_sent'], 'received' => row['hug_received'] },
        'slap' => { 'sent' => row['slap_sent'], 'received' => row['slap_received'] }
      }
    else
      { 'hug' => { 'sent' => 0, 'received' => 0 }, 'slap' => { 'sent' => 0, 'received' => 0 } }
    end
  end

  def add_interaction(uid, type, role)
    col = "#{type}_#{role}"
    @db.execute("INSERT INTO interactions (user_id, #{col}) VALUES (?, 1) ON CONFLICT(user_id) DO UPDATE SET #{col} = #{col} + 1", [uid])
  end

  # =========================
  # SERVER SETTINGS
  # =========================
  def levelup_enabled?(sid)
    row = @db.get_first_row("SELECT levelup_enabled FROM server_settings WHERE server_id = ?", [sid])
    row ? row['levelup_enabled'] == 1 : GLOBAL_LEVELUP_ENABLED
  end

  def set_levelup(sid, enabled)
    val = enabled ? 1 : 0
    @db.execute("INSERT INTO server_settings (server_id, levelup_enabled) VALUES (?, ?) ON CONFLICT(server_id) DO UPDATE SET levelup_enabled = ?", [sid, val, val])
  end

  # =========================
  # BLACKLIST
  # =========================
  def toggle_blacklist(uid)
    row = @db.get_first_row("SELECT user_id FROM blacklist WHERE user_id = ?", [uid])
    if row
      @db.execute("DELETE FROM blacklist WHERE user_id = ?", [uid])
      return false
    else
      @db.execute("INSERT INTO blacklist (user_id) VALUES (?)", [uid])
      return true
    end
  end

  def get_blacklist
    @db.execute("SELECT user_id FROM blacklist").map { |row| row['user_id'] }
  end

end # <--- MAKE SURE THIS FINAL 'END' IS HERE!

# Instantiate the global DB object!
DB = BotDatabase.new