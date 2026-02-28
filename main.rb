require 'discordrb'
require 'dotenv/load'
require 'ffi'

LIB_DIR = File.join(__dir__, 'lib')
ENV['PATH'] = "#{LIB_DIR};#{ENV['PATH']}"

module RbNaCl
  module Sodium
    extend FFI::Library
    ffi_lib File.join(LIB_DIR, 'sodium.dll')
    attach_function :sodium_init, [], :int
  end
end

RbNaCl::Sodium.sodium_init

puts "[SYSTEM] Checking voice engine..."
begin
  if defined?(Discordrb::Voice)
    puts "✅ Voice Engine: Ready"
  else
    puts "❌ Voice Engine: Missing (libsodium/sodium.dll not found)"
  end
rescue LoadError => e
  puts "❌ Voice Engine: Load Error - #{e.message}"
end

# =========================
# LOAD CONFIG DATA & DATABASE
# =========================
require_relative 'data/config'
require_relative 'data/pools'
require_relative 'data/database'

# =========================
# DATA STRUCTURES
# =========================
server_bomb_configs = DB.load_all_bomb_configs
ACTIVE_BOMBS       = {} 
ACTIVE_COLLABS     = {}
ACTIVE_TRADES      = {}

COMMAND_CATEGORIES = {
  'Economy'   => [:balance, :daily, :work, :stream, :post, :collab, :cooldowns, :coinlb],
  'Gacha'     => [:summon, :collection, :banner, :shop, :buy, :view, :ascend, :trade],
  'Arcade'    => [:coinflip, :slots, :roulette, :scratch, :dice, :cups],
  'Fun'       => [:kettle, :leaderboard, :hug, :slap, :interactions],
  'Utility'   => [:ping, :help, :about, :level, :call, :dismiss],
  'Admin'   => [:setlevel, :enablebombs, :disablebombs, :levelup, :addxp, :bomb],
  'Developer' => [:addcoins, :setcoins, :blacklist, :card, :backup, :addpremium, :removepremium]
}.freeze

def get_cmd_category(cmd_name)
  COMMAND_CATEGORIES.each do |category, commands|
    return category if commands.include?(cmd_name)
  end
  'Uncategorized'
end

# =========================
# BOT HELPERS
# =========================

def roll_rarity(premium = false)
  roll = rand(100)
  
  premium_table = { common: 40, rare: 40, legendary: 15, goddess: 5 }
  
  active_table = premium ? premium_table : RARITY_TABLE
  
  total = 0
  active_table.each do |(rarity, weight)|
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

def interaction_embed(event, action_name, gifs)
  target = event.message.mentions.first
  unless target
    return send_embed(event, title: "#{EMOJIS['error']} Interaction Error", description: "Mention someone to #{action_name}!")
  end

  actor_id  = event.user.id
  target_id = target.id

  DB.add_interaction(actor_id, action_name, 'sent')
  DB.add_interaction(target_id, action_name, 'received')

  actor_stats  = DB.get_interactions(actor_id)[action_name]
  target_stats = DB.get_interactions(target_id)[action_name]

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

def generate_collection_page(user_obj, rarity_page)
  uid = user_obj.id
  chars = DB.get_collection(uid)
  
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

def collection_view(target_uid, current_page)
  user_chars = DB.get_collection(target_uid)
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
# PREMIUM SYSTEM
# =========================

SUPPORT_SERVER_ID = 1475696989059420162
PREMIUM_ROLE_ID   = 1477110574419808306

def is_premium?(bot, user_id)
  return true if DB.is_lifetime_premium?(user_id)

  server = bot.server(SUPPORT_SERVER_ID)
  return false unless server

  member = server.member(user_id)
  return false unless member

  member.roles.any? { |role| role.id == PREMIUM_ROLE_ID }
end

def award_coins(bot, user_id, amount)
  final_amount = amount
  
  final_amount = (amount * 1.10).round if is_premium?(bot, user_id)
  
  DB.add_coins(user_id, final_amount)
  
  final_amount 
end

# =========================
# BOT SETUP
# =========================

bot = Discordrb::Commands::CommandBot.new(
  token: ENV['TOKEN'],
  prefix: PREFIX,
  intents: [:servers, :server_messages, :server_members, :server_voice_states]
)
# =========================
# LOAD COMMANDS
# =========================

eval(File.read(File.join(__dir__, 'commands/basic.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/economy.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/gacha.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/arcade.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/trade.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/developer.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/leveling.rb')), binding)
eval(File.read(File.join(__dir__, 'commands/voice.rb')), binding)

# =========================
# RUN
# =========================

bot.ready do
  puts "Blossom is connected and live!"
  
  Thread.new do
    storage_server_id  = 1475696989059420162
    storage_channel_id = 1476943608702832680
    
    loop do
      begin
        storage_channel = bot.channel(storage_channel_id, storage_server_id)
        
        if storage_channel
          db_file = "blossom.db"
          if File.exist?(db_file)
            timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
            
            # Send the file with a clear label
            storage_channel.send_message("📦 **Automated Daily Backup**\nTimestamp: `#{timestamp}`")
            File.open(db_file, 'rb') { |file| storage_channel.send_file(file) }
            
            puts "[SYSTEM] Daily backup sent to storage channel."
          end
        else
          puts "[ERROR] Backup failed: Could not find storage channel."
        end
      rescue => e
        puts "[BACKUP ERROR] #{e.message}"
      end

      # Wait exactly 24 hours (86,400 seconds)
      sleep 86400
    end
  end

  loop do
      bot.playing = "#{PREFIX}help in the Arcade 🕹️"
      sleep 15

      server_count = bot.servers.size
      total_members = bot.servers.values.sum { |server| server.member_count }
      bot.playing = "with #{total_members} chatters in #{server_count} servers 🔴| b!"
      sleep 15
    end
  end

DB.get_blacklist.each do |uid|
  bot.ignore_user(uid)
end

puts "Starting bot with prefix #{PREFIX.inspect}..."
bot.run