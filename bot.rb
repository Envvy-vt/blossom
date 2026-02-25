require 'discordrb'
require 'json'
require 'time'
require 'dotenv/load'

# =========================
# CONFIG
# =========================

# Grabs the token securely from your .env file
TOKEN  = ENV['DISCORD_TOKEN'] 
PREFIX = '!'

DEV_ID = 1398450651297747065

XP_PER_MESSAGE   = 5
MESSAGE_COOLDOWN = 10 # seconds

SUMMON_COST = 100

# Direct Buy Prices
SHOP_PRICES = {
  'common'    => 1_000,
  'rare'      => 5_000,
  'legendary' => 25_000
}.freeze

# Duplicate Sell Values (10% of buy price)
SELL_PRICES = {
  'common'    => 100,
  'rare'      => 500,
  'legendary' => 2_500
}.freeze

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
    embed.footer = Discordrb::Webhooks::EmbedFooter.new(text: "Requested by #{event.user.display_name}", icon_url: event.user.avatar_url)
  end
end

# Characters by rarity
# Rotating Gacha Banners

CHARACTER_POOLS = {
  pool_a: {
    name: '🌐 Western Indies & VShojo Banner',
    characters: {
      common: [
        { name: 'Filian', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906142571073709/Filian.full.3794780.png?ex=699f3035&is=699ddeb5&hm=0fa5a3108c7ab2f09cbc25075057215447f0bd7039df1a28dd2ac778cd9bb1f7&=&format=webp&quality=lossless&width=599&height=800' },
        { name: 'Bao', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906000530706505/Bao.Vtuber.full.3715040.png?ex=699f3013&is=699dde93&hm=73bc6e60238efd9cee449aba416451af0a3d8d6d2299f24ba57f81e315e906b7&=&format=webp&quality=lossless&width=1421&height=800' },
        { name: 'Silvervale', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906146434027550/Silvervale.600.3382388.jpg?ex=699f3036&is=699ddeb6&hm=344ae1a0e630f4473f63487aa2636687951057b5858877fae7ba544fc30f9ca2&=&format=webp&width=750&height=423' },
        { name: 'Zentreya', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475905997036978319/9735eb3be571a7b355ad43e5c84e1740.jpg?ex=699f3012&is=699dde92&hm=5cad4719732dab191191c17d1f3037c1afc67e355387d171aa9fcb65b32bd1c8&=&format=webp&width=919&height=519' },
        { name: 'Obkatiekat', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475905996638650421/0bc6e44c-d7ef-46c9-a650-60af46b11ab5_png_9d136497-9c84-459e-af6d-542073d3c03fsharable.png?ex=699f3012&is=699dde92&hm=f69abada94390d8c8cce7acbe4e6a2fbf1c77e6322ad7469f60d3346094b9db7&=&format=webp&quality=lossless&width=1463&height=800' },
        { name: 'Sinder', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906145574064310/nanoless-sinder-vtuber-snow-coats-brunette-hd-wallpaper-preview.jpg?ex=699f3036&is=699ddeb6&hm=2cbecf900ae3e42bb6f542e76bd7aca9ea0269be6e2836c153792e5809701b61&=&format=webp&width=910&height=513' },
        { name: 'Trickywi', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906141266379076/E-8_UgOXoBQM58Z.png?ex=699f3035&is=699ddeb5&hm=c5853c11c35cf12e25a08b1a64398c590c627bae90a24132423fcf57b5c252a6&=&format=webp&quality=lossless' },
        { name: 'CottontailVA', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906002032398386/CottonTailF.png?ex=699f3013&is=699dde93&hm=cf34733a8b26394d8457a089842012b45dd0b5eadc1620bebd1a8c391d5db42c&=&format=webp&quality=lossless&width=1116&height=800' },
        { name: 'Haruka Karibu', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906143044898998/haruka-karibu-v0-vfrk3706as4e1.webp?ex=699f3035&is=699ddeb5&hm=e82372d5ab3056ba22edd827f0d756eded667d7fab2c5034b9c1ea3de5496402&=&format=webp&width=566&height=800' },
        { name: 'Kuro Kurenai', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475905999092187238/b342fcdcd50602e096cc7b5205561522.jpg?ex=699f3013&is=699dde93&hm=954a6a7456add7e97286a679fbafe70857d1777ca689aea51c613e881309ee11&=&format=webp&width=600&height=800' }
      ],
      rare: [
        { name: 'Shylily', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906143846006794/hk4dryof6mtf1.jpeg?ex=699f3035&is=699ddeb5&hm=0c98e6844bcd82f7608abbefb600ed9d085dcfb485132488f41480c4d82ddc36&=&format=webp&width=1195&height=800' },
        { name: 'Nihmune', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906141803511940/fhilippe124-commission-final.jpg?ex=699f3035&is=699ddeb5&hm=0786a97762222f681df738434d219d58cf5cd0ec59d4f2dc1a24e3e67a1043a3&=&format=webp&width=1420&height=800' },
        { name: 'Apricot', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475905997422727249/Apricot.the.Lich.600.3795523.jpg?ex=699f3012&is=699dde92&hm=172c77800e707b2a545c5a10872567cd1e6a31ee53df0ca9a76d4d774a1ab5ee&=&format=webp&width=750&height=530' },
        { name: 'Henya the Genius', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906145154629743/light_artist-henya-the-genius-artgift01-by-light-artist.jpg?ex=699f3036&is=699ddeb6&hm=6f8101137f3465bca5e0cf88f4dfc34eb0f6f1e2eee70fd9ba0bd0c084df1346&=&format=webp&width=1421&height=800' },
        { name: 'Kson', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906144605311106/Kson.full.3906147.jpg?ex=699f3035&is=699ddeb5&hm=d591d4058fd2e783d3f4e9387f61f00ad4ff465ed772870aa51203e505b895df&=&format=webp&width=576&height=800' },
        { name: 'Veibae', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475905997905199205/arden-galdones-vshojo-veibae-merch-illustration-lowres.jpg?ex=699f3012&is=699dde92&hm=141624dc3c9b32a82e063612d8c0909cb25902bfdf613e5d290fc090dacfdfd1&=&format=webp' },
        { name: 'Monarch (AmaLee)', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906157569773679/wp15698433.webp?ex=699f3038&is=699ddeb8&hm=b7f907a8df900947318c23d481f5c18808fc9b3980cd4c9e9488f68ea93bf976&=&format=webp&width=1423&height=800' },
        { name: 'Chibidoki', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475905996130881596/0a5dc010-2156-477e-b897-d9deb9c1fc1e-profile_banner-480.png?ex=699f3012&is=699dde92&hm=046a21cb56344a9022c622de326c2bbee6621c52bb2b3024df449356ec13f1ee&=&format=webp&quality=lossless&width=1066&height=600' }
      ],
      legendary: [
        { name: 'Ironmouse', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475935719846445293/CollabCafe-1024x576.png?ex=699f4bc1&is=699dfa41&hm=f387f1b170955e07f479453c2d318c8a244862e26ab892bceb28cc1c7830917c&=&format=webp&quality=lossless&width=1280&height=720' },
        { name: 'Nyanners', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475905998542606408/b58caa30-643b-4c5d-be1c-5dbac45c7af9_nyah2.jpg?ex=699f3013&is=699dde93&hm=7043c68b94244b02d8aa2187de90167237f6c3fb9eb3692860bcd5f70f901134&=&format=webp&width=975&height=673' },
        { name: 'Snuffy', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906147092267049/Snuffy_Swimsuit_Outfit_Icon.webp?ex=699f3036&is=699ddeb6&hm=4be3bc13db7a6dddd7b4c680d5237564dd6e8a8feedc54fe97e01c626608906d&=&format=webp&width=800&height=800' },
        { name: 'Projekt Melody', gif: 'https://media.discordapp.net/attachments/1475889769820192861/1475906001340469313/cb7ff336-3108-4b37-8786-666d90afa5ca-profile_banner-480.png?ex=699f3013&is=699dde93&hm=71e0ac911cbbe52094aca7960a38b782cc07ed8e62c562e4e9395765389253c4&=&format=webp&quality=lossless&width=1066&height=600' }
      ]
    }
  },
  pool_b: {
    name: '🌸 Hololive & Nijisanji Banner',
    characters: {
      common: [
        { name: 'Elira Pendora', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938363319259428/Elira.Pendora.600.3788087.jpg?ex=699f4e37&is=699dfcb7&hm=c81b504c3259443d20f46bedf6d9ed5e113184f22e0f199404fdfc53231eaeb0&=&format=webp&width=750&height=511' },
        { name: 'Finana Ryugu', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938364942192673/Finana.Ryugu.600.3334984.jpg?ex=699f4e37&is=699dfcb7&hm=d960df4ee102925deeb25791d3da3fd0044e1312027057f17ea89167963bd617&=&format=webp&width=750&height=423' },
        { name: 'Pomu Rainpuff', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475941147322093721/PomuRainpuff.jpg?ex=699f50cf&is=699dff4f&hm=730ba603cfda4342c6acf950a90b767af3ca978a92dc1f7866358b794fd4dca0&=&format=webp&width=966&height=543' },
        { name: 'Rosemi Lovelock', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475941146986545153/rosemi_lovelock_by_29292ni_deptprc-fullview.jpg?ex=699f50cf&is=699dff4f&hm=ee3b6152abc7444e7c3ea992a90df67a56490093f4d5404f66aec5bbebd9fb50&=&format=webp&width=831&height=543' },
        { name: 'Enna Alouette', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475941146571178134/EnnaAlouette.jpg?ex=699f50cf&is=699dff4f&hm=4bed3d27f51db14bf01f5ec66a583f26c6d1d0e6569dfda5a1f8d1395c407f95&=&format=webp&width=769&height=544' },
        { name: 'Millie Parfait', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475941146097094657/Millie.Parfait.600.3549930.jpg?ex=699f50ce&is=699dff4e&hm=3cb5afffef9ec6e4265ea8997c26fdd38f5f7bd87e2531dbf6e5da32e9521513&=&format=webp' },
        { name: 'Luca Kaneshiro', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475941145530990633/HD-wallpaper-anime-virtual-youtuber-luca-kaneshiro-luxiem.jpg?ex=699f50ce&is=699dff4e&hm=3e25a60a2ad77f5976ef60c0de1e830d389bb19d8d3e33bb51a966872f843144&=&format=webp' },
        { name: 'Shu Yamino', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475941144985862278/ShuYamino.jpg?ex=699f50ce&is=699dff4e&hm=c7b115aefd38732dfeb79a082759624fb76c53a7ff8f5d417a0f43a97c5a6765&=&format=webp&width=797&height=544' }
      ],
      rare: [
        { name: 'Hoshimachi Suisei', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938363956658248/fbf9d6edb0e65fd538a931dd4047fd52.jpg?ex=699f4e37&is=699dfcb7&hm=715a15170a3b303acc00dde50d0aa477da58c64769078147d82ef4844602fdd7&=&format=webp&width=750&height=494' },
        { name: 'Shirakami Fubuki', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938366947065856/HD-wallpaper-anime-virtual-youtuber-shirakami-fubuki.jpg?ex=699f4e38&is=699dfcb8&hm=ba40afc03ebb8fd14a06c1a0bbbc999450508fa450894d00b05be785c782c2ea&=&format=webp&width=961&height=680' },
        { name: 'Kobo Kanaeru', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938367983063213/Kobo.Kanaeru.600.3723600.jpg?ex=699f4e38&is=699dfcb8&hm=df5f4bfe4dcbcc6e237f17049b07f1039ae82469570742f8c008ea1a534768e1&=&format=webp&width=750&height=498' },
        { name: 'Vox Akuma', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938362861948958/1271665.jpg?ex=699f4e37&is=699dfcb7&hm=db21815b603c551756b3bbe01f8f54bd4e634d664ee89d726ee9d9548587899d&=&format=webp&width=961&height=680' },
        { name: 'Ouro Kronii', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943955748094162/OuroKronii.jpg?ex=699f536c&is=699e01ec&hm=46ceea51f7f8d62c13db325892791982db01796ed749097b074b0df52acb41c9&=&format=webp&width=653&height=544' },
        { name: 'Nanashi Mumei', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943954946986065/NanashiMumei.jpg?ex=699f536c&is=699e01ec&hm=166a0e67edec3e20fcd17b68a0b5453eea54a1770bb255a7a4c4acf005a07e8c&=&format=webp&width=966&height=543' },
        { name: 'Hakos Baelz', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943954582212772/HakosBaelz.png?ex=699f536c&is=699e01ec&hm=9fa4ab957e9cf3094c4d15e90e111b51a2f009881ade94aadc4717c879c09f9c&=&format=webp&quality=lossless&width=966&height=543' },
        { name: 'Ike Eveland', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943954045337650/IkeEveland.jpg?ex=699f536c&is=699e01ec&hm=cdb5309d642d0f1c2d61caafd6d77d8cb48744ae197aaa43a8d2e3ded60430bf&=&format=webp' },
        { name: 'Mysta Rias', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943953533636649/MystaRias.jpg?ex=699f536c&is=699e01ec&hm=dfa34231f1f996b2264a975eb5561beb0ce89a965eb0bbbb66b1688722a3b340&=&format=webp' }
      ],
      legendary: [
        { name: 'Gawr Gura', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938365806481428/flat750x075f-pad750x1000f8f8f8.jpg?ex=699f4e38&is=699dfcb8&hm=4f5d5e7adc7ec6dc2dcffbfd8e57eba422a79bac25c0091a9cabd706b895e929&=&format=webp&width=510&height=680' },
        { name: 'Houshou Marine', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943953013412014/HoushouMarine.jpg?ex=699f536c&is=699e01ec&hm=539b5b6b941443aad2c12d0f6e227169222c03aec310828f47e75ec24a7b91cc&=&format=webp&width=769&height=544' },
        { name: 'Kuzuha', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938368582844436/Kuzuha-Nijisanji-VTuber-tops-charts.jpg?ex=699f4e38&is=699dfcb8&hm=cecf434b0e7c8b78f44a28eb87d3783bd50cb899e77c39909d4f629bae0e9c7b&=&format=webp&width=1208&height=679' },
        { name: 'Kizuna AI', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938370537652326/thumb-1920-904634.jpg?ex=699f4e39&is=699dfcb9&hm=b9e4deb40be13cac638b762b632fb813c0d78666d63b0da4290df5f2368fce5e&=&format=webp&width=869&height=680' },
        { name: 'Mori Calliope', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475938369530761318/soho-2.jpg?ex=699f4e38&is=699dfcb8&hm=3f2200456052531e049b6b7735035d711ac0ec6461723c139ed8f662aada1297&=&format=webp&width=1115&height=680' },
        { name: 'Usada Pekora', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943952321482812/UsadaPekora.jpg?ex=699f536b&is=699e01eb&hm=9349a07fcee33f1b3823999a3f82e9a2318c8c9faa216a7ffa2482e1669a89b3&=&format=webp' },
        { name: 'Inugami Korone', gif: 'https://media.discordapp.net/attachments/1475906261533851768/1475943951302393856/InugamiKorone.png?ex=699f536b&is=699e01eb&hm=cf5612517aeb458d853557320257ae6a93a19ced29562595168392ed9367e9bc&=&format=webp&quality=lossless&width=966&height=543' }
      ]
    }
  },
  pool_c: {
    name: '🌀 The Multiverse Banner',
    characters: {
      common: [
        { name: 'Pippa Pipkin', gif: 'https://s1.zerochan.net/Pipkin.Pippa.600.3496985.jpg' },
        { name: 'Tenma Maemi', gif: 'https://s1.zerochan.net/Tenma.Maemi.600.3551523.jpg' },
        { name: 'Rin Penrose', gif: 'https://s1.zerochan.net/Rin.Penrose.600.3814882.jpg' },
        { name: 'Yuko Yurei', gif: 'https://s1.zerochan.net/Yuko.Yurei.600.3855521.jpg' },
        { name: 'Poko', gif: 'https://s1.zerochan.net/Poko.%28Idol.EN%29.600.3814884.jpg' },
        { name: 'Lumi', gif: 'https://s1.zerochan.net/Lumi.%28Phase.Connect%29.600.3804818.jpg' },
        { name: 'Erina Makina', gif: 'https://s1.zerochan.net/Erina.Makina.600.3804822.jpg' },
        { name: 'Clara Alcantara', gif: 'https://s1.zerochan.net/Clara.Alcantara.600.4046554.jpg' }
      ],
      rare: [
        { name: 'Dokibird', gif: 'https://s1.zerochan.net/Dokibird.600.4124564.jpg' },
        { name: 'Mint Fantome', gif: 'https://s1.zerochan.net/Mint.Fantome.600.4146741.jpg' },
        { name: 'Uruka Fujikura', gif: 'https://s1.zerochan.net/Fujikura.Uruka.600.3340854.jpg' },
        { name: 'Shiina', gif: 'https://s1.zerochan.net/Shiina.%28Phase.Connect%29.600.3804821.jpg' },
        { name: 'Riro Ron', gif: 'https://s1.zerochan.net/Riro.Ron.600.3814883.jpg' },
        { name: 'Kureiji Ollie', gif: 'https://s1.zerochan.net/Kureiji.Ollie.600.3151854.jpg' },
        { name: 'Dizzy Aster', gif: 'https://s1.zerochan.net/Dizzy.Aster.600.3804824.jpg' }
      ],
      legendary: [
        { name: 'Neuro-sama', gif: 'https://s1.zerochan.net/Neuro-sama.600.3871254.jpg' },
        { name: 'Vedal987 (Turtle)', gif: 'https://s1.zerochan.net/Vedal987.600.4068524.jpg' },
        { name: 'Hoshikawa Sara', gif: 'https://s1.zerochan.net/Hoshikawa.Sara.600.2988126.jpg' },
        { name: 'Kanae', gif: 'https://s1.zerochan.net/Kanae.%28Nijisanji%29.600.2988124.jpg' }
      ]
    }
  }
}.freeze

# Automatically calculates the total unique characters available in the entire game
TOTAL_UNIQUE_CHARS = { 'common' => [], 'rare' => [], 'legendary' => [] }

CHARACTER_POOLS.values.each do |pool|
  TOTAL_UNIQUE_CHARS['common'].concat(pool[:characters][:common].map { |c| c[:name] })
  TOTAL_UNIQUE_CHARS['rare'].concat(pool[:characters][:rare].map { |c| c[:name] })
  TOTAL_UNIQUE_CHARS['legendary'].concat(pool[:characters][:legendary].map { |c| c[:name] })
end

# Shrink the lists down to just the final count of unique names
TOTAL_UNIQUE_CHARS.transform_values! { |arr| arr.uniq.size }

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
# COMMAND CATEGORIES
# =========================

COMMAND_CATEGORIES = {
  'Economy'   => [:balance, :daily, :work, :stream, :post, :collab, :cooldowns],
  'Gacha'     => [:summon, :collection, :banner, :shop, :buy, :view],
  'Fun'       => [:kettle, :leaderboard, :hug, :slap, :interactions, :bomb],
  'Utility'   => [:ping, :help, :about, :level, :levelup],
  'Developer' => [:addcoins, :setcoins, :setlevel, :addxp]
}.freeze

def get_cmd_category(cmd_name)
  COMMAND_CATEGORIES.each do |category, commands|
    return category if commands.include?(cmd_name)
  end
  'Uncategorized'
end

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
  # Build the embed object manually first
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

  # Send the embed as a direct reply to the message that triggered it!
  # Parameters: content, tts, embed, attachments, allowed_mentions, message_reference
  event.channel.send_message(nil, false, embed, nil, nil, event.message)
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

def get_current_banner
  # Calculates the number of weeks since the Unix Epoch (Jan 1, 1970)
  # 604800 is the exact number of seconds in one week.
  week_number = Time.now.to_i / 604_800 
  
  # Grabs the list of pool keys (e.g., [:pool_a, :pool_b])
  available_pools = CHARACTER_POOLS.keys
  
  # Use modulo math to seamlessly loop through the pools week after week!
  active_key = available_pools[week_number % available_pools.size]
  
  # Return the active pool's hash
  CHARACTER_POOLS[active_key]
end

def generate_collection_page(user_obj, collections, rarity_page)
  uid = user_obj.id
  chars = collections[uid] || {}
  
  # Filter the user's collection to just this specific rarity
  page_chars = chars.select { |_, data| data['rarity'] == rarity_page }
  
  total_collected = page_chars.size
  total_available = TOTAL_UNIQUE_CHARS[rarity_page]
  
  emoji = case rarity_page
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end
          
  desc = "You have collected **#{total_collected} / #{total_available}** unique #{rarity_page.capitalize} characters.\n\n"
  
  if page_chars.empty?
    desc += "*You haven't pulled any characters of this rarity yet!*"
  else
    # Format them cleanly into a list with their quantities
    list = page_chars.map { |name, data| "`#{name}` (x#{data['count']})" }.join(', ')
    desc += list
  end
  
  embed = Discordrb::Webhooks::Embed.new
  embed.title = "#{emoji} #{user_obj.display_name}'s Collection - #{rarity_page.capitalize}"
  embed.description = desc
  embed.color = NEON_COLORS.sample
  embed
end

def collection_view(target_uid, current_page)
  Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "coll_common_#{target_uid}", label: 'Common', style: current_page == 'common' ? :success : :secondary, emoji: '⭐', disabled: current_page == 'common')
      r.button(custom_id: "coll_rare_#{target_uid}", label: 'Rare', style: current_page == 'rare' ? :success : :secondary, emoji: '✨', disabled: current_page == 'rare')
      r.button(custom_id: "coll_legendary_#{target_uid}", label: 'Legendary', style: current_page == 'legendary' ? :success : :secondary, emoji: '🌟', disabled: current_page == 'legendary')
    end
  end
end

def generate_help_page(bot, user_obj, page_number)
  # 1. Group all commands using our new Master Dictionary! 
  grouped_commands = bot.commands.values.group_by { |cmd| get_cmd_category(cmd.name) }
  
  # 2. Define the exact order (reading top-to-bottom from your dictionary)
  category_order = COMMAND_CATEGORIES.keys + ['Uncategorized']
  
  # 3. Slice them into safe, bite-sized pages following YOUR custom order
  pages = []
  category_order.each do |category|
    # Skip the category entirely if there are no commands inside it
    next unless grouped_commands[category] 
    
    cmds = grouped_commands[category].sort_by(&:name)
    
    cmds.each_slice(10).with_index do |slice, index|
      pages << {
        category: category,
        commands: slice,
        part: index + 1,
        total_parts: (cmds.size / 10.0).ceil
      }
    end
  end

  total_pages = pages.size
  # ... (The rest of the method stays exactly the same from here down!)

  total_pages = pages.size
  total_pages = 1 if total_pages < 1
  
  page_number = 1 if page_number < 1
  page_number = total_pages if page_number > total_pages

  # 3. Grab the data for the current page
  active_page = pages[page_number - 1]
  
  # 4. Format the commands
  command_lines = active_page[:commands].map do |cmd|
    desc = cmd.attributes[:description] || 'No description provided.'
    "> `#{PREFIX}#{cmd.name}` - #{desc}"
  end

  # If there are multiple parts to a category, append "(Pt. 1)"
  cat_name = active_page[:category]
  cat_name += " (Pt. #{active_page[:part]})" if active_page[:total_parts] > 1

  # 5. Build the embed!
  embed = Discordrb::Webhooks::Embed.new
  embed.title = "🌸 Bot Help Menu - #{cat_name}"
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
      # Compare names ignoring uppercase/lowercase differences
      found = char_list.find { |c| c[:name].downcase == search_name.downcase }
      return { char: found, rarity: rarity.to_s } if found
    end
  end
  nil
end

def build_shop_home(user_id)
  embed = Discordrb::Webhooks::Embed.new
  embed.title = '🛒 The VTuber Black Market'
  embed.description = "Tired of bad gacha luck? Save up your stream revenue and buy exactly who you want!\n\n" \
                      "⭐ **Common:** #{SHOP_PRICES['common']} coins *(Sells for #{SELL_PRICES['common']})*\n" \
                      "✨ **Rare:** #{SHOP_PRICES['rare']} coins *(Sells for #{SELL_PRICES['rare']})*\n" \
                      "🌟 **Legendary:** #{SHOP_PRICES['legendary']} coins *(Sells for #{SELL_PRICES['legendary']})*\n\n" \
                      "Use `#{PREFIX}buy <Character Name>` to purchase one!"
  embed.color = NEON_COLORS.sample
  embed.image = Discordrb::Webhooks::EmbedImage.new(url: 'https://media.discordapp.net/attachments/1475889769820192861/1475906143846006794/hk4dryof6mtf1.jpeg')

  view = Discordrb::Components::View.new do |v|
    v.row do |r|
      r.button(custom_id: "shop_catalog_#{user_id}_1", label: 'View Catalog', style: :primary, emoji: '📖')
      r.button(custom_id: "shop_sell_#{user_id}", label: 'Sell Duplicates', style: :danger, emoji: '♻️')
    end
  end
  
  [embed, view]
end

def build_shop_catalog(user_id, page)
  rarities = ['common', 'rare', 'legendary']
  target_rarity = rarities[page - 1]

  # Gather all characters of this rarity from every pool
  chars = []
  CHARACTER_POOLS.values.each do |pool|
    chars.concat(pool[:characters][target_rarity.to_sym].map { |c| c[:name] })
  end
  
  # Alphabetize them and remove any accidental duplicates in the code
  chars = chars.uniq.sort

  emoji = case target_rarity
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end

  embed = Discordrb::Webhooks::Embed.new
  embed.title = "📖 Shop Catalog - #{target_rarity.capitalize}s #{emoji}"
  embed.description = "Price: **#{SHOP_PRICES[target_rarity]}** coins each.\n\n`" + chars.join("`, `") + "`"
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

bot.command(:ping, description: 'Check bot latency', category: 'Utility') do |event|
  # Calculate the time difference between when the user sent the message and right now
  time_diff = Time.now - event.message.timestamp
  
  # Convert to milliseconds and round to a clean number
  latency_ms = (time_diff * 1000).round 
  
  send_embed(
    event,
    title: '🏓 Pong!',
    description: "My connection to Discord is **#{latency_ms}ms**.\nChat is moving fast!"
  )
  
  nil
end

bot.command(:kettle, description: 'Pings a specific user with a yay emoji', category: 'Fun') do |event|
  # <@USER_ID> is the standard Discord format for pinging a user
  event.respond("<:gwolfYay:1475837867598024864> <@266358927401287680> <:gwolfYay:1475837867598024864>")
  nil
end

bot.command(:help, description: 'Shows a paginated list of all available commands', category: 'Utility') do |event|
  target_user = event.user
  
  # Generate the first page (Page 1)
  embed, total_pages, current_page = generate_help_page(event.bot, target_user, 1)
  view = help_view(target_user.id, current_page, total_pages)
  
  # Reply to the user without pinging them, and attach the buttons
  event.channel.send_message(nil, false, embed, nil, { replied_user: false }, event.message, view)
  
  nil
end

bot.command(:about, description: 'Learn more about Blossom and her creator!', category: 'Utility') do |event|
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

bot.command(:level, description: 'Show a user\'s level and XP for this server', category: 'Utility') do |event|
  unless event.server
    event.respond("❌ This command can only be used in a server!")
    next
  end

  # 1. Check for a mention, default to the command runner if nobody is pinged!
  target_user = event.message.mentions.first || event.user

  sid  = event.server.id
  uid  = target_user.id
  
  # 2. Grab the data for whoever the target is
  user = users[sid][uid]
  needed = user['level'] * 100

  # 3. Send the embed!
  send_embed(
    event,
    title: "#{target_user.display_name}'s Server Level",
    description: '',
    fields: [
      { name: 'Level', value: user['level'].to_s, inline: true },
      { name: 'XP', value: "#{user['xp']}/#{needed}", inline: true },
      { name: 'Global Coins', value: coins[uid].to_s, inline: true }
    ]
  )
  
  nil
end

bot.command(:leaderboard, description: 'Show top users by level and XP for this server', category: 'Fun') do |event|
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
      name = user_obj ? user_obj.display_name : "User #{id}"
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

bot.command(:levelup, description: 'Enable or disable level-up messages for this server (Admin only)', category: 'Utility') do |event, state|
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

bot.command(:setlevel, description: 'Set a user\'s server level (Admin Only)', min_args: 2, category: 'Developer') do |event, mention, level|
  # Make sure this is being run inside a server
  unless event.server
    event.respond("❌ This command can only be used inside a server!")
    next
  end

  # Check for Administrator permissions OR your personal DEV_ID bypass
  unless event.user.permission?(:administrator, event.channel) || event.user.id == DEV_ID
    event.respond("❌ You need Administrator permissions to use this command!")
    next
  end

  target_user = event.message.mentions.first
  new_level = level.to_i

  if target_user.nil? || new_level < 1
    event.respond("Usage: `#{PREFIX}setlevel @user <level>`")
    next
  end

  sid = event.server.id
  uid = target_user.id
  
  users[sid][uid]['level'] = new_level

  send_embed(
    event,
    title: '🛠️ Admin Override',
    description: "Successfully set #{target_user.mention}'s level to **#{new_level}**."
  )
  
  nil
end

bot.command(:addxp, description: 'Add or remove server XP from a user (Admin Only)', min_args: 2, category: 'Developer') do |event, mention, amount|
  unless event.server
    event.respond("❌ This command can only be used inside a server!")
    next
  end

  unless event.user.permission?(:administrator, event.channel) || event.user.id == DEV_ID
    event.respond("❌ You need Administrator permissions to use this command!")
    next
  end

  target_user = event.message.mentions.first
  amount = amount.to_i

  if target_user.nil?
    event.respond("Usage: `#{PREFIX}addxp @user <amount>`\n*(Tip: Use a negative number to remove XP!)*")
    next
  end

  sid = event.server.id
  uid = target_user.id
  
  users[sid][uid]['xp'] += amount
  
  # Prevent their XP from glitching into the negatives
  users[sid][uid]['xp'] = 0 if users[sid][uid]['xp'] < 0

  # Smart Level-Up Check! 
  # If you give them 5,000 XP, this loops to correctly jump them multiple levels at once.
  needed = users[sid][uid]['level'] * 100
  while users[sid][uid]['xp'] >= needed
    users[sid][uid]['xp'] -= needed
    users[sid][uid]['level'] += 1
    needed = users[sid][uid]['level'] * 100
  end

  send_embed(
    event,
    title: '🛠️ Admin Override',
    description: "Successfully added **#{amount}** XP to #{target_user.mention}.\nThey are now **Level #{users[sid][uid]['level']}** with **#{users[sid][uid]['xp']}** XP."
  )
  
  nil
end

# =========================
# ECONOMY SYSTEM
# =========================

bot.command(:balance, description: 'Show a user\'s coin balance and gacha collection stats', category: 'Economy') do |event|
  target_user = event.message.mentions.first || event.user
  uid = target_user.id

  # 1. Grab the user's collection
  user_collection = collections[uid] || {}
  
  # 2. Count exactly how many unique characters they have of each rarity
  common_count    = user_collection.values.count { |c| c['rarity'] == 'common' }
  rare_count      = user_collection.values.count { |c| c['rarity'] == 'rare' }
  legendary_count = user_collection.values.count { |c| c['rarity'] == 'legendary' }

  # 3. Package it all into clean embed fields!
  fields = [
    { name: '💰 Bank Account', value: "**#{coins[uid]}** coins", inline: false },
    { name: '⭐ Commons', value: "#{common_count} / #{TOTAL_UNIQUE_CHARS['common']}", inline: true },
    { name: '✨ Rares', value: "#{rare_count} / #{TOTAL_UNIQUE_CHARS['rare']}", inline: true },
    { name: '🌟 Legendaries', value: "#{legendary_count} / #{TOTAL_UNIQUE_CHARS['legendary']}", inline: true }
  ]

  send_embed(
    event,
    title: "#{target_user.display_name}'s Profile",
    description: "Here are #{target_user.display_name}'s current economy and gacha stats!",
    fields: fields
  )
  
  nil
end

bot.command(:daily, description: 'Claim your daily coin reward', category: 'Economy') do |event|
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

bot.command(:work, description: 'Work for some coins (5min cooldown)', category: 'Economy') do |event|
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

bot.command(:stream, description: 'Go live and earn some coins! (30m cooldown)', category: 'Economy') do |event|
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

bot.command(:post, description: 'Post on social media for some quick coins! (5m cooldown)', category: 'Economy') do |event|
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

bot.command(:collab, description: 'Ask the server to do a collab stream! (30m cooldown)', category: 'Economy') do |event|
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

  # The 6th parameter is the message_reference (what we are replying to)
  msg = event.channel.send_message(nil, false, embed, nil, nil, event.message, view)

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

bot.command(:cooldowns, description: 'Check your active timers for economy commands', category: 'Economy') do |event|
  uid = event.user.id
  cd  = economy_cooldowns[uid]

  # Helper method to calculate future ready time and format as a live Discord timestamp
  check_cd = ->(last_used, cooldown_duration) do
    if last_used && (Time.now - last_used) < cooldown_duration
      ready_time = last_used + cooldown_duration
      "Ready <t:#{ready_time.to_i}:R>"
    else
      "**Ready!**"
    end
  end

  # Package up the fields
  cd_fields = [
    { name: '!daily', value: check_cd.call(cd['daily_at'], DAILY_COOLDOWN), inline: true },
    { name: '!work', value: check_cd.call(cd['work_at'], WORK_COOLDOWN), inline: true },
    { name: '!stream', value: check_cd.call(cd['stream_at'], STREAM_COOLDOWN), inline: true },
    { name: '!post', value: check_cd.call(cd['post_at'], POST_COOLDOWN), inline: true },
    { name: '!collab', value: check_cd.call(cd['collab_at'], COLLAB_COOLDOWN), inline: true }
  ]

  # Send it straight to the channel using your updated helper!
  send_embed(
    event,
    title: "⏱️ #{event.user.display_name}'s Cooldowns",
    description: "Here are your current economy timers:",
    fields: cd_fields
  )
  
  nil
end

# =========================
# DEVELOPER TOOLS
# =========================

bot.command(:addcoins, description: 'Add or remove coins from a user (Dev Only)', min_args: 2, category: 'Developer') do |event, mention, amount|
  # Instantly reject anyone who isn't you
  unless event.user.id == DEV_ID
    event.respond("❌ Only the bot developer can use this command!")
    next
  end

  target_user = event.message.mentions.first
  amount = amount.to_i

  if target_user.nil?
    event.respond("Usage: `#{PREFIX}addcoins @user <amount>`\n*(Tip: Use a negative number to remove coins!)*")
    next
  end

  uid = target_user.id
  coins[uid] += amount

  send_embed(
    event,
    title: '🛠️ Developer Override',
    description: "Successfully added **#{amount}** coins to #{target_user.mention}.\nTheir new balance is **#{coins[uid]}**."
  )
  
  nil
end

bot.command(:setcoins, description: 'Set a user\'s balance to an exact amount (Dev Only)', min_args: 2, category: 'Developer') do |event, mention, amount|
  # Instantly reject anyone who isn't you
  unless event.user.id == DEV_ID
    event.respond("❌ Only the bot developer can use this command!")
    next
  end

  target_user = event.message.mentions.first
  amount = amount.to_i

  if target_user.nil? || amount < 0
    event.respond("Usage: `#{PREFIX}setcoins @user <amount>`")
    next
  end

  uid = target_user.id
  coins[uid] = amount # Overwrites the balance entirely

  send_embed(
    event,
    title: '🛠️ Developer Override',
    description: "#{target_user.mention}'s balance has been forcefully set to **#{coins[uid]}** coins."
  )
  
  nil
end

# =========================
# GACHA / CHARACTER SUMMONS
# =========================

bot.command(:summon, description: 'Spend coins to summon a character from the weekly banner!', category: 'Fun') do |event|
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

  # 1. Grab the active banner for this week
  active_banner = get_current_banner
  
  # 2. Roll for rarity, then pull from THIS banner's specific character list
  rarity = roll_rarity
  pulled_char = active_banner[:characters][rarity].sample
  
  name = pulled_char[:name]
  gif_url = pulled_char[:gif]
  
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
    title: "Summon Result: #{active_banner[:name]}",
    description: "#{emoji} You summoned **#{name}** (#{rarity_label})!\nYou now own **#{collections[uid][name]['count']}** of them.",
    fields: [
      { name: 'Remaining Balance', value: coins[uid].to_s, inline: true }
    ],
    image: gif_url
  )
  nil
end

bot.command(:collection, description: 'View your vtuber collection', category: 'Fun') do |event|
  target_user = event.user
  
  # Generate the first page (Commons)
  embed = generate_collection_page(target_user, collections, 'common')
  view  = collection_view(target_user.id, 'common')
  
  # Reply to the user without pinging them
  event.channel.send_message(nil, false, embed, nil, { replied_user: false }, event.message, view)
  
  nil
end

bot.command(:banner, description: 'Check which characters are in the gacha pool this week!', category: 'Gacha') do |event|
  active_banner = get_current_banner
  chars = active_banner[:characters]

  # --- MATH FOR THE NEXT BANNER ---
  # 1 week = 604,800 seconds
  week_number = Time.now.to_i / 604_800 
  available_pools = CHARACTER_POOLS.keys
  
  # Peek at the next key in the loop
  next_key = available_pools[(week_number + 1) % available_pools.size]
  next_banner = CHARACTER_POOLS[next_key]
  
  # Calculate the exact Unix timestamp for the start of the next week
  next_rotation_time = (week_number + 1) * 604_800
  # --------------------------------

  fields = [
    {
      name: '🌟 Legendaries (5%)',
      value: chars[:legendary].map { |c| c[:name] }.join(', '),
      inline: false
    },
    {
      name: '✨ Rares (25%)',
      value: chars[:rare].map { |c| c[:name] }.join(', '),
      inline: false
    },
    {
      name: '⭐ Commons (70%)',
      value: chars[:common].map { |c| c[:name] }.join(', '),
      inline: false
    }
  ]

  # Format the description with Discord's live countdown timestamp
  desc = "Here are the VTubers you can pull this week!\n\n"
  desc += "**Next Rotation:** <t:#{next_rotation_time}:R>\n"
  desc += "**Up Next:** #{next_banner[:name]}"

  send_embed(
    event,
    title: "Current Gacha: #{active_banner[:name]}",
    description: desc,
    fields: fields
  )
  nil
end

# Listener for the collection pagination buttons
bot.button(custom_id: /^coll_(common|rare|legendary)_(\d+)$/) do |event|
  # Explicitly match the custom_id string to grab the data safely
  match_data = event.custom_id.match(/^coll_(common|rare|legendary)_(\d+)$/)
  requested_page = match_data[1]
  target_uid     = match_data[2].to_i
  
  # Ensure only the owner of the collection can flip the pages!
  if event.user.id != target_uid
    event.respond(content: "You can only flip the pages of your own collection! Use `!collection` to view yours.", ephemeral: true)
    next
  end

  target_user = event.user
  
  # Generate the new page and update the buttons
  new_embed = generate_collection_page(target_user, collections, requested_page)
  new_view  = collection_view(target_uid, requested_page)
  
  # Seamlessly edit the message
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

# Listener for the help menu pagination buttons
bot.button(custom_id: /^helpnav_(\d+)_(\d+)$/) do |event|
  # Extract the requested target page and the ID of the user whose help menu this is
  match_data = event.custom_id.match(/^helpnav_(\d+)_(\d+)$/)
  target_uid  = match_data[1].to_i
  target_page = match_data[2].to_i
  
  # Ensure only the owner can flip the pages!
  if event.user.id != target_uid
    event.respond(content: "You can only flip the pages of your own help menu! Use `!help` to open yours.", ephemeral: true)
    next
  end

  # Generate the new page and update the buttons
  new_embed, total_pages, current_page = generate_help_page(event.bot, event.user, target_page)
  new_view = help_view(target_uid, current_page, total_pages)
  
  # Seamlessly edit the message
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

bot.command(:shop, description: 'View the character shop and direct-buy prices!', category: 'Gacha') do |event|
  embed, view = build_shop_home(event.user.id)
  
  # Send the message with the interactive buttons attached
  event.channel.send_message(nil, false, embed, nil, { replied_user: false }, event.message, view)
  
  nil
end

bot.command(:buy, description: 'Directly buy a character (Usage: !buy Character Name)', min_args: 1, category: 'Gacha') do |event, *name_args|
  uid = event.user.id
  
  # Recombine the arguments in case the character name has spaces (e.g. "Gawr Gura")
  search_name = name_args.join(' ')

  # 1. Search for the character
  result = find_character_in_pools(search_name)
  
  unless result
    send_embed(
      event,
      title: '🛒 Shop Error',
      description: "I couldn't find a character named **#{search_name}** in the database. Check your spelling!"
    )
    next
  end

  # 2. Extract character info and check the price
  char_data = result[:char]
  rarity    = result[:rarity]
  price     = SHOP_PRICES[rarity]

  if coins[uid] < price
    send_embed(
      event,
      title: '🛒 Insufficient Funds',
      description: "You need **#{price}** coins to buy a #{rarity.capitalize} character.\nYou currently have **#{coins[uid]}**."
    )
    next
  end

  # 3. Process the transaction!
  coins[uid] -= price
  
  name = char_data[:name]
  gif_url = char_data[:gif]

  collections[uid][name] ||= { 'rarity' => rarity, 'count' => 0 }
  collections[uid][name]['count'] += 1

  emoji = case rarity
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end

  send_embed(
    event,
    title: '🛒 Purchase Successful!',
    description: "#{emoji} You directly purchased **#{name}** for **#{price}** coins!\nYou now own **#{collections[uid][name]['count']}** of them.",
    fields: [
      { name: 'Remaining Balance', value: coins[uid].to_s, inline: true }
    ],
    image: gif_url
  )
  
  nil
end

bot.command(:view, description: 'Look at a specific character you own', min_args: 1, category: 'Gacha') do |event, *name_args|
  uid = event.user.id
  search_name = name_args.join(' ')
  
  user_chars = collections[uid] || {}
  
  # Find the exact character name in their collection, ignoring uppercase/lowercase
  owned_name = user_chars.keys.find { |k| k.downcase == search_name.downcase }
  
  # 1. Check if they actually own it
  unless owned_name && user_chars[owned_name]['count'] > 0
    send_embed(
      event,
      title: '🔍 Character Not Found',
      description: "You don't own **#{search_name}** yet!\nUse `#{PREFIX}summon` to roll for them, or `#{PREFIX}buy` to get them from the shop."
    )
    next
  end
  
  # 2. Grab the GIF and data from the global pool using our helper
  result = find_character_in_pools(owned_name)
  
  char_data = result[:char]
  rarity    = result[:rarity]
  count     = user_chars[owned_name]['count']
  
  emoji = case rarity
          when 'legendary' then '🌟'
          when 'rare'      then '✨'
          else '⭐'
          end
          
  # 3. Display the character!
  send_embed(
    event,
    title: "#{emoji} #{owned_name} (#{rarity.capitalize})",
    description: "You currently own **#{count}** copies of this character.",
    image: char_data[:gif]
  )
  
  nil
end

# =========================
# INTERACTIVE COMMANDS
# =========================

bot.command(:hug, description: 'Send a hug with a random GIF', category: 'Fun') do |event|
  interaction_embed(event, 'hug', HUG_GIFS, interactions)
  nil
end

bot.command(:slap, description: 'Send a playful slap with a random GIF', category: 'Fun') do |event|
  interaction_embed(event, 'slap', SLAP_GIFS, interactions)
  nil
end

bot.command(:interactions, description: 'Show your hug/slap stats', category: 'Fun') do |event|
  data = interactions[event.user.id]

  hug  = data['hug']
  slap = data['slap']

  send_embed(
    event,
    title: "#{event.user.display_name}'s Interaction Stats",
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

bot.command(:bomb, description: 'Plant a bomb that explodes in 5 minutes (Admin only)', category: 'Fun') do |event|
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

  # The 6th parameter is the message_reference (what we are replying to)
  msg = event.channel.send_message(nil, false, embed, nil, nil, event.message, view)

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
# SHOP MENU LISTENERS
# =========================

# 1. Flip through Catalog Pages
bot.button(custom_id: /^shop_catalog_(\d+)_(\d+)$/) do |event|
  match_data = event.custom_id.match(/^shop_catalog_(\d+)_(\d+)$/)
  uid  = match_data[1].to_i
  page = match_data[2].to_i
  
  if event.user.id != uid
    event.respond(content: "You cannot use someone else's shop menu! Type `!shop` to open your own.", ephemeral: true)
    next
  end

  new_embed, new_view = build_shop_catalog(uid, page)
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

# 2. Return to Shop Home
bot.button(custom_id: /^shop_home_(\d+)$/) do |event|
  uid = event.custom_id.match(/^shop_home_(\d+)$/)[1].to_i
  
  if event.user.id != uid
    event.respond(content: "You cannot use someone else's shop menu!", ephemeral: true)
    next
  end

  new_embed, new_view = build_shop_home(uid)
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

# 3. Sell Duplicates Button
bot.button(custom_id: /^shop_sell_(\d+)$/) do |event|
  uid = event.custom_id.match(/^shop_sell_(\d+)$/)[1].to_i
  
  if event.user.id != uid
    event.respond(content: "You cannot sell someone else's characters!", ephemeral: true)
    next
  end

  user_collection = collections[uid] || {}
  total_earned = 0
  dupes_sold = 0

  # Search inventory for anything greater than 1 copy
  user_collection.each do |name, data|
    if data['count'] > 1
      sell_amount = data['count'] - 1
      rarity = data['rarity']
      coins_earned = sell_amount * SELL_PRICES[rarity]
      
      total_earned += coins_earned
      dupes_sold += sell_amount
      data['count'] = 1 # Drops them safely back to 1 copy!
    end
  end

  embed = Discordrb::Webhooks::Embed.new
  view = Discordrb::Components::View.new do |v|
    v.row { |r| r.button(custom_id: "shop_home_#{uid}", label: 'Back to Shop', style: :secondary, emoji: '🔙') }
  end

  if dupes_sold > 0
    coins[uid] += total_earned
    embed.title = '♻️ Duplicates Sold!'
    embed.description = "You converted **#{dupes_sold}** duplicate characters into **#{total_earned}** coins!\n\nNew Balance: **#{coins[uid]}** coins."
    embed.color = 0x00FF00 # Green
  else
    embed.title = '♻️ No Duplicates'
    embed.description = "You don't have any duplicate characters to sell right now! You currently have 1 or 0 copies of everyone."
    embed.color = 0xFF0000 # Red
  end

  # Update the shop menu into a Receipt!
  event.update_message(content: nil, embeds: [embed], components: view)
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