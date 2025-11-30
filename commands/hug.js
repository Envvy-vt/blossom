const { EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle } = require("discord.js");
const fs = require("fs");

module.exports = {
    name: "hug",
    description: "Send someone a hug!",
    async execute(message) {

        const hugger = message.author;
        const user = message.mentions.users.first();

        if (!user) return message.reply("Please mention someone to hug 💗");
        if (user.id === hugger.id) return message.reply("You can’t hug yourself 💞");

        // Load hug data
        let hugData = {};
        if (fs.existsSync("./hugData.json")) {
            hugData = JSON.parse(fs.readFileSync("./hugData.json"));
        }

        if (!hugData[hugger.id]) hugData[hugger.id] = 0;
        hugData[hugger.id] += 1;
        fs.writeFileSync("./hugData.json", JSON.stringify(hugData, null, 2));

        const embed = new EmbedBuilder()
            .setColor("#ffc1cc")
            .setTitle("🤗 A Hug Appears!")
            .setDescription(`**${hugger}** gave **${user}** a warm hug!`)
            .addFields({
                name: "💗 Total Hugs Given",
                value: `${hugData[hugger.id]}`,
                inline: true
            })
            .setTimestamp();

        const row = new ActionRowBuilder().addComponents(
            new ButtonBuilder()
                .setCustomId(`hugback_${hugger.id}_${user.id}_${message.id}`)
                .setLabel("Hug Back 💞")
                .setStyle(ButtonStyle.Secondary)
        );

        await message.reply({ embeds: [embed], components: [row] });
    }
};
