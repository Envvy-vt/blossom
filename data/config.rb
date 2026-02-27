# =========================
# CONFIG & VARIABLES
# =========================

TOKEN  = ENV['DISCORD_TOKEN'] 
PREFIX = 'b!'
DEV_ID = 1398450651297747065

XP_PER_MESSAGE   = 5
MESSAGE_COOLDOWN = 10 # seconds
SUMMON_COST      = 100

# Direct Buy Prices
SHOP_PRICES = {
  'common'    => 1_000,
  'rare'      => 5_000,
  'legendary' => 25_000
}.freeze

# Duplicate Sell Values (10% of buy price)
SELL_PRICES = {
  'common'    => 50,
  'rare'      => 250,
  'legendary' => 1_000,
  'goddess'   => 5_000
}.freeze

# --- ECONOMY CONFIGS ---
DAILY_REWARD      = 500
DAILY_COOLDOWN    = 24 * 60 * 60 # 24 hours

WORK_REWARD_RANGE = (50..100)
WORK_COOLDOWN     = 60 * 10 # 10 minutes

STREAM_REWARD_RANGE = (100..200)
STREAM_COOLDOWN     = 30 * 60 # 30 minutes
STREAM_GAMES = [
  'Minecraft', 'Valorant', 'Just Chatting', 'Apex Legends',
  'Lethal Company', 'Elden Ring', 'Genshin Impact', 'Phasmophobia',
  'Overwatch 2', 'VRChat'
].freeze

POST_REWARD_RANGE = (20..50)
POST_COOLDOWN     = 5 * 60 # 5 minutes
POST_PLATFORMS = [
  'Twitter/X', 'TikTok', 'Instagram', 'YouTube Shorts', 
  'Bluesky', 'Threads', 'Reddit'
].freeze

COLLAB_REWARD   = 200
COLLAB_COOLDOWN = 30 * 60 # 30 minutes

COINS_PER_MESSAGE = 5

# --- BLACK MARKET CONFIG ---
BLACK_MARKET_ITEMS = {
  'headset' => { name: '🎧 Cheap Headset', price: 500, type: 'upgrade', desc: 'Better audio! Grants +25% to !post payouts.' },
  'keyboard' => { name: '⌨️ RGB Keyboard', price: 2000, type: 'upgrade', desc: 'Type at the speed of light! Grants +25% to !work payouts.' },
  'mic' => { name: '🎙️ Studio Mic', price: 10000, type: 'upgrade', desc: 'Professional audio! Grants +10% to !stream payouts.' },
  'neon sign' => { name: '✨ Holographic Neon Sign', price: 25000, type: 'upgrade', desc: 'Attracts massive attention! Doubles your !daily reward (x2).' },
  'gacha pass' => { name: '🎟️ Gacha Pass', price: 15000, type: 'upgrade', desc: 'Permanently cuts your summon cooldown in half (5 minutes)!' },
  'stamina pill' => { name: '💊 Stamina Pill', price: 1500, type: 'consumable', desc: 'Instantly resets your summon cooldown!' },
  'gamer fuel' => { name: '🥫 Gamer Fuel', price: 2500, type: 'consumable', desc: 'Instantly resets your stream, post, and collab cooldowns!' },
  'rng manipulator' => { name: '🔮 RNG Manipulator', price: 5000, type: 'consumable', desc: 'Guarantees your next !summon is a Rare or higher!' }
}.freeze

# --- MINIGAME CONFIGS ---
BOMB_MIN_MESSAGES = 10
BOMB_MAX_MESSAGES = 20

DATA_FILE = 'bot_data.json'
GLOBAL_LEVELUP_ENABLED = true

NEON_COLORS = [
  0xFF00FF, 0x00FFFF, 0x8A2BE2, 0xFF1493, 
  0x00BFFF, 0x9400D3, 0xFF69B4 
].freeze

# =========================
# CUSTOM SERVER EMOJIS
# =========================
EMOJIS = {
  'coin'          => '<a:coin:1476300163730640956>',
  'like'          => '<a:like:1476300193811927051>',
  'angry'         => '<a:angry:1476300253094346908>',
  'bonk'          => '<a:bonk:1476300267359310138>',
  'drink'         => '<a:drink:1476300280512516146>',
  'error'         => '<a:error:1476300312439554078>',
  'jail'          => '<a:jail:1476300328398885017>',
  'knife'         => '<:knife:1476300339887214754>',
  'hearts'        => '<:hearts:1476300374993408080>',
  'rich'          => '<a:rich:1476300389652500531>',
  'mute'          => '<:mute:1476300428860985446>',
  'nervous'       => '<a:nervous:1476300444618981599>',
  'confused'      => '<a:confused:1476300459286331597>',
  'coins'         => '<a:coins:1476300477217112127>',
  'sparkle'       => '<:sparkle:1476300494195654820>',
  'surprise'      => '<a:surprise:1476300545445724200>',
  'thumbsup'      => '<:thumbsup:1476300593822826516>',
  'thumbsdown'    => '<:thumbsdown:1476300611673788607>',
  'work'          => '<a:work:1476300654120276148>',
  'worktired'     => '<a:worktired:1476300670482251960>',
  'LevelUp'       => '<:LevelUp:1476317904705421332>',
  'x_'            => '<:x_:1476317931099914271>',
  'play'          => '<:play:1476317972799815741>',
  'stream'        => '<:stream:1476318017217368084>',
  'crown'         => '<:crown:1476318072464871646>',
  'heart'         => '<:heart:1476318158104039445>',
  'neonsparkle'   => '<a:neonsparkle:1476318215339769868>',
  'developer'     => '<:developer:1476318256200552528>',
  'rainbowheart'  => '<a:rainbowheart:1476318353189765140>',
  's_coin'        => '<:s_coin:1476318407044628664>',
  'info'          => '<a:info:1476318560123879626>',
  'confuse'       => '<a:confuse:1476318602272444468>',
  'bomb'          => '<a:bomb:1476321595877232802>'
}.freeze