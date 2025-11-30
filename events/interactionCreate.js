const { EmbedBuilder, InteractionType, ComponentType } = require("discord.js");
const fs = require("fs");

module.exports = {
    name: "interactionCreate",

    async execute(interaction, client) {
        console.log("Interaction received:", interaction.type); {

        // Make sure it's a button
        if (interaction.type !== InteractionType.MessageComponent) return;
        if (interaction.componentType !== ComponentType.Button) return;

        try {
            if (interaction.customId.startsWith("hugback_")) {

                const [, originalHugger, originalReceiver] = interaction.customId.split("_");

                if (interaction.user.id !== originalReceiver) {
                    return interaction.reply({
                        content: "Only the hugged person can hug back 💞",
                        ephemeral: true
                    });
                }

                let hugData = {};
                if (fs.existsSync("./hugData.json")) {
                    hugData = JSON.parse(fs.readFileSync("./hugData.json"));
                }

                if (!hugData[interaction.user.id]) hugData[interaction.user.id] = 0;
                hugData[interaction.user.id] += 1;

                fs.writeFileSync("./hugData.json", JSON.stringify(hugData, null, 2));

                const embed = new EmbedBuilder()
                    .setColor("#ffc1cc")
                    .setTitle("💞 Hug Returned!")
                    .setDescription(`**${interaction.user}** hugged <@${originalHugger}> back!`)
                    .addFields({
                        name: "💗 Your Total Hugs Given",
                        value: `${hugData[interaction.user.id]}`,
                        inline: true
                    })
                    .setTimestamp();

                await interaction.reply({ embeds: [embed] });
            }

        } catch (err) {
            console.error("Hug Button Error:", err);

            if (!interaction.replied) {
                interaction.reply({
                    content: "Something went wrong 💔",
                    ephemeral: true
                });
            }
        }
    }
}}
