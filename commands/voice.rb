bot.command(:call, description: 'Summon Blossom to your voice channel', category: 'Utility') do |event|
  channel = event.user.voice_channel
  
  if channel.nil?
    event.respond "❌ You aren't in a voice channel! Please join one and try again."
    next
  end

  begin
    bot.voice_connect(channel)
    event.respond "🔊 **Connected to #{channel.name}!** I'm ready to listen (or play audio later)."
  rescue => e
    event.respond "❌ Voice Connection Failed: #{e.message}"
    puts "[VOICE ERROR] #{e.backtrace.first}: #{e.message}"
  end
end

bot.command(:dismiss, description: 'Make Blossom leave the voice channel', category: 'Utility') do |event|
  bot.voice_destroy(event.server.id)
  event.respond "👋 Disconnected from voice."
end