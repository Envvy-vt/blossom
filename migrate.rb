require 'json'
require 'sqlite3'

puts "Starting database migration..."

# 1. Open the JSON file
if !File.exist?('bot_data.json')
  puts "ERROR: bot_data.json not found!"
  exit
end

raw_data = JSON.parse(File.read('bot_data.json'))

# 2. Create and connect to the new SQLite database
db = SQLite3::Database.new("blossom.db")
db.results_as_hash = true

# 3. Build the Tables
puts "Building database tables..."
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS global_users (
    user_id INTEGER PRIMARY KEY,
    coins INTEGER DEFAULT 0,
    daily_at TEXT,
    work_at TEXT,
    stream_at TEXT,
    post_at TEXT,
    collab_at TEXT,
    summon_at TEXT
  );
SQL

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS server_xp (
    server_id INTEGER,
    user_id INTEGER,
    xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    last_xp_at TEXT,
    PRIMARY KEY (server_id, user_id)
  );
SQL

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS collections (
    user_id INTEGER,
    character_name TEXT,
    rarity TEXT,
    count INTEGER DEFAULT 0,
    ascended INTEGER DEFAULT 0,
    PRIMARY KEY (user_id, character_name)
  );
SQL

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS inventory (
    user_id INTEGER,
    item_name TEXT,
    count INTEGER DEFAULT 0,
    PRIMARY KEY (user_id, item_name)
  );
SQL

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS interactions (
    user_id INTEGER PRIMARY KEY,
    hug_sent INTEGER DEFAULT 0,
    hug_received INTEGER DEFAULT 0,
    slap_sent INTEGER DEFAULT 0,
    slap_received INTEGER DEFAULT 0
  );
SQL

# 4. Import the Data!
puts "Importing Economy & Cooldowns..."
# Ensure all users with coins have a row
(raw_data['coins'] || {}).each do |uid, amount|
  db.execute("INSERT OR IGNORE INTO global_users (user_id, coins) VALUES (?, ?)", [uid.to_i, amount.to_i])
end

# Add cooldowns to those rows
(raw_data['economy_cooldowns'] || {}).each do |uid, cds|
  db.execute(
    "UPDATE global_users SET daily_at = ?, work_at = ?, stream_at = ?, post_at = ?, collab_at = ? WHERE user_id = ?", 
    [cds['daily_at'], cds['work_at'], cds['stream_at'], cds['post_at'], cds['collab_at'], uid.to_i]
  )
end

puts "Importing Server XP..."
(raw_data['users'] || {}).each do |server_id, users_hash|
  next if server_id == 'xp' # Skip corrupted root keys just in case
  users_hash.each do |uid, data|
    db.execute(
      "INSERT OR REPLACE INTO server_xp (server_id, user_id, xp, level, last_xp_at) VALUES (?, ?, ?, ?, ?)",
      [server_id.to_i, uid.to_i, data['xp'].to_i, data['level'].to_i, data['last_xp_at']]
    )
  end
end

puts "Importing Gacha Collections..."
(raw_data['collections'] || {}).each do |uid, chars|
  chars.each do |char_name, data|
    db.execute(
      "INSERT OR REPLACE INTO collections (user_id, character_name, rarity, count, ascended) VALUES (?, ?, ?, ?, ?)",
      [uid.to_i, char_name, data['rarity'], data['count'].to_i, data['ascended'].to_i]
    )
  end
end

puts "Importing Tech Inventory..."
(raw_data['inventory'] || {}).each do |uid, items|
  items.each do |item_name, count|
    db.execute(
      "INSERT OR REPLACE INTO inventory (user_id, item_name, count) VALUES (?, ?, ?)",
      [uid.to_i, item_name, count.to_i]
    )
  end
end

puts "Importing Interactions..."
(raw_data['interactions'] || {}).each do |uid, data|
  db.execute(
    "INSERT OR REPLACE INTO interactions (user_id, hug_sent, hug_received, slap_sent, slap_received) VALUES (?, ?, ?, ?, ?)",
    [
      uid.to_i, 
      data.dig('hug', 'sent').to_i, data.dig('hug', 'received').to_i,
      data.dig('slap', 'sent').to_i, data.dig('slap', 'received').to_i
    ]
  )
end

puts "✅ Migration Complete! Your database 'blossom.db' has been created."