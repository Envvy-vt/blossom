import { Client, GatewayIntentBits, Collection } from "discord.js";
import dotenv from "dotenv";
import fs from "fs";
import path from "path";


dotenv.config();

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ]
});

client.once("clientReady", () => {
  console.log(`Logged in as ${client.user.tag}!`);
});

client.on("messageCreate", (message) => {
  if (message.content === "!blossom") {
    message.reply("Nyaa~! Blossom is here! 🌸💗");
  }
});

// Command collection
client.commands = new Collection();

// Load commands
const commandsPath = path.join(process.cwd(), "commands");
for (const file of fs.readdirSync(commandsPath)) {
  if (file.endsWith(".js")) {
    const command = await import(`./commands/${file}`);
    client.commands.set(command.default.name, command.default);
  }
}

// Load events
const eventsPath = path.join(process.cwd(), "events");
for (const file of fs.readdirSync(eventsPath)) {
  if (file.endsWith(".js")) {
    const event = await import(`./events/${file}`);

    if (event.default.once) {
      client.once(event.default.name, (...args) => event.default.execute(...args, client));
    } else {
      client.on(event.default.name, (...args) => event.default.execute(...args, client));
  }
}

client.login(process.env.TOKEN);
}
