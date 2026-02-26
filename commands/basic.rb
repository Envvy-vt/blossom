# =========================
# BASIC COMMANDS
# =========================

bot.command(:ping, description: 'Check bot latency', category: 'Utility') do |event|
  time_diff = Time.now - event.message.timestamp
  latency_ms = (time_diff * 1000).round 
  
  send_embed(
    event,
    title: "#{EMOJIS['play']} Pong!",
    description: "My connection to Discord is **#{latency_ms}ms**.\nChat is moving fast!"
  )
  nil
end

bot.command(:kettle, description: 'Pings a specific user with a yay emoji', category: 'Fun') do |event|
  event.respond("#{EMOJIS['sparkle']} <@266358927401287680> #{EMOJIS['sparkle']}")
  nil
end

bot.command(:help, description: 'Shows a paginated list of all available commands', category: 'Utility') do |event|
  target_user = event.user
  embed, total_pages, current_page = generate_help_page(event.bot, target_user, 1)
  view = help_view(target_user.id, current_page, total_pages)
  
  event.channel.send_message(nil, false, embed, nil, { replied_user: false }, event.message, view)
  nil
end

# Listener for the help menu pagination buttons
bot.button(custom_id: /^helpnav_(\d+)_(\d+)$/) do |event|
  match_data = event.custom_id.match(/^helpnav_(\d+)_(\d+)$/)
  target_uid  = match_data[1].to_i
  target_page = match_data[2].to_i
  
  if event.user.id != target_uid
    event.respond(content: "You can only flip the pages of your own help menu! Use `!help` to open yours.", ephemeral: true)
    next
  end

  new_embed, total_pages, current_page = generate_help_page(event.bot, event.user, target_page)
  new_view = help_view(target_uid, current_page, total_pages)
  
  event.update_message(content: nil, embeds: [new_embed], components: new_view)
end

bot.command(:about, description: 'Learn more about Blossom and her creator!', category: 'Utility') do |event|
  fields = [
    {
      name: "#{EMOJIS['play']} The Content Grind",
      value: "We are on that monetization grind! I manage the server's economy so you can earn #{EMOJIS['s_coin']} by hitting that `!stream` button, getting engagement with a quick `!post` on socials, or doing a `!collab` with other chatters.",
      inline: false
    },
    {
      name: "#{EMOJIS['sparkle']} VTuber Gacha",
      value: "Spend your hard-earned stream revenue to `!summon` your favorite VTubers! Will you pull common indie darlings, or hit the legendary RNG for Gura, Calli, or Ironmouse? Build your `!collection` and flex your pulls!",
      inline: false
    },
    {
      name: "#{EMOJIS['like']} Just Chatting & Vibes",
      value: "Lurkers don't get XP here! I track your chat activity and reward you with levels the more you type. Plus, you can `!hug` your friends or `!slap` a troll.",
      inline: false
    },
    {
      name: "#{EMOJIS['bomb']} A Little Bit of Trolling",
      value: "Sometimes chat gets too cozy, so the admins let me drop a literal `!bomb` in the channel. You have to scramble to defuse it for a massive coin payout, or the whole chat goes BOOM!",
      inline: false
    },
    {
      name: "#{EMOJIS['developer']} Behind the Scenes",
      value: "Made by **Envvy.VT** and coded in **.rb** (Ruby).",
      inline: false
    }
  ]

  send_embed(
    event,
    title: "#{EMOJIS['heart']} About Blossom",
    description: "Hey Chat! I'm **Blossom**, your server's dedicated head mod, hype-woman, and resident gacha addict. I'm here to turn your Discord server into the ultimate content creator community.\n\nDrop a `!help` in chat and let's go live! #{EMOJIS['stream']}#{EMOJIS['neonsparkle']}",
    fields: fields
  )
  nil
end

bot.command(:hug, description: 'Send a hug with a random GIF', category: 'Fun') do |event|
  interaction_embed(event, 'hug', HUG_GIFS)
  nil
end

bot.command(:slap, description: 'Send a playful slap with a random GIF', category: 'Fun') do |event|
  interaction_embed(event, 'slap', SLAP_GIFS)
  nil
end

bot.command(:interactions, description: 'Show your hug/slap stats', category: 'Fun') do |event|
  data = DB.get_interactions(event.user.id)

  hug  = data['hug']
  slap = data['slap']

  send_embed(
    event,
    title: "#{event.user.display_name}'s Interaction Stats",
    description: '',
    fields: [
      {
        name: "#{EMOJIS['hearts']} Hugs",
        value: "Sent: **#{hug['sent']}**\nReceived: **#{hug['received']}**",
        inline: true
      },
      {
        name: "#{EMOJIS['bonk']} Slaps",
        value: "Sent: **#{slap['sent']}**\nReceived: **#{slap['received']}**",
        inline: true
      }
    ]
  )
  nil
end