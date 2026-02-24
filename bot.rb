require 'discordrb'
require 'json'
require 'time'
require 'dotenv/load' # <--- Add this line!

# =========================
# CONFIG
# =========================

# Grabs the token securely from your new .env file!
TOKEN  = ENV['DISCORD_TOKEN'] 
PREFIX = '!'

XP_PER_MESSAGE   = 5
MESSAGE_COOLDOWN = 10 # seconds

SUMMON_COST = 100

DAILY_REWARD      = 500
DAILY_COOLDOWN    = 24 * 60 * 60 # 24 hours
WORK_REWARD_RANGE = (50..100)
WORK_COOLDOWN     = 60 * 10 # 10 minutes

COINS_PER_MESSAGE = 5

DATA_FILE = 'bot_data.json'

# default: level-up messages ON
GLOBAL_LEVELUP_ENABLED = true

# Streamer neon color pool (Pink, Cyan, Purple, Blue)
NEON_COLORS = [
  0xFF00FF, # Magenta / Neon Pink
  0x00FFFF, # Cyan / Neon Blue
  0x8A2BE2, # Blue Violet
  0xFF1493, # Deep Pink
  0x00BFFF, # Deep Sky Blue
  0x9400D3, # Dark Violet
  0xFF69B4  # Hot Pink
].freeze

# Single embed color: ruby red
def send_embed(event, title:, description:, fields: nil, image: nil)
  event.channel.send_embed do |embed|
    embed.title = title
    embed.description = description
    embed.color = NEON_COLORS.sample # <--- This picks a random neon color!
    if fields
      fields.each do |f|
        embed.add_field(name: f[:name], value: f[:value], inline: f.fetch(:inline, false))
      end
    end
    embed.image = Discordrb::Webhooks::EmbedImage.new(url: image) if image
    embed.timestamp = Time.now
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Requested by #{event.user.distinct}")
  end
end

# Characters by rarity
# Characters by rarity (VTuber Edition with GIFs)
CHARACTERS = {
  common: [
    { name: 'Filian', gif: 'https://www.dexerto.com/cdn-image/wp-content/uploads/2023/06/05/filian-screenshot.jpg?width=1200&quality=60&format=auto' },
    { name: 'Bao', gif: 'https://cdna.artstation.com/p/assets/images/images/052/242/470/large/charlotte-zhu-tingyu-bao2.jpg?1659327917' },
    { name: 'Silvervale', gif: 'https://s1.zerochan.net/Silvervale.600.3382388.jpg' },
    { name: 'Zentreya', gif: 'https://i.pinimg.com/736x/97/35/eb/9735eb3be571a7b355ad43e5c84e1740.jpg' },
    { name: 'Elira Pendora', gif: 'https://s1.zerochan.net/Elira.Pendora.600.3788087.jpg' },
    { name: 'Finana Ryugu', gif: 'https://s1.zerochan.net/Finana.Ryugu.600.3334984.jpg' },
    { name: 'Obkatiekat', gif: 'https://storage.ko-fi.com/cdn/useruploads/0bc6e44c-d7ef-46c9-a650-60af46b11ab5_png_9d136497-9c84-459e-af6d-542073d3c03fsharable.png?custom=05379cb7-f975-41b2-b634-83868bd9539d' },
    { name: 'CottontailVA', gif: 'https://c10.patreonusercontent.com/4/patreon-media/p/post/100613114/912e98626c554d3395349488f8f9fa43/eyJ3IjoxMDgwfQ%3D%3D/1.png?token-hash=oyVl2ndA3qkg2vzdweJ714psK6qy1j8kMgum7YjWrEU%3D&token-time=1772755200' }
  ],
  rare: [
    { name: 'Hoshimachi Suisei', gif: 'https://i.pinimg.com/736x/fb/f9/d6/fbf9d6edb0e65fd538a931dd4047fd52.jpg' },
    { name: 'Shirakami Fubuki', gif: 'https://w0.peakpx.com/wallpaper/419/798/HD-wallpaper-anime-virtual-youtuber-shirakami-fubuki.jpg' },
    { name: 'Shylily', gif: 'https://i.redd.it/hk4dryof6mtf1.jpeg' },
    { name: 'Kobo Kanaeru', gif: 'https://s1.zerochan.net/Kobo.Kanaeru.600.3723600.jpg' },
    { name: 'Vox Akuma', gif: 'https://images4.alphacoders.com/127/1271665.jpg' },
    { name: 'Nihmune', gif: 'https://cdnb.artstation.com/p/assets/images/images/049/440/717/large/fhilippe124-commission-final.jpg?1652485442' },
    { name: 'Apricot', gif: 'https://s1.zerochan.net/Apricot.the.Lich.600.3795523.jpg' }
  ],
  legendary: [
    { name: 'Gawr Gura', gif: 'https://ih1.redbubble.net/image.1795514236.4101/flat,750x,075,f-pad,750x1000,f8f8f8.jpg' },
    { name: 'Houshou Marine', gif: 'https://preview.redd.it/marine-houshou-fanart-i-did-ahoy-v0-n3hygd8cp6kc1.png?auto=webp&s=81696580f84edd6604cde90978cb17086e5085b0' },
    { name: 'Ironmouse', gif: 'https://spiroworks.com/wp-content/uploads/2025/11/CollabCafe-1024x576.png' },
    { name: 'Kuzuha', gif: 'https://www.dexerto.com/cdn-image/wp-content/uploads/2021/10/09/Kuzuha-Nijisanji-VTuber-tops-charts.jpg' },
    { name: 'Kizuna AI', gif: 'https://images8.alphacoders.com/904/thumb-1920-904634.jpg' },
    { name: 'Mori Calliope', gif: 'https://cdnb.artstation.com/p/assets/images/images/044/580/671/large/soho-2.jpg?1640494073' }
  ]
}.freeze

# Weighted rarity table (percentages)
RARITY_TABLE = [
  [:common, 70],   # 70%
  [:rare, 25],     # 25%
  [:legendary, 5]  # 5%
].freeze

# GIF pools
HUG_GIFS = [
  'https://media.giphy.com/media/l2QDM9Jnim1YVILXa/giphy.gif',
  'https://media.giphy.com/media/od5H3PmEG5EVq/giphy.gif',
  'https://media.giphy.com/media/wnsgren9NtITS/giphy.gif'
].freeze

SLAP_GIFS = [
  'https://media.giphy.com/media/Gf3AUz3eBNbTW/giphy.gif',
  'https://media.giphy.com/media/jLeyZWgtwgr2U/giphy.gif',
  'https://media.giphy.com/media/Zau0yrl17uzdK/giphy.gif'
].freeze

# =========================
# DATA STRUCTURES
# =========================

users = Hash.new do |hash, server_id|
  hash[server_id] = Hash.new { |h, user_id| h[user_id] = { 'xp' => 0, 'level' => 1, 'last_xp_at' => nil } }
end

coins              = Hash.new(0)
collections        = Hash.new { |h, k| h[k] = {} }
interactions       = Hash.new do |h, k|
  h[k] = {
    'hug'  => { 'sent' => 0, 'received' => 0 },
    'slap' => { 'sent' => 0, 'received' => 0 }
  }
end
economy_cooldowns  = Hash.new { |h, k| h[k] = { 'daily_at' => nil, 'work_at' => nil } }
levelup_settings   = {} # server_id => true/false

# Tracks active bombs to prevent multiple defuses or late explosions
ACTIVE_BOMBS       = {} 

# Tracks active collabs to prevent self-acceptance and handle timeouts
ACTIVE_COLLABS = {}

# =========================
# PERSISTENCE HELPERS
# =========================

def load_data(file, users, coins, collections, interactions, economy_cooldowns, levelup_settings)
  return unless File.exist?(file)

  raw = JSON.parse(File.read(file))

  (raw['users'] || {}).each do |server_id_str, server_data|
    # Safety check: Ignore old global data format so the bot doesn't crash during migration
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
      # Migrate old array format to new quantity hash format
      data.each do |c|
        name = c['name']
        rarity = c['rarity']
        collections[uid][name] ||= { 'rarity' => rarity, 'count' => 0 }
        collections[uid][name]['count'] += 1
      end
    else
      # Load new quantity hash format directly
      collections[uid] = data
    end
  end

  (raw['interactions'] || {}).each do |id_str, data|
    id = id_str.to_i

    # Backward compatible: if old flat structure, convert it
    if data.key?('sent') && data.key?('received')
      interactions[id] = {
        'hug'  => { 'sent' => data['sent'] || 0, 'received' => data['received'] || 0 },
        'slap' => { 'sent' => 0, 'received' => 0 }
      }
    else
      interactions[id] = {
        'hug' => {
          'sent'     => data.dig('hug', 'sent') || 0,
          'received' => data.dig('hug', 'received') || 0
        },
        'slap' => {
          'sent'     => data.dig('slap', 'sent') || 0,
          'received' => data.dig('slap', 'received') || 0
        }
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
rescue StandardError => e
  puts "Failed to load data: #{e.message}"
end

def save_data(file, users, coins, collections, interactions, economy_cooldowns, levelup_settings)
  payload = {
    users: users.transform_values do |server_data|
      server_data.transform_values do |u|
        {
          xp: u['xp'],
          level: u['level'],
          last_xp_at: u['last_xp_at']&.iso8601
        }
      end
    end,

    coins: coins,
    collections: collections,
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
    levelup_settings: levelup_settings
  }

  File.write(file, JSON.pretty_generate(payload))
rescue StandardError => e
  puts "Failed to save data: #{e.message}"
end

# =========================
# HELPER METHODS
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
  days = seconds / 86_400
  seconds %= 86_400
  hours = seconds / 3600
  seconds %= 3600
  minutes = seconds / 60
  seconds %= 60

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
  event.channel.send_embed do |embed|
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
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Requested by #{event.user.distinct}")
  end
end

def interaction_embed(event, action_name, gifs, interactions)
  target = event.message.mentions.first
  unless target
    return send_embed(
      event,
      title: 'Interaction Error',
      description: "Mention someone to #{action_name}!"
    )
  end

  actor_id  = event.user.id
  target_id = target.id

  interactions[actor_id]
  interactions[target_id]

  interactions[actor_id][action_name]['sent']     += 1
  interactions[target_id][action_name]['received'] += 1

  actor_stats  = interactions[actor_id][action_name]
  target_stats = interactions[target_id][action_name]

  gif = gifs.sample

  send_embed(
    event,
    title: action_name.capitalize,
    description: "#{event.user.mention} #{action_name}s #{target.mention}!",
    fields: [
      {
        name: "#{event.user.name}'s #{action_name}s",
        value: "Sent: **#{actor_stats['sent']}**\nReceived: **#{actor_stats['received']}**",
        inline: true
      },
      {
        name: "#{target.name}'s #{action_name}s",
        value: "Sent: **#{target_stats['sent']}**\nReceived: **#{target_stats['received']}**",
        inline: true
      }
    ],
    image: gif
  )
end

# =========================
# BOT SETUP
# =========================

bot = Discordrb::Commands::CommandBot.new(
  token:   TOKEN,
  prefix:  PREFIX,
  intents: %i[server_messages server_members]
)

# Load persistent data at startup
load_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings)

# Save data periodically (every 60 seconds)
Thread.new do
  loop do
    sleep 60
    save_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings)
  end
end

# Also save on shutdown
trap('INT') do
  puts 'Saving data and shutting down...'
  save_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings)
  exit
end

trap('TERM') do
  puts 'Saving data and shutting down...'
  save_data(DATA_FILE, users, coins, collections, interactions, economy_cooldowns, levelup_settings)
  exit
end

# =========================
# BASIC COMMANDS
# =========================

bot.command(:ping, description: 'Check bot latency') do |event|
  # Calculate the time difference between when the user sent the message and right now
  time_diff = Time.now - event.message.timestamp
  
  # Convert to milliseconds and round to a clean number
  latency_ms = (time_diff * 1000).round 
  
  send_embed(
    event,
    title: '🏓 Pong!',
    description: "My connection to Discord is **#{latency_ms}ms**.\nChat is moving fast! 💨"
  )
  
  nil
end

bot.command(:kettle, description: 'Pings a specific user with a yay emoji') do |event|
  # <@USER_ID> is the standard Discord format for pinging a user
  event.respond("<:gwolfYay:1475837867598024864> <@266358927401287680> <:gwolfYay:1475837867598024864>")
  nil
end

bot.command(:help, description: 'Shows a list of all available commands') do |event|
  # Grab all the commands registered to the bot and sort them alphabetically
  all_commands = event.bot.commands.values.sort_by(&:name)

  # Format each command into a neat string using the description you provided in the code
  command_lines = all_commands.map do |cmd|
    desc = cmd.attributes[:description] || 'No description provided.'
    "> `#{PREFIX}#{cmd.name}` - #{desc}"
  end

  # Discord embed fields have a strict 1024-character limit. 
  # To make sure your bot never crashes if you add 50+ commands later, 
  # this slices your command list into chunks of 10 and creates a new field for each chunk!
  fields = []
  command_lines.each_slice(10).with_index do |slice, index|
    fields << {
      name: index == 0 ? '📜 Command List' : '📜 Command List (Cont.)',
      value: slice.join("\n"),
      inline: false
    }
  end

  send_embed(
    event,
    title: '🌸 Bot Help Menu',
    description: "Here is everything I can do! My prefix is `#{PREFIX}`.",
    fields: fields
  )
  
  nil
end

bot.command(:about, description: 'Learn more about Blossom and her creator!') do |event|
  fields = [
    {
      name: '🎮 The Content Grind',
      value: "We are on that monetization grind! I manage the server's economy so you can earn coins by hitting that `!stream` button, getting engagement with a quick `!post` on socials, or doing a `!collab` with other chatters.",
      inline: false
    },
    {
      name: '🌟 VTuber Gacha',
      value: "Spend your hard-earned stream revenue to `!summon` your favorite VTubers! Will you pull common indie darlings, or hit the legendary RNG for Gura, Calli, or Ironmouse? Build your `!collection` and flex your pulls!",
      inline: false
    },
    {
      name: '💬 Just Chatting & Vibes',
      value: "Lurkers don't get XP here! I track your chat activity and reward you with levels the more you type. Plus, you can `!hug` your friends or `!slap` a troll.",
      inline: false
    },
    {
      name: '💣 A Little Bit of Trolling',
      value: "Sometimes chat gets too cozy, so the admins let me drop a literal `!bomb` in the channel. You have to scramble to defuse it for a massive coin payout, or the whole chat goes BOOM!",
      inline: false
    },
    {
      name: '🛠️ Behind the Scenes',
      value: "Made by **Envvy.VT** and coded in **.rb** (Ruby).",
      inline: false
    }
  ]

  send_embed(
    event,
    title: '🌸 About Blossom',
    description: "Hey Chat! I'm **Blossom**, your server's dedicated head mod, hype-woman, and resident gacha addict. I'm here to turn your Discord server into the ultimate content creator community.\n\nDrop a `!help` in chat and let's go live! 🔴✨",
    fields: fields
  )
  
  nil
end

# =========================
# LEVELING SYSTEM
# =========================

bot.message do |event|
  next if event.user.bot_account?
  next unless event.server # Ignore Direct Messages

  sid  = event.server.id
  uid  = event.user.id
  user = users[sid][uid]

  now = Time.now
  if user['last_xp_at'] && (now - user['last_xp_at']) < MESSAGE_COOLDOWN
    next
  end

  user['xp'] += XP_PER_MESSAGE
  user['last_xp_at'] = now
  
  # Coins remain global so players can use them anywhere!
  coins[uid] += COINS_PER_MESSAGE

  needed = user['level'] * 100
  if user['xp'] >= needed
    user['xp']   -= needed
    user['level'] += 1

    if levelup_enabled_for?(sid, levelup_settings)
      send_embed(
        event,
        title: 'Level Up!',
        description: "#{event.user.mention} reached level **#{user['level']}**!",
        fields: [
          {
            name: 'XP Remaining',
            value: "#{user['xp']}/#{user['level'] * 100}",
            inline: true
          },
          {
            name: 'Coins',
            value: coins[uid].to_s,
            inline: true
          }
        ]
      )
    end
  end
end

bot.command(:level, description: 'Show your level and XP for this server') do |event|
  unless event.server
    event.respond("This command can only be used in a server!")
    next
  end

  sid  = event.server.id
  uid  = event.user.id
  user = users[sid][uid]
  needed = user['level'] * 100

  send_embed(
    event,
    title: "#{event.user.name}'s Server Level",
    description: '',
    fields: [
      { name: 'Level', value: user['level'].to_s, inline: true },
      { name: 'XP', value: "#{user['xp']}/#{needed}", inline: true },
      { name: 'Global Coins', value: coins[uid].to_s, inline: true }
    ]
  )
  nil
end

bot.command(:leaderboard, description: 'Show top users by level and XP for this server') do |event|
  unless event.server
    event.respond("This command can only be used in a server!")
    next
  end

  sid = event.server.id
  
  # Sort only the users inside THIS specific server
  sorted = users[sid].sort_by { |_id, data| [-(data['level']), -(data['xp'])] }.first(10)

  if sorted.empty?
    send_embed(
      event,
      title: 'Server Leaderboard',
      description: 'Nobody has gained any XP here yet.'
    )
  else
    desc = sorted.each_with_index.map do |(id, data), index|
      user_obj = event.bot.user(id)
      name = user_obj ? user_obj.name : "User #{id}"
      "##{index + 1} — **#{name}**: Level #{data['level']} (#{data['xp']} XP)"
    end.join("\n")

    send_embed(
      event,
      title: 'Server Leaderboard',
      description: desc
    )
  end
  nil
end

bot.command(:levelup, description: 'Enable or disable level-up messages for this server (Admin only)') do |event, state|
  unless event.server
    send_embed(
      event,
      title: 'Level-Up Settings',
      description: 'This command can only be used in a server.'
    )
    next
  end

  perms = event.user.permission? :manage_server, event.channel
  unless perms
    send_embed(
      event,
      title: 'Level-Up Settings',
      description: 'You need the Manage Server permission to change this setting.'
    )
    next
  end

  case state&.downcase
  when 'on', 'enable', 'enabled'
    levelup_settings[event.server.id] = true
    send_embed(
      event,
      title: 'Level-Up Settings',
      description: 'Level-up messages are now **enabled** in this server.'
    )
  when 'off', 'disable', 'disabled'
    levelup_settings[event.server.id] = false
    send_embed(
      event,
      title: 'Level-Up Settings',
      description: 'Level-up messages are now **disabled** in this server.'
    )
  else
    current = levelup_enabled_for?(event.server.id, levelup_settings) ? 'enabled' : 'disabled'
    send_embed(
      event,
      title: 'Level-Up Settings',
      description: "Usage: `!levelup on` or `!levelup off`\nCurrently **#{current}**."
    )
  end
  nil
end

# =========================
# ECONOMY SYSTEM
# =========================

bot.command(:balance, description: 'Show your coin balance') do |event|
  uid = event.user.id
  send_embed(
    event,
    title: "#{event.user.name}'s Balance",
    description: "You have **#{coins[uid]}** coins."
  )
  nil
end

bot.command(:daily, description: 'Claim your daily coin reward') do |event|
  uid = event.user.id
  now = Time.now
  cd  = economy_cooldowns[uid]

  if cd['daily_at'] && (now - cd['daily_at']) < DAILY_COOLDOWN
    remaining = DAILY_COOLDOWN - (now - cd['daily_at'])
    send_embed(
      event,
      title: 'Daily Reward',
      description: "You already claimed your daily.\nTry again in **#{format_time_delta(remaining)}**."
    )
  else
    coins[uid] += DAILY_REWARD
    cd['daily_at'] = now
    send_embed(
      event,
      title: 'Daily Reward',
      description: "You claimed **#{DAILY_REWARD}** coins!\nNew balance: **#{coins[uid]}**."
    )
  end
  nil
end

bot.command(:work, description: 'Work for some coins (5min cooldown)') do |event|
  uid = event.user.id
  now = Time.now
  cd  = economy_cooldowns[uid]

  if cd['work_at'] && (now - cd['work_at']) < WORK_COOLDOWN
    remaining = WORK_COOLDOWN - (now - cd['work_at'])
    send_embed(
      event,
      title: 'Work',
      description: "You are tired.\nTry working again in **#{format_time_delta(remaining)}**."
    )
  else
    amount = rand(WORK_REWARD_RANGE)
    coins[uid] += amount
    cd['work_at'] = now
    send_embed(
      event,
      title: 'Work',
      description: "You worked hard and earned **#{amount}** coins!\nNew balance: **#{coins[uid]}**."
    )
  end
  nil
end

# Stream config
STREAM_COOLDOWN = 30 * 60 # 30 minutes
STREAM_REWARD_RANGE = (100..200)
STREAM_GAMES = [
  'Minecraft', 'Valorant', 'Just Chatting', 'Apex Legends',
  'Lethal Company', 'Elden Ring', 'Genshin Impact', 'Phasmophobia',
  'Overwatch 2', 'VRChat'
].freeze

bot.command(:stream, description: 'Go live and earn some coins! (30m cooldown)') do |event|
  uid = event.user.id
  now = Time.now
  cd  = economy_cooldowns[uid]

  # Check if the user is on cooldown
  if cd['stream_at'] && (now - cd['stream_at']) < STREAM_COOLDOWN
    remaining = STREAM_COOLDOWN - (now - cd['stream_at'])
    send_embed(
      event,
      title: '🔴 Stream Offline',
      description: "You just finished streaming! Your voice needs a break.\nTry going live again in **#{format_time_delta(remaining)}**."
    )
  else
    # Generate the reward and pick a game
    reward = rand(STREAM_REWARD_RANGE)
    game = STREAM_GAMES.sample
    
    # Apply rewards and start the cooldown timer
    coins[uid] += reward
    cd['stream_at'] = now

    send_embed(
      event,
      title: '🔴 Stream Ended',
      description: "You had a great stream playing **#{game}** and earned **#{reward}** coins!\nNew balance: **#{coins[uid]}**."
    )
  end
  
  nil
end

# Social Media config
POST_COOLDOWN = 5 * 60 # 5 minutes
POST_REWARD_RANGE = (20..50)
POST_PLATFORMS = [
  'Twitter/X', 'TikTok', 'Instagram', 'YouTube Shorts', 
  'Bluesky', 'Threads', 'Reddit'
].freeze

bot.command(:post, description: 'Post on social media for some quick coins! (5m cooldown)') do |event|
  uid = event.user.id
  now = Time.now
  cd  = economy_cooldowns[uid]

  if cd['post_at'] && (now - cd['post_at']) < POST_COOLDOWN
    remaining = POST_COOLDOWN - (now - cd['post_at'])
    send_embed(
      event,
      title: '📱 Social Media Break',
      description: "You're posting too fast! Don't get shadowbanned.\nTry posting again in **#{format_time_delta(remaining)}**."
    )
  else
    reward = rand(POST_REWARD_RANGE)
    platform = POST_PLATFORMS.sample
    
    coins[uid] += reward
    cd['post_at'] = now

    send_embed(
      event,
      title: '📱 New Post Uploaded!',
      description: "Your latest post on **#{platform}** got a lot of engagement! You earned **#{reward}** coins.\nNew balance: **#{coins[uid]}**."
    )
  end
  
  nil
end

# Collab config
COLLAB_COOLDOWN = 30 * 60 # 30 minutes
COLLAB_REWARD = 200

bot.command(:collab, description: 'Ask the server to do a collab stream! (30m cooldown)') do |event|
  uid = event.user.id
  now = Time.now
  cd  = economy_cooldowns[uid]

  # 1. Check Cooldown
  if cd['collab_at'] && (now - cd['collab_at']) < COLLAB_COOLDOWN
    remaining = COLLAB_COOLDOWN - (now - cd['collab_at'])
    send_embed(
      event,
      title: 'Collab Burnout',
      description: "You're collaborating too much! Rest your voice.\nTry again in **#{format_time_delta(remaining)}**."
    )
    next
  end

  # 2. Put the user on cooldown
  cd['collab_at'] = now

  # 3. Setup the Collab request
  expire_time = Time.now + 180 # 3 minutes
  discord_timestamp = "<t:#{expire_time.to_i}:R>"
  
  collab_id = "collab_#{expire_time.to_i}_#{rand(10000)}"
  # Store the user's ID so we know who to reward and who to block from clicking
  ACTIVE_COLLABS[collab_id] = uid 

  embed = Discordrb::Webhooks::Embed.new(
    title: '🎙️ Collab Request!',
    description: "#{event.user.mention} is looking for someone to do a collab stream with!\n\nPress the button below to join them! Request expires **#{discord_timestamp}**.",
    color: NEON_COLORS.sample
  )

  view = Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: collab_id, label: 'Accept Collab', style: :success, emoji: '🤝')
    end
  end

  msg = event.channel.send_message(nil, false, embed, nil, false, nil, view)

  # 4. Background thread for the 3-minute timeout
  Thread.new do
    sleep 180
    if ACTIVE_COLLABS.key?(collab_id)
      # Nobody clicked it in time
      ACTIVE_COLLABS.delete(collab_id)

      failed_embed = Discordrb::Webhooks::Embed.new(
        title: '📉 Collab Cancelled',
        description: "Nobody was available to collab with #{event.user.mention} this time...",
        color: 0x808080 # Gray
      )
      
      # Remove the button and update the message
      msg.edit(nil, failed_embed, Discordrb::Components::View.new)
    end
  end

  nil
end

# Listener for the "Accept Collab" button
bot.button(custom_id: /^collab_/) do |event|
  collab_id = event.custom_id

  # Check if this collab is still active
  if ACTIVE_COLLABS.key?(collab_id)
    author_id = ACTIVE_COLLABS[collab_id]

    # Prevent the user from accepting their own collab
    if event.user.id == author_id
      event.respond(content: "You can't accept your own collab request!", ephemeral: true)
      next
    end

    # Success! Remove it from active collabs
    ACTIVE_COLLABS.delete(collab_id)

    # Reward both the author and the person who accepted
    coins[author_id] += COLLAB_REWARD
    coins[event.user.id] += COLLAB_REWARD

    author_user = event.bot.user(author_id)
    author_mention = author_user ? author_user.mention : "<@#{author_id}>"

    success_embed = Discordrb::Webhooks::Embed.new(
      title: '🎉 Collab Stream Started!',
      description: "#{event.user.mention} accepted the collab with #{author_mention}!\n\nBoth streamers earned **#{COLLAB_REWARD}** coins for an awesome stream.",
      color: 0x00FF00 # Green
    )

    # Update the original message and wipe the button
    event.update_message(content: nil, embeds: [success_embed], components: Discordrb::Components::View.new)
  else
    event.respond(content: 'This collab request has already expired or been accepted!', ephemeral: true)
  end
end

bot.command(:cooldowns, description: 'Check your active timers for economy commands') do |event|
  uid = event.user.id
  now = Time.now
  cd  = economy_cooldowns[uid]

  # A small helper method to calculate remaining time or return "Ready!"
  check_cd = ->(last_used, cooldown_duration) do
    if last_used && (now - last_used) < cooldown_duration
      remaining = cooldown_duration - (now - last_used)
      "⏳ Ready in **#{format_time_delta(remaining)}**"
    else
      "✅ **Ready!**"
    end
  end

  # Build the fields using our helper
  fields = [
    {
      name: '🎁 Daily (`!daily`)',
      value: check_cd.call(cd['daily_at'], DAILY_COOLDOWN),
      inline: true
    },
    {
      name: '💼 Work (`!work`)',
      value: check_cd.call(cd['work_at'], WORK_COOLDOWN),
      inline: true
    },
    {
      name: '🔴 Stream (`!stream`)',
      value: check_cd.call(cd['stream_at'], STREAM_COOLDOWN),
      inline: true
    },
    {
      name: '📱 Post (`!post`)',
      value: check_cd.call(cd['post_at'], POST_COOLDOWN),
      inline: true
    },
    {
      name: '🤝 Collab (`!collab`)',
      value: check_cd.call(cd['collab_at'], COLLAB_COOLDOWN),
      inline: true
    }
  ]

  send_embed(
    event,
    title: "⏱️ #{event.user.name}'s Cooldowns",
    description: "Here is when you can hit the grind again:",
    fields: fields
  )
  
  nil
end

# =========================
# GACHA / CHARACTER SUMMONS
# =========================

bot.command(:summon, description: 'Spend coins to summon a random character') do |event|
  uid = event.user.id

  if coins[uid] < SUMMON_COST
    send_embed(
      event,
      title: 'Summon',
      description: "You need **#{SUMMON_COST}** coins to summon.\nYou currently have **#{coins[uid]}**."
    )
    next
  end

  coins[uid] -= SUMMON_COST

  # Roll for rarity, then sample a full character hash from that rarity
  rarity = roll_rarity
  pulled_char = CHARACTERS[rarity].sample
  
  name = pulled_char[:name]
  gif_url = pulled_char[:gif]
  
  # Initialize the character in their inventory if they don't have it, then increment count
  collections[uid][name] ||= { 'rarity' => rarity.to_s, 'count' => 0 }
  collections[uid][name]['count'] += 1

  rarity_label = rarity.to_s.capitalize
  emoji = case rarity
          when :legendary then '🌟'
          when :rare      then '✨'
          else '⭐'
          end

  send_embed(
    event,
    title: 'Summon Result',
    description: "#{emoji} You summoned **#{name}** (#{rarity_label})!\nYou now own **#{collections[uid][name]['count']}** of them.",
    fields: [
      { name: 'Remaining Balance', value: coins[uid].to_s, inline: true }
    ],
    image: gif_url # <--- This passes the VTuber's specific GIF to the embed!
  )
  nil
end

bot.command(:collection, description: 'View your summoned characters') do |event|
  uid   = event.user.id
  chars = collections[uid] # Now a Hash: { "Slime" => { "rarity" => "common", "count" => 5 }, ... }

  if chars.empty?
    send_embed(
      event,
      title: 'Your Collection',
      description: 'You have no characters yet. Use `!summon` to roll one!'
    )
  else
    # Convert the hash back into a flat list so we can group it easily
    char_list = chars.map { |name, data| { 'name' => name, 'rarity' => data['rarity'], 'count' => data['count'] } }
    grouped = char_list.group_by { |c| c['rarity'] }
    
    fields = []

    %w[legendary rare common].each do |rar|
      next unless grouped[rar]

      title = rar.capitalize
      emoji = case rar
              when 'legendary' then '🌟'
              when 'rare'      then '✨'
              else '⭐'
              end
              
      # Format names to include their quantities
      names_with_counts = grouped[rar].map { |c| "#{c['name']} (x#{c['count']})" }
      
      # Calculate total distinct characters vs total cards owned in this rarity
      total_distinct = grouped[rar].size
      total_cards = grouped[rar].sum { |c| c['count'] }

      fields << {
        name: "#{emoji} #{title} (Unique: #{total_distinct} | Total: #{total_cards})",
        value: names_with_counts.join(', ')
      }
    end

    send_embed(
      event,
      title: "#{event.user.name}'s Collection",
      description: '',
      fields: fields
    )
  end
  nil
end

# =========================
# INTERACTIVE COMMANDS
# =========================

bot.command(:hug, description: 'Send a hug with a random GIF') do |event|
  interaction_embed(event, 'hug', HUG_GIFS, interactions)
  nil
end

bot.command(:slap, description: 'Send a playful slap with a random GIF') do |event|
  interaction_embed(event, 'slap', SLAP_GIFS, interactions)
  nil
end

bot.command(:interactions, description: 'Show your hug/slap stats') do |event|
  data = interactions[event.user.id]

  hug  = data['hug']
  slap = data['slap']

  send_embed(
    event,
    title: "#{event.user.name}'s Interaction Stats",
    description: '',
    fields: [
      {
        name: 'Hugs',
        value: "Sent: **#{hug['sent']}**\nReceived: **#{hug['received']}**",
        inline: true
      },
      {
        name: 'Slaps',
        value: "Sent: **#{slap['sent']}**\nReceived: **#{slap['received']}**",
        inline: true
      }
    ]
  )
  nil
end

# =========================
# BOMB COMMAND
# =========================

bot.command(:bomb, description: 'Plant a bomb that explodes in 5 minutes (Admin only)') do |event|
  # Check for Administrator permissions
  unless event.user.permission?(:administrator, event.channel)
    send_embed(
      event,
      title: 'Permission Denied',
      description: 'You need Administrator permissions to plant a bomb!'
    )
    next
  end

  # Set expiration to 5 minutes (300 seconds) from now
  expire_time = Time.now + 300
  discord_timestamp = "<t:#{expire_time.to_i}:R>"
  
  bomb_id = "bomb_#{expire_time.to_i}_#{rand(10000)}"
  ACTIVE_BOMBS[bomb_id] = true

  embed = Discordrb::Webhooks::Embed.new(
    title: '💣 Bomb Planted!',
    description: "An admin has planted a bomb! It will explode **#{discord_timestamp}**!\nQuick, press the button to defuse it and earn a reward!",
    color: NEON_COLORS.sample
  )

  view = Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: bomb_id, label: 'Defuse', style: :danger, emoji: '✂️')
    end
  end

  msg = event.channel.send_message(nil, false, embed, nil, false, nil, view)

  # Background thread for the 5-minute timer
  Thread.new do
    sleep 300
    if ACTIVE_BOMBS[bomb_id]
      ACTIVE_BOMBS.delete(bomb_id)

      exploded_embed = Discordrb::Webhooks::Embed.new(
        title: '💥 BOOM!',
        description: 'Nobody defused it in time... The bomb exploded!',
        color: 0x000000 
      )
      
      msg.edit(nil, exploded_embed, Discordrb::Components::View.new)
    end
  end

  nil
end

# Listener for the "Defuse" button press
bot.button(custom_id: /^bomb_/) do |event|
  bomb_id = event.custom_id

  if ACTIVE_BOMBS[bomb_id]
    ACTIVE_BOMBS.delete(bomb_id)

    # Generate a random coin reward between 50 and 150
    reward = rand(50..150)
    
    # Add the reward to the user's balance
    coins[event.user.id] += reward

    defused_embed = Discordrb::Webhooks::Embed.new(
      title: '🛡️ Bomb Defused!',
      description: "The bomb was successfully defused by #{event.user.mention}!\nThey earned **#{reward}** coins for their bravery.",
      color: 0x00FF00 
    )

    event.update_message(content: nil, embeds: [defused_embed], components: Discordrb::Components::View.new)
  else
    event.respond(content: 'This bomb has already exploded or been defused!', ephemeral: true)
  end
end

# =========================
# READY EVENT (STATUS)
# =========================

bot.ready do
  # Sets the "Playing" status on the bot's profile
  bot.playing = "#{PREFIX}help for commands!"
  puts "Bot is connected and status is set to: Playing #{PREFIX}help for commands!"
end

# =========================
# RUN BOT
# =========================

puts "Starting bot with prefix #{PREFIX.inspect}..."
bot.run