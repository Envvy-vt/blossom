require 'discordrb'
require 'json'
require 'time'
require 'dotenv/load'

# =========================
# 1. LOAD CONFIG DATA
# =========================
require_relative 'data/config'
require_relative 'data/pools'

# =========================
# 2. DATA STRUCTURES
# =========================

COMMAND_CATEGORIES = {
  'Economy'   => [:balance, :daily, :work, :stream, :post, :collab, :cooldowns],
  'Gacha'     => [:summon, :collection, :banner, :shop, :buy, :view, :ascend, :trade],
  'Arcade'    => [:coinflip, :slots, :roulette, :scratch, :dice, :cups],
  'Fun'       => [:kettle, :leaderboard, :hug, :slap, :interactions, :bomb],
  'Utility'   => [:ping, :help, :about, :level],
  'Developer' => [:addcoins, :setcoins, :setlevel, :addxp, :enablebombs, :disablebombs, :levelup]
}.freeze

def get_cmd_category(cmd_name)
  COMMAND_CATEGORIES.each do |category, commands|
    return category if commands.include?(cmd_name)
  end
  'Uncategorized'
end

users = Hash.new do |hash, server_id|
  hash[server_id] = Hash.new { |h, user_id| h[user_id] = { 'xp' => 0, 'level' => 1, 'last_xp_at' => nil } }
end

coins              = Hash.new(0)
collections        = Hash.new { |h, k| h[k] = {} }
inventory          = Hash.new { |h, k| h[k] = {} } 
interactions       = Hash.new do |h, k|
  h[k] = { 'hug' => { 'sent' => 0, 'received' => 0 }, 'slap' => { 'sent' => 0, 'received' => 0 } }
end
economy_cooldowns  = Hash.new { |h, k| h[k] = { 'daily_at' => nil, 'work_at' => nil } }
summon_cooldowns   = {}
levelup_settings   = {} 
server_bomb_configs = {}
ACTIVE_BOMBS       = {} 
ACTIVE_COLLABS     = {}
ACTIVE_TRADES      = {}

# =========================
# 3. PERSISTENCE HELPERS
# =========================

def load_data(file, users, coins, collections, interactions, economy_cooldowns, levelup_settings, server_bomb_configs, inventory)
  return unless File.exist?(file)

  raw = JSON.parse(File.read(file))

  (raw['users'] || {}).each do |server_id_str, server_data|
    next if server_data.key?('xp') 
    
    sid = server_id_str.to_i
    server_data.each do |id_str, data|
      uid = id_str.to_i
      users[sid][uid] = {
        'xp'         => data['xp'] || 0,
        'level'      => data['level'] || 1,
        'last_xp_at' => data['last_xp_at'] ? Time.parse(data['last_xp_at']) : nil
      }
    end
  end

  (raw['coins'] || {}).each do |id_str, amount|
    coins[id_str.to_i] = amount.to_i
  end

  (raw['collections'] || {}).each do |id_str, data|
    uid = id_str.to_i
    if data.is_a?(Array)
      data.each do |c|
        name = c['name']
        rarity = c['rarity']
        collections[uid][name] ||= { 'rarity' => rarity, 'count' => 0 }
        collections[uid][name]['count'] += 1
      end
    else
      collections[uid] = data
    end
  end

  (raw['inventory'] || {}).each do |id_str, data|
    inventory[id_str.to_i] = data
  end

  (raw['interactions'] || {}).each do |id_str, data|
    id = id_str.to_i
    if data.key?('sent') && data.key?('received')
      interactions[id] = {
        'hug'  => { 'sent' => data['sent'] || 0, 'received' => data['received'] || 0 },
        'slap' => { 'sent' => 0, 'received' => 0 }
      }
    else
      interactions[id] = {
        'hug' => { 'sent' => data.dig('hug', 'sent') || 0, 'received' => data.dig('hug', 'received') || 0 },
        'slap' => { 'sent' => data.dig('slap', 'sent') || 0, 'received' => data.dig('slap', 'received') || 0 }
      }
    end
  end

  (raw['economy_cooldowns'] || {}).each do |id_str, data|
    economy_cooldowns[id_str.to_i] = {
      'daily_at'  => data['daily_at'] ? Time.parse(data['daily_at']) : nil,
      'work_at'   => data['work_at'] ? Time.parse(data['work_at']) : nil,
      'stream_at' => data['stream_at'] ? Time.parse(data['stream_at']) : nil,
      'post_at'   => data['post_at'] ? Time.parse(data['post_at']) : nil,
      'collab_at' => data['collab_at'] ? Time.parse(data['collab_at']) : nil
    }
  end

  (raw['levelup_settings'] || {}).each do |server_id_str, enabled|
    levelup_settings[server_id_str.to_i] = !!enabled
  end

  (raw['server_bomb_configs'] || {}).each do |sid_str, config|
    server_bomb_configs[sid_str.to_i] = config
  end

rescue StandardError => e
  puts "Failed to load data: #{e.message}"
end

def save_data(file, users, coins, collections, interactions, economy_cooldowns, levelup_settings, server_bomb_configs, inventory)
  payload = {
    users: users.transform_values do |server_data|
      server_data.transform_values do |u|
        { xp: u['xp'], level: u['level'], last_xp_at: u['last_xp_at']&.iso8601 }
      end
    end,
    coins: coins,
    collections: collections,
    inventory: inventory,
    interactions: interactions,
    economy_cooldowns: economy_cooldowns.transform_values do |c|
      {
        daily_at:  c['daily_at']&.iso8601,
        work_at:   c['work_at']&.iso8601,
        stream_at: c['stream_at']&.iso8601,
        post_at:   c['post_at']&.iso8601,
        collab_at: c['collab_at']&.iso8601
      }
    end,
    levelup_settings: levelup_settings,
    server_bomb_configs: server_bomb_configs
  }

  File.write(file, JSON.pretty_generate(payload))
rescue StandardError => e
  puts "Failed to save data: #{e.message}"
end

# =========================
# 4. BOT HELPERS
# =========================

def roll_rarity
  roll = rand(100)
  total = 0
  RARITY_TABLE.each do |(rarity, weight)|
    total += weight
    return rarity if roll < total
  end
  :common
end

def format_time_delta(seconds)
  seconds = seconds.to_i
  return '0s' if seconds <= 0

  parts = []
  days = seconds / 86_400; seconds %= 86_400
  hours = seconds / 3600;  seconds %= 3600
  minutes = seconds / 60;  seconds %= 60

  parts << "#{days}d" if days.positive?
  parts << "#{hours}h" if hours.positive?
  parts << "#{minutes}m" if minutes.positive?
  parts << "#{seconds}s" if seconds.positive?
  parts.join(' ')
end

def levelup_enabled_for?(server_id, levelup_settings)
  return GLOBAL_LEVELUP_ENABLED if server_id.nil?
  levelup_settings.fetch(server_id, GLOBAL_LEVELUP_ENABLED)
end

def send_embed(event, title:, description:, fields: nil, image: nil)
  embed = Discordrb::Webhooks::Embed.new
  embed.title = title
  embed.description = description
  embed.color = NEON_COLORS.sample
  
  if fields
    fields.each do |f|
      embed.add_field(name: f[:name], value: f[:value], inline: f.fetch(:inline, false))
    end
  end
  
  embed.image = Discordrb::Webhooks::EmbedImage.new(url: image) if image
  embed.timestamp = Time.now
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Requested by #{event.user.display_name}", icon_url: event.user.avatar_url)

  event.channel.send_message(nil, false, embed, nil, nil, event.message)
end

def interaction_embed(event, action_name, gifs, interactions)
  target = event.message.mentions.first
  unless target
    return send_embed(event, title: "#{EMOJIS['error']} Interaction Error", description: "Mention someone to #{action_name}!")
  end

  actor_id  = event.user.id
  target_id = target.id

  interactions[actor_id][action_name]['sent']     += 1
  interactions[target_id][action_name]['received'] += 1

  actor_stats  = interactions[actor_id][action_name]
  target_stats = interactions[target_id][action_name]

  send_embed(
    event,
    title: "#{EMOJIS['heart']} #{action_name.capitalize}",
    description: "#{event.user.mention} #{action_name}s #{target.mention}!",
    fields: [
      { name: "#{event.user.name}'s #{action_name}s", value: "Sent: **#{actor_stats['sent']}**\nReceived: **#{actor_stats['received']}**", inline: true },
      { name: "#{target.name}'s #{action_name}s", value: "Sent: **#{target_stats['sent']}**\nReceived: **#{target_stats['received']}**", inline: true }
    ],
    image: gifs.sample
  )
end

def get_current_banner
  week_number = Time.now.to_i / 604_800 
  available_pools = CHARACTER_POOLS.keys
  active_key = available_pools[week_number % available_pools.size]
  CHARACTER_POOLS[active_key]
end

def generate_collection_page(user_obj, collections, rarity_page)
  uid = user_obj.id
  chars = collections[uid] || {}
  
  # Checks if they have normal copies OR ascended copies
  page_chars = chars.select { |_, data| data['rarity'] == rarity_page && (data['count'] > 0 || data['ascended'].to_i > 0) }
  
  total_collected = page_chars.size
  total_available = TOTAL_UNIQUE_CHARS[rarity_page]
  
  emoji = case rarity_page
          when 'goddess'   then '💎'
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end
          
  desc = "You have collected **#{total_collected} / #{total_available}** unique #{rarity_page.capitalize} characters.\n\n"
  
  if page_chars.empty?
    desc += "*You haven't pulled any characters of this rarity yet!*"
  else
    # NEW: Formats the list to show standard copies and shiny ascended copies!
    list = page_chars.map do |name, data|
      str = "`#{name}` (x#{data['count']})"
      str += " ✨*(Ascended x#{data['ascended']})*" if data['ascended'].to_i > 0
      str
    end
    desc += list.join(', ')
  end
  
  embed = Discordrb::Webhooks::Embed.new
  embed.title = "#{emoji} #{user_obj.display_name}'s Collection - #{rarity_page.capitalize}"
  embed.description = desc
  embed.color = NEON_COLORS.sample
  embed
end

def collection_view(target_uid, current_page, collections)
  user_chars = collections[target_uid] || {}
  owns_goddess = user_chars.values.any? { |data| data['rarity'] == 'goddess' && data['count'] > 0 }

  Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "coll_common_#{target_uid}", label: 'Common', style: current_page == 'common' ? :success : :secondary, emoji: '⭐', disabled: current_page == 'common')
      r.button(custom_id: "coll_rare_#{target_uid}", label: 'Rare', style: current_page == 'rare' ? :success : :secondary, emoji: '✨', disabled: current_page == 'rare')
      r.button(custom_id: "coll_legendary_#{target_uid}", label: 'Legendary', style: current_page == 'legendary' ? :success : :secondary, emoji: '🌟', disabled: current_page == 'legendary')
      if owns_goddess
        r.button(custom_id: "coll_goddess_#{target_uid}", label: 'Goddess', style: current_page == 'goddess' ? :success : :secondary, emoji: '💎', disabled: current_page == 'goddess')
      end
    end
  end
end

def generate_help_page(bot, user_obj, page_number)
  grouped_commands = bot.commands.values.group_by { |cmd| get_cmd_category(cmd.name) }
  category_order = COMMAND_CATEGORIES.keys + ['Uncategorized']
  
  pages = []
  category_order.each do |category|
    next unless grouped_commands[category] 
    cmds = grouped_commands[category].sort_by(&:name)
    cmds.each_slice(10).with_index do |slice, index|
      pages << { category: category, commands: slice, part: index + 1, total_parts: (cmds.size / 10.0).ceil }
    end
  end

  total_pages = pages.size
  total_pages = 1 if total_pages < 1
  page_number = 1 if page_number < 1
  page_number = total_pages if page_number > total_pages

  active_page = pages[page_number - 1]
  command_lines = active_page[:commands].map { |cmd| "> `#{PREFIX}#{cmd.name}` - #{cmd.attributes[:description] || 'No description provided.'}" }

  cat_name = active_page[:category]
  cat_name += " (Pt. #{active_page[:part]})" if active_page[:total_parts] > 1

  embed = Discordrb::Webhooks::Embed.new
  embed.title = "#{EMOJIS['info']} Bot Help Menu - #{cat_name}"
  embed.description = "Use `#{PREFIX}` before any command!\n\n**Menu Page #{page_number} of #{total_pages}**"
  embed.color = NEON_COLORS.sample
  embed.add_field(name: '📜 Commands', value: command_lines.join("\n"), inline: false)
  embed.timestamp = Time.now
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Requested by #{user_obj.display_name}")

  [embed, total_pages, page_number]
end

def help_view(target_uid, current_page, total_pages)
  Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "helpnav_#{target_uid}_#{current_page - 1}", label: 'Previous', style: :primary, emoji: '◀️', disabled: current_page <= 1)
      r.button(custom_id: "helpnav_#{target_uid}_#{current_page + 1}", label: 'Next', style: :primary, emoji: '▶️', disabled: current_page >= total_pages)
    end
  end
end

def find_character_in_pools(search_name)
  CHARACTER_POOLS.values.each do |pool|
    pool[:characters].each do |rarity, char_list|
      found = char_list.find { |c| c[:name].downcase == search_name.downcase }
      return { char: found, rarity: rarity.to_s } if found
    end
  end
  nil
end

def build_shop_home(user_id)
  embed = Discordrb::Webhooks::Embed.new
  embed.title = "#{EMOJIS['rich']} The VTuber Black Market"
  embed.description = "Tired of bad gacha luck? Save up your stream revenue and buy exactly who you want!\n\n" \
                      "⭐ **Common:** #{SHOP_PRICES['common']} #{EMOJIS['s_coin']} *(Sells for #{SELL_PRICES['common']})*\n" \
                      "✨ **Rare:** #{SHOP_PRICES['rare']} #{EMOJIS['s_coin']} *(Sells for #{SELL_PRICES['rare']})*\n" \
                      "🌟 **Legendary:** #{SHOP_PRICES['legendary']} #{EMOJIS['s_coin']} *(Sells for #{SELL_PRICES['legendary']})*\n\n" \
                      "Use `#{PREFIX}buy <Name>` to purchase characters or tech upgrades!"
  embed.color = NEON_COLORS.sample
  embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://media.discordapp.net/attachments/1475890017443516476/1476244926638592050/d60459-53-0076f9af74811878db01-0.jpg?ex=69a06bb9&is=699f1a39&hm=a5769b33a3b669e67f439bad467b90c1a9681f8d3a1e975bb048b79d521ec929&=&format=webp')

  view = Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "shop_catalog_#{user_id}_1", label: 'View Catalog', style: :primary, emoji: '📖')
      r.button(custom_id: "shop_blackmarket_#{user_id}", label: 'Tech Upgrades', style: :success, emoji: '🛒')
      r.button(custom_id: "shop_sell_#{user_id}", label: 'Sell Duplicates', style: :danger, emoji: '♻️')
    end
  end
  [embed, view]
end

def build_shop_catalog(user_id, page)
  rarities = ['common', 'rare', 'legendary']
  target_rarity = rarities[page - 1]

  chars = []
  CHARACTER_POOLS.values.each { |pool| chars.concat(pool[:characters][target_rarity.to_sym].map { |c| c[:name] }) }
  chars = chars.uniq.sort

  emoji = case target_rarity
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end

  embed = Discordrb::Webhooks::Embed.new
  embed.title = "📖 Shop Catalog - #{target_rarity.capitalize}s #{emoji}"
  embed.description = "Price: **#{SHOP_PRICES[target_rarity]}** #{EMOJIS['s_coin']} each.\n\n`" + chars.join("`, `") + "`"
  embed.color = NEON_COLORS.sample
  embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Catalog Page #{page} of 3")

  view = Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "shop_catalog_#{user_id}_#{page - 1}", label: 'Previous', style: :primary, emoji: '◀️', disabled: page <= 1)
      r.button(custom_id: "shop_home_#{user_id}", label: 'Back to Shop', style: :secondary, emoji: '🔙')
      r.button(custom_id: "shop_catalog_#{user_id}_#{page + 1}", label: 'Next', style: :primary, emoji: '▶️', disabled: page >= 3)
    end
  end
  [embed, view]
end

def build_blackmarket_page(user_id)
  desc = "Welcome to the underground tech shop. Use `#{PREFIX}buy <Item Name>` to purchase.\n\n"
  
  desc += "**🖥️ Stream Upgrades (Permanent)**\n"
  BLACK_MARKET_ITEMS.each do |key, data|
    if data[:type] == 'upgrade'
      desc += "`#{key}` — **#{data[:name]}** (#{data[:price]} #{EMOJIS['s_coin']})\n> *#{data[:desc]}*\n"
    end
  end

  desc += "\n**🎒 Consumables (One-Time Use)**\n"
  BLACK_MARKET_ITEMS.each do |key, data|
    if data[:type] == 'consumable'
      desc += "`#{key}` — **#{data[:name]}** (#{data[:price]} #{EMOJIS['s_coin']})\n> *#{data[:desc]}*\n"
    end
  end

  embed = Discordrb::Webhooks::Embed.new
  embed.title = "🛒 The Black Market"
  embed.description = desc
  embed.color = NEON_COLORS.sample

  view = Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "shop_home_#{user_id}", label: 'Back to Shop', style: :secondary, emoji: '🔙')
    end
  end

  [embed, view]
end

# =========================
# 5. BOT SETUP & TRIGGERS
# =========================

bot = Discordrb::Commands::CommandBot.new(
  token:   TOKEN,
  prefix:  PREFIX,
  intents: %i[server_messages server_members]
)

load_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings, server_bomb_configs, inventory)

Thread.new do
  loop do
    sleep 60
    save_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings, server_bomb_configs, inventory)
  end
end

trap('INT') do
  puts 'Saving data and shutting down...'
  save_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings, server_bomb_configs, inventory)
  exit
end

trap('TERM') do
  puts 'Saving data and shutting down...'
  save_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings, server_bomb_configs, inventory)
  exit
end

# =========================
# 6. LOAD COMMANDS
# =========================

eval(File.read(File.join(__dir__, 'commands/basic.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/economy.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/gacha.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/arcade.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/trade.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/developer.rb')), binding)

# =========================
# 7. RUN
# =========================

bot.ready do
  bot.playing = "#{PREFIX}help for commands!"
  puts "Bot is connected and status is set to: Playing #{PREFIX}help for commands!"
end

puts "Starting bot with prefix #{PREFIX.inspect}..."
bot.run