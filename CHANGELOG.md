# Changelog

All notable changes to Blossom Bot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added

- **Smart global slash sync:** On ready, Blossom GETs Discord’s global commands and bulk-overwrites **only when** the normalized schema differs from `slash_definitions.rb` (or always when `BLOSSOM_SLASH_SYNC=force`). Regenerate payloads with **`ruby components/_gen_slash_definitions.rb`** after editing the **`slash_registry.rb`** `=begin` block.
- **`/profile shop` / `b!profile shop`:** Premium users get a single CV2 panel listing shop pet Prisma prices (and pointers to title/theme/badge commands).
- **Instant ban on forbidden home channel:** Messages in `FORBIDDEN_INSTANT_BAN_CHANNEL_ID` are deleted and the author is banned; bots and `DEV_IDS` are exempt from the ban (see `events/passive/0_forbidden_channel_instant_ban.rb`).

### Documentation

- **Premium perks & Ko-fi ops:** Expanded **`COMMANDS.md`** perks table (arcade, scratch Double or Nothing, chat XP, trivia, boss, heist, birthdays, leaderboard flair, etc.). Documented explicit **Path A** (Discord roles via Ko‑fi rewards) vs **Path B** (`POST /webhooks/kofi`): Path B verifies/dedupes and runs **`grant_premium_roles_after_kofi`** (**`PREMIUM_SERVERS`**) when payloads include a Discord snowflake — **automatic role removal when membership ends** remains primarily **[Ko‑fi Discord rewards](https://help.ko-fi.com/hc/en-us/articles/360020363857-Setting-up-Discord-rewards-with-Ko-fi)** (Ko‑fi does not webhook cancel today). **`README.md`** lays out reverse-proxy **URL → `127.0.0.1:<port>`**, shared **`TOPGG_WEBHOOK_*`** bind/port, and env (**`KOFI_VERIFICATION_TOKEN`**, **`KOFI_MEMBERSHIP_WEBHOOK_TYPES`**, **`KOFI_PAGE_URL`**) plus **`https://ko-fi.com/manage/webhooks`**.
- **Pity wording (historical):** Corrected **`[v1.0.0]`** Premium / gacha changelog lines to match code—pity counts pulls **below** Legendary/Goddess (Rare counts toward the counter).

### Fixed

- **`/remindme` daily ping timing:** Reminder eligibility no longer uses PostgreSQL `NOW() - INTERVAL '24 hours'` on timezone-less `daily_at` timestamps (which could drift from `/daily`’s Ruby cooldown). Shared helpers **`daily_cooldown_ready?`** / **`daily_cooldown_remaining`** now gate remindme, autoclaim, and `/daily` with the same rolling **`DAILY_COOLDOWN`** math; users who never claimed but enabled remindme are pinged when eligible.
- **`/invest` / portfolio reads / withdraw:** `get_investment` no longer calls `Time.parse` on a value the `pg` gem already decodes as `Time` (which raised and broke invest flows). Investing now uses a single DB transaction (check open position, atomic coin deduction, insert) so races cannot spend coins without creating the row. **`withdraw_investment_atomic`** does SELECT … FOR UPDATE, payout math (aligned with `calculate_investment_value`), DELETE, and coin credit in one transaction so deletes and payouts cannot diverge. **`BlossomCache`** adds `sweep_expired!`, invoked from the weekly-challenge background loop, so expired TTL entries are pruned instead of sitting in `@store` until that key is read again.
- **Profile Prisma cosmetics:** Shop pets, titles, themes, and purchasable badges now debit Prisma with a single **`UPDATE … WHERE balance >= cost`** (`deduct_prisma!`) so a failed payment cannot still apply the cosmetic; negative `add_prisma` no longer creates a bad first row for users without a **`user_prisma`** record. **Custom banner** uses the same atomic debit. Prefix **`b!profile`** normalizes empty first args to **view**; **`b!profile shop`** (and **`/profile shop`**) lists shop pet prices and commands. Slash handlers read options with string or symbol keys.
- **Heist console noise:** The hourly heist loop and result runner no longer **`puts`** routine heist diagnostics to the terminal.
- **`b!say` multiline:** The command no longer flattens your announcement into one line — it parses the raw message after `#channel` so **newlines and paragraph spacing** survive into the embed. PostgreSQL **`NOTICE`** lines from idempotent DDL (`CREATE … IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`) are suppressed per pooled connection via **`client_min_messages = WARNING`**. **`purge_user_data`** deletes Ko-fi rows with **`discord_user_id`** (not **`user_id`**), uses **`SAVEPOINT`** per table so one failure no longer aborts the whole transaction, and no longer prints **`[PURGE]`** skip / failure lines on every boot.
- **`b!dserver` DM list includes guild snowflakes** next to each name (sorted A→Z, still chunked for Discord limits).
- **Hourly heist announcements:** unknown/missing channels no longer spam multi-line stack traces — discordrb’s duplicate **Unknown Channel** log line is filtered like **Unknown Member**; the loop **clears** a dead `heist_channel` from `server_configs` so you can run **`heist setup`** again in a valid channel. Misconfigured channels stay registered until an admin fixes overrides or picks a new channel (**NoPermission** no longer emits loop `puts`; config stays in place).
- **`b!dcommxp` no longer silently reverts.** The passive community-pool handler ran on the same message as the command, read stale totals, and could write `old_xp + chat_gain` after the dev update — mirroring the old `b!setxp` race. Prefix command messages are now skipped by the community leveling event (and blacklisted users no longer contribute pool XP), consistent with per-user leveling.
- **Global Communities leaderboard names after guild renames:** Not a Discord API delay — the tab read cached `server_name` from the database, which only refreshed on boot, community XP writes, or `dcommxp`. The embed now prefers the live guild name from Blossom’s cache when she’s in that server, and **`GUILD_UPDATE`** syncs the stored name so the DB stays current too.
- **Leaderboards (all three tabs):** Embeds use plain titles (no 👥💰 globe icons on the board). Dropdown options have no decorative emojis. Only **1st–3rd** place rows use 🏆 🥈 🥉; ranks 4+ have no rank-side medal. **Bold highlighting:** Global Communities bolds only the server you’re in when it appears; Server Members (XP) and Global Richest bold only **your** username when you’re on that list (fixes markdown noise from double-wrapping every name).
- **Monthly daily-calendar milestone payouts are atomic.** 14-/28‑claim milestone coin bonuses (premium happy-hour/stacked payouts via `calculate_coin_payout`) and the 28‑day Prisma drop for subscribers are folded into the same `commit_daily_claim_atomic` transaction as the base daily grant for both `b!daily` and premium auto-claim, instead of a second `award_coins` / `add_prisma` pass that could fail or race after the main claim was already written.
- **Fewer economy half-states across daily, transfers, shop, and ascension.** Interactive `daily`, premium auto-claim, `givecoins` peer transfers, `/buy` (black-market stacks, Goddess Prisma pulls, coin character purchases), and `/ascend` now persist related coin/prisma/inventory/collection updates in coordinated transactions (or paired helpers) instead of separate `add_coins` / `add_prisma` / row writes that could leave inconsistent balances if the process crashed mid-flight or two actions raced.
- **"Unknown Member" log spam silenced.** discordrb's API layer logs Discord error responses via `Discordrb::LOGGER.error(e.full_message)` *before* raising the exception, so callers like `is_premium?` (which already `rescue` the resulting `UnknownMember`) couldn't suppress the noise — every stale-member fetch across 1000+ users / 13+ servers still printed `[ERROR : et-NN @ ...] Unknown Member` to stdout. New helper `helpers/log_filter.rb` monkey-patches `Discordrb::Logger#error` to drop log lines matching any pattern in `SUPPRESSED_LOG_PATTERNS` (e.g. **`Unknown Member`**, **`Unknown Channel`**); the underlying exception still raises and is still caught by existing rescues. Add more substrings/regexes to that list if other low-signal Discord errors start spamming the console.
- `**b!setxp` no longer silently reverts.** The passive chat-XP handler used to fire on the command message itself, race the admin write, and overwrite it with `old_xp + chat_gain`. Command messages (anything starting with `PREFIX`) are now skipped by the leveling event entirely.
- **Trivia buttons no longer report "expired" on every click — for real this time, structurally.** The previous fix migrated session state from an in-memory hash to a `trivia_sessions` table, but click resolution still depended on that DB row being present and visible. Any race, transaction-visibility hiccup, missing migration, or stale code path would make `DB.get_trivia_session` return `nil` and the user would see "expired" the instant they clicked. The handler is now **DB-independent for the answer decision**: every piece of state needed to resolve a click — the user id, this option's label, the correct label, the reward, and the asked-at epoch — is baked into the button `custom_id` itself (format `tv2_<uid>_<label>_<correct>_<reward>_<epoch>`). The DB row is consulted purely to decorate the result message with the full correct-answer text; if it's missing, the message degrades gracefully to `(answer hidden)` instead of falsely claiming the trivia expired. The only remaining trigger for an "expired" message is the asked-epoch in the custom_id actually being older than `TRIVIA_TIME_LIMIT` seconds.
- **Trivia DB layer hardened against silent failures and timezone weirdness.** `get_trivia_session` reads `asked_at` as an epoch (`EXTRACT(EPOCH FROM asked_at)::bigint`) and rebuilds it with `Time.at`, eliminating any naive-timestamp / local-vs-UTC drift. All trivia DB methods explicitly cast `uid.to_i`, log exceptions with `[TRIVIA DB ERROR]` instead of swallowing them, and `save_trivia_session` returns true/false so callers can verify the row landed. (Diagnostic per-call logs that were added during the previous round of debugging have been removed now that the click handler no longer depends on the DB for correctness.)
- **Blacklisted users can no longer bypass the block via slash commands or button clicks.** discordrb's `ignore_user` only filters message events; slash commands, buttons, selects, and modals slipped past it. A new interaction guard checks the bot's ignore set and short-circuits with an ephemeral notice in Blossom's voice.
- **Blacklisting a user now wipes their entire footprint from the database.** Previously, a blacklisted user kept all their coins, prisma, collection, achievements, badges, materials, challenges, daily calendar, investments, social interaction counters, premium status, custom banners, trivia state, lottery entries, boss participation, crew memberships, giveaway entries, per-server XP, marriages, friendships, gift logs, and rep cooldowns — they just couldn't access any of it. Now `b!blacklist` runs a single-transaction purge across every per-user table after adding the user to the list, and the response embed shows how many rows were wiped. Removing someone from the blacklist (forgiving them) does NOT restore their data — once it's gone, it's gone.
- **Blacklisted user data is re-purged on every bot boot.** The `$bot.ready` blacklist application loop now also calls `DB.purge_user_data(uid)` for every blacklisted user, in addition to applying the in-memory ignore. This is a self-healing safety net: if anything ever leaks data back in for someone on the list (a bug, a manual SQL insert, a partial transaction), the next restart will wipe it again. The boot log prints a one-line summary of how many users were re-applied and how many stale rows were cleaned.
- **Blacklisted users no longer earn XP, levels, chat coins, or activity streaks.** The passive `$bot.message` leveling handler now bails out immediately if `event.bot.ignored?(uid)` is true. discordrb's gateway-level filter already drops most messages from ignored users, but this explicit check protects against the narrow window where a user is freshly blacklisted in the DB but the in-memory ignore set hasn't synced yet.
- **Leaderboard select-menu navigation no longer crashes on transient interaction state errors.** The handler at `events/interactions/leaderboard_menu.rb` was raising unhandled `Interaction has already been acknowledged` (Discord 40060) exceptions when `defer_update` happened to lose the race against another ack — most commonly from a double-delivered interaction, a momentarily double-running bot process, or a rapid double-click. Every Discord API call in the handler is now wrapped in a defensive rescue that logs and continues. `edit_response` still works in those cases because it goes through the webhook channel, so the user-facing behavior is unchanged on success and degrades to a logged warning instead of a raised exception on the rare failure.
- **Stale servers no longer linger on the global leaderboard or in the per-server XP table.** On every boot, after the existing server-name sync, Blossom now diffs her connected-server list against the DB and prunes any `community_levels` and `server_xp` rows for guilds she's no longer in. Includes a hard safety guard: if the connected-server cache is empty (e.g., a flaky gateway handshake), the prune is skipped entirely so a transient blip can't wipe the database. Counts of pruned rows are logged.
- **Lottery inserts are actually transactional.** `enter_lottery` used `@db.exec("BEGIN")` / separate `exec_params` / `COMMIT` on the connection pool wrapper, which can run each statement on a different pooled connection — so the BEGIN never wrapped the INSERTs. It now runs all ticket inserts inside `PGPoolWrapper#transaction` (single checked-out connection). `get_lottery_stats` no longer pulls the full lottery table into Ruby; it uses one SQL statement with aggregate subqueries.
- **Economy-facing coin deductions are concurrency-safe.** New `DatabaseEconomy#deduct_coins_if_possible`; boot migration clamps stray negative balances then adds `global_users_coins_non_negative` CHECK. Arcade (`coinflip`, `cups`, `dice`, `roulette`, `scratch`, `slots`), blackjack (per-user Mutex + atomic deduct on start/double-down), carnival ring toss/balloon pop, Double-or-Nothing loss stash, crafting (deduct coins before removing materials), `/summon` pull cost, and `/lottery` ticket purchase (`purchase_lottery_tickets` — deduction + INSERTs in one transaction) use the new path instead of SELECT-then-UPDATE gaps.

### Changed

- **Family flavor text:** **`mom_remark`** still fires **only** for **`DEV_ID`** (primary creator). Command responses now use **`family_remark`**, which adds **Uncle Z / Zin** lines (`DEV_IDS[1]`) and **Berry** (`BERRY_MOM_ID`, other mom) while keeping mama as #1 in Blossom’s bit. **`DEV_IDS`** now includes Z’s snowflake as second dev.

- **Slash command sync:** On ready, **`BlossomSlashSync`** GETs Discord’s global commands, compares a normalized fingerprint to **`BlossomSlashDefinitions`** (from `components/slash_definitions.rb`), and calls **bulk overwrite** only when they differ. **`BLOSSOM_SLASH_SYNC`**: `auto` (default), `never` (no HTTP), `force` (always PUT). Edit the `=begin` block in **`components/slash_registry.rb`**, then run **`ruby components/_gen_slash_definitions.rb`** to refresh the generated payloads. Duplicate **`/leaderboard`** and **`/vote`** registration remains removed from **`events/passive/ready.rb`**.
- **`/support` / `b!support`:** Invite updated to **https://discord.gg/cZ8zAT42u4** (Sakura Shrine).

### Added

- **`b!say #channel <text>`** (Administrator or Developer ID): posts an embed whose body is the message into another channel **in the same server**; prefix-only, 4096-char cap. **`b!drules #channel`** (Developer ID): posts Blossom's default server-rules embed (incl. staff ping etiquette).

- **Premium expansion pack:** `/vipcrate` (monthly coins + Prisma), `/eventvip` (daily event currency during seasonal months), **Subscriber Streak Guard** (weekly streak save when `/autoclaim` is on), **weekly summon stipend** (3× −40 coins) + automatic **+5 pity** once per ISO week, **×1.12** carnival ticket wins for subscribers, **+8%** crew XP from coin→crew conversion for Premium, **+12** server **community XP** on Premium boss hits, **favorite slots 4–5** with **`/collection` showcase** row, **`profile epithet`** / **`profile tagline`**, **monthly rotating pet** (half off Prisma for subs), DB table **`premium_extras`**, and related columns on **`global_users`**.

- **Neon Arcade hub account-age gate:** On the home guild (**`1499998845873033316`**), **`member_join`** kicks non-bot members whose Discord account is younger than **14 days** (`events/passive/member_logging.rb`). Documented under **`/verifysetup`** in **`COMMANDS.md`**.

- **Developer command `b!dleave <server_id>`** (prefix-only): Blossom leaves the specified guild by snowflake. Developer ID only; documented in **`COMMANDS.md`** and **`b!devhelp`**.
- **Owner hub join/leave log:** `events/passive/hub_guild_logger.rb` posts Components V2 (section + icon thumbnail) to hub channel **1500339783610929192** (guild **1499998845873033316**) on **`GUILD_CREATE`** / **`GUILD_DELETE`** with members, owner username, created time, guild id, and current arcade + member totals. Channel id in **`data/settings.rb`** as **`HUB_GUILD_LOG_CHANNEL_ID`**.

- **Top.gg voting:** WEBrick webhook listener on `POST /webhooks/topgg` (v1 `x-topgg-signature` + legacy `Authorization`), Prisma **5 + streak** (streak capped at **10**, reset after **>28h** between votes), multiplied by top.gg **weight**, idempotent `vote_id`, blacklist records vote without paying. Tables `topgg_votes_processed`, `topgg_vote_state`. Env: `TOPGG_WEBHOOK_SECRET`, `TOPGG_BOT_DISCORD_ID`, optional `TOPGG_VOTE_PAGE_URL`, `TOPGG_WEBHOOK_PORT`, `TOPGG_WEBHOOK_BIND`. Commands `b!vote` / `/vote` and DM reminder loop. **Gem:** `webrick`.
- **Ko-fi membership webhook:** `POST /webhooks/kofi` mounts when **`KOFI_VERIFICATION_TOKEN`** is set. Verifies Ko-fi JSON **`verification_token`**, accepts configurable membership `type`s (comma-separated **`KOFI_MEMBERSHIP_WEBHOOK_TYPES`**, default **`Subscription`**), persists idempotent **`kofi_webhooks_processed`** rows, runs **`grant_premium_roles_after_kofi`** (**`PREMIUM_SERVERS`**) when a Discord snowflake is present on replay-safe membership receipts, clears **`CACHE`** premium keys after sync. Shares **`TOPGG_WEBHOOK_*`** bind/port with Top.gg. Listener lives in **`components/blossom_webhook_server.rb`** (**`TopggWebhookServer`** aliases **`BlossomWebhookServer`**).
- **`b!premium` / `/premium`** (`vip`, `supporter`, `subscribe`) — short Neon Arcade VIP rundown + **`KOFI_PAGE_URL`** Ko‑fi link line when configured.

- Developer commands `b!dcommxp` (aliases `dcomm`, `communityxp`) to adjust **community** (server-wide pooled) XP and level for the current guild — separate from per-user `setxp`. `add` / `remove` / `set` recalc level from cumulative XP; `level` sets rank while preserving stored XP. DB helpers `community_xp_threshold` and `community_level_from_total_xp` on `DatabaseLeveling`; passive community leveling now uses the shared threshold method.
- New DB module `DatabaseTrivia` with `get_trivia_session`, `save_trivia_session`, `mark_trivia_answered`, and `clear_trivia_session`.
- New `trivia_sessions` table (one row per user, upserted on each new question).
- New `helpers/blacklist_guard.rb` that monkey-patches `ApplicationCommandEventHandler#call` and `ComponentEventHandler#call` to enforce the blacklist on all interaction types.
- New `DB.prune_orphan_servers(active_ids)` method on `DatabaseLeveling` that cleans the global leaderboard and per-server XP tables of any server IDs not in the supplied active list (with empty-list safety guard).
- New `DB.purge_user_data(uid)` method on `DatabaseAdmin` that nukes a user's entire footprint across every per-user and pairwise-relationship table in a single transaction. Returns a `{ table_name => deleted_row_count }` hash so callers can log meaningful summaries. Per-table failures roll back to a savepoint and continue instead of aborting the whole purge.
- New developer command `b!dserver` (prefix-only, no slash variant by design) that DMs the invoking developer an alphabetically sorted, numbered list of every server Blossom is currently connected to. Output is chunked across multiple DMs to respect Discord's 2000-char limit; in-channel reply confirms the total count and number of DM chunks sent. The command is listed in `b!devhelp`.

### Changed

- **`PREMIUM_SERVERS`** (guild **`1499998845873033316`**): subscriber role id is now **`1500326377780547604`** (`helpers/economy_engine.rb`).
- **Main server auto level roles:** IDs updated for milestones 5 / 10 / 20 / 30 / 40 / 50 / 75 / 100 (`events/passive/user_leveling.rb`).
- **Weekly challenges CV2:** Decorative Unicode emoji (status icons, headers, bonus lines, claim button, completion screen) removed so only the custom **coin** and **Prisma** server emojis remain beside amounts.
- **Developer commands are prefix-only.** Slash handlers and slash registry entries for dev tools were removed so they do not appear in Discord’s public command list (`dcommxp`, `dreset`, `dticketsetup`, `dapplysetup`, and the dev-only registrations in `slash_registry.rb` such as addcoins/prisma/blacklist/card/premium/backup/syncachievements). Use prefix commands and `b!devhelp` instead.
- `.ruby-version` bumped to **3.4.9** (Ruby 3.4 patch). README tech table updated: **PostgreSQL** (`pg` + `connection_pool`) and **discordrb 3.7.2** (replacing stale SQLite / generic discordrb rows).
- Giveaway scheduler sleeps until the next scheduled end time (with a short cap so newly posted giveaways are picked up) instead of polling Postgres every 10 seconds.
- Premium auto-claim batches per-user daily context into one query and runs daily/calendar/Prisma writes in a single transaction.
- Replaced `Hexchu` Goddess art URL across all banner goddess pools.
- Expanded the VTuber roster by adding a large batch of new characters distributed across Common, Rare, and Legendary tiers.
- Added new Goddess-tier cards across all banners: `baonuki`, `Katoh Eli`, and `Megrocks.exe`.
- Updated Blossom's baonuki card flavor text in gacha/trade/view flows to refer to baonuki as "mom's past life."
- Added mama-focused Blossom flavor lines for interactions involving `baonuki` (summon, buy, givecard, view, and trades).
- Added developer command `b!derase` to globally remove `Kyvrixon` and refund 100 Prisma per removed copy.
- Fixed auto-claim daily so it also increments weekly `daily_claims` challenge progress.
- Removed the now-unused `ACTIVE_TRIVIA` in-memory hash from `data/constants.rb`.

---

## [v1.3.0] - 2026-04-15

### Summary

Major integration update: Wires together six previously scaffolded systems — crews, friendships, crafting, weekly challenges, daily tips, and Blossom dialogue. All systems now actively track progress, award bonuses, and interconnect with the economy engine. Massively expands Blossom's personality with new dialogue categories and more varied responses.

---

### Added

#### Crew System — Fully Wired

- Crew coin bonus (+5%) now **actually applied** in `award_coins()` for all earning commands
- Crew XP earned passively when members earn coins (1 XP per 50 coins)
- Crew level-up logic: crews level up when XP reaches `level × 1,000`
- Crew bonus stacks with Premium (+10%) and Happy Hour multipliers

#### Friendship/Affinity System — Fully Wired

- Affinity now awarded automatically from all social interactions:
  - Collab: +5, Trade: +3, Gift Coins: +5, Gift Card: +5
  - Hug: +1, Slap: +1, Pat: +1
- Friendship tiers unlock collab bonuses: Friend (+5%), Close Friend (+10%), Best Friend (+15%)
- New dialogue helpers: `friendship_milestone_remark()`, `crew_remark()`, `craft_remark()`

#### Weekly Challenge Tracking — Fully Wired

- Challenge progress now tracked from **all** matching commands:
  - `arcade_wins` — all arcade games (coinflip, slots, roulette, dice, etc.)
  - `cards_pulled` — summon command
  - `coins_earned` — work, stream, post, collab
  - `coins_given` — givecoins command
  - `trades_completed` — trade accept handler
  - `social_sent` — hug, slap, pat (both Blossom and user-to-user)
  - `cards_gifted` — givecard command
  - `collab_completed` — collab accept handler
  - Previously working: `daily_claims`, `trivia_correct`, `boss_attacks`, `cards_salvaged`

#### Ticket & Application System — New Developer Commands

- `b!dticketsetup #channel` — Posts a support ticket panel with select menu (5 categories: General, Bug, Account, Feedback, Other)
- `b!dapplysetup #channel` — Posts a mod application panel with select menu (Twitch Mod, Discord Mod)
- When a user selects a category, a private channel is created in the designated ticket category
- Private channels visible only to: ticket opener + Staff role
- Each ticket channel gets an embed with **Claim Ticket** and **Close Ticket** buttons
- Staff role is pinged on ticket creation
- Claim button locks to the claiming staff member
- Close button deletes the channel after 10-second countdown
- Duplicate ticket prevention (one open ticket per user)
- Mod applications include role-specific questionnaires (7 questions each)
- New files: `commands/developer/dticketsetup.rb`, `commands/developer/dapplysetup.rb`, `events/interactions/ticket_system.rb`
- New constants: `TICKET_CATEGORY_ID`, `TICKET_SERVER_ID`, `TICKET_STAFF_ROLE`, `ACTIVE_TICKETS`

#### Daily Tips Expansion

- Pool expanded from 53 to 80+ tips covering new systems
- New tip categories: Crews & Social, Crafting, Weekly Challenges, Boss Battles, Advanced Strategies

#### Blossom Dialogue Expansion

- **Time remarks:** Added 8 AM-noon, lunchtime, evening, and more late-night variants (now covers all hours)
- **Streak remarks:** Every tier now has 3 variants (randomized), added 200-364 day tier
- **Losing remarks:** Every tier now has 3 variants (randomized)
- **Wealth remarks:** Added mid-range tiers (100-999, 10K-99K), all tiers have variants
- **First-time remarks:** Added crew, craft, salvage, hug, invest, fish, boss command types
- **New dialogue categories:**
  - `crew_remark()` — Crew-specific flavor text
  - `craft_remark()` — Crafting/salvage flavor text
  - `friendship_milestone_remark()` — Tier-up celebration messages
  - `challenge_remark()` — Weekly challenge progress flavor
  - `pull_mood_remark()` — Rarity-specific summon mood text

### Changed

#### Economy Engine (`helpers/economy_engine.rb`)

- `award_coins()` now checks for crew membership and applies CREW_COIN_BONUS (+5%)
- `award_coins()` now awards crew XP when a crew member earns coins
- New helper: `award_crew_xp()` — Handles XP addition and level-up threshold checking

#### Arcade Engine (`helpers/arcade_engine.rb`)

- `track_arcade()` now calls `track_challenge(uid, 'arcade_wins', 1)` on wins

#### Core Utils (`helpers/core_utils.rb`)

- `interaction_embed()` now awards friendship affinity and tracks `social_sent` challenges

#### Commands Modified (challenge/affinity hooks added)

- `commands/economy/work.rb` — tracks `coins_earned`
- `commands/economy/stream.rb` — tracks `coins_earned`
- `commands/economy/post.rb` — tracks `coins_earned`
- `commands/economy/givecoins.rb` — tracks `coins_given` + awards affinity
- `commands/gacha/summon.rb` — tracks `cards_pulled`
- `commands/gacha/givecard.rb` — tracks `cards_gifted` + awards affinity
- `commands/fun/hug.rb` — tracks `social_sent` (Blossom case)
- `commands/fun/slap.rb` — tracks `social_sent` (Blossom case)
- `commands/fun/pat.rb` — tracks `social_sent` (Blossom case)

#### Interaction Handlers Modified

- `events/interactions/trade_buttons.rb` — tracks `trades_completed` + awards affinity
- `events/interactions/collab_accept.rb` — tracks `collab_completed` + `coins_earned` + awards affinity

---

## [v1.2.0] - 2026-04-08

### Summary

Massive feature drop: VTuber trivia, hourly heist events, monthly boss battles, auto-moderation, and holiday event backend. Adds 7 new user commands, 3 new admin commands, 4 new DB tables, 2 new background loops, and a generalized seasonal event system.

---

### Added

#### VTuber Trivia (`/trivia`) — New Arcade Command

- Multiple-choice trivia with 4 answer buttons (A/B/C/D) and 15-second timer
- 5 auto-generated question types from character pool data:
  - Rarity tier identification ("What rarity is X?")
  - Comparative rarity ("Which VTuber has the highest rarity?")
  - Odd-one-out with fake VTuber names ("Which is NOT in the collection?")
  - Reverse rarity ("Which VTuber is in the Legendary tier?")
  - General knowledge (hardcoded bank)
- 16 hardcoded general VTuber/Blossom knowledge questions (gacha mechanics, items, lore)
- 20 fake VTuber names for odd-one-out questions
- Rewards: 50-100 coins (100-200 for Premium)
- 2-minute cooldown between questions
- Correct/wrong/timeout states all handled with CV2 response updates
- New data file: `data/trivia.rb` with `generate_trivia_question()` and `build_character_index()`
- New command file: `commands/arcade/trivia.rb`
- New interaction handler: `events/interactions/trivia_answer.rb`

#### Hourly Heist Events (`/heist`) — New Admin + Passive System

- Admin command: `b!heist setup #channel` / `b!heist disable` to designate a heist channel per server
- Background loop spawns vault robbery opportunities every hour (offset 30 min from lottery)
- 5-minute join window with "Join the Heist!" button
- Minimum 3 players required to execute; cancelled if too few join
- Success calculation:
  - Base: 30% + 5% per player
  - Premium "hacker bonus": +3% per premium player
  - Maximum cap: 85%
- Vault rewards: 2,000 base + 500 per player coins, split evenly among crew
- No penalty on failure — encourages participation
- Success/failure announcements with crew mentions and stats
- New command file: `commands/admin/heist.rb`
- New interaction handler: `events/interactions/heist_join.rb`
- New background thread in `events/passive/background_loops.rb`

#### Monthly Boss Battles (`/boss`, `/bosssetup`) — New Arcade + Admin Commands

- Global HP boss auto-spawns each calendar month (100,000 HP)
- `b!boss` — View current boss with visual HP bar and Attack button
- Attack once per hour: 50-200 damage (100-400 for Premium — double damage)
- Visual HP bar using red/black square emojis with percentage display
- On defeat: ALL participants who dealt damage earn 50 Prisma
- Final blow announcement with killer credit
- 12 rotating boss names: Glitch Hydra, The Lag Beast, Corrupted Firewall, Neon Phantom, Data Leviathan, Pixel Wyrm, Void Sentinel, Static Colossus, Binary Behemoth, The Buffering Horror, Malware Titan, Desync Demon
- `b!bosssetup #channel` — Admin command to set defeat announcement channel
- Individual participant damage tracking and cooldown display
- New command file: `commands/arcade/boss.rb`
- New interaction handler: `events/interactions/boss_attack.rb`

#### Auto-Mod Lite (`/automod`) — New Admin Command + Passive Handler

- **Word filter:** Configurable banned words list, auto-deletes matching messages
  - `b!automod words add <word>` / `b!automod words remove <word>`
  - `b!automod words list` — Sends list via DM for privacy (never posted in channel)
  - Status display shows word count only ("X words banned"), not the actual words
- **Link filter:** Toggle to block all URLs/links from non-admin users
  - Matches `http://`, `https://`, `www.`, and `discord.gg/` patterns
  - `b!automod links` to toggle
- **Spam filter:** Rate limiting with automatic timeout
  - Triggers on 5+ messages within 5 seconds from the same user
  - Applies 1-minute timeout via raw Discord API (PATCH guild member)
  - In-memory tracking with automatic cleanup of old timestamps
  - `b!automod spam` to toggle
- All three filters skip administrators and developer IDs
- `b!automod` with no args shows full status dashboard (filter states + word count)
- New command file: `commands/admin/automod.rb`
- New passive handler: `events/passive/automod_handler.rb`

#### Holiday Event Backend — Generalized Seasonal System

- Refactored `data/events.rb` from single-event config to master registry pattern
- `SEASONAL_EVENTS` hash maps months to event configs for quick lookup
- Three new skeleton events prepared (character pools empty, pending art):
  - **Summer Beach Party** (July) — Currency: Seashells, Items: Snow Cone, Watermelon Slice
  - **Halloween Arcade** (October) — Currency: Candy Corn, Items: Pumpkin Latte, Witch Cookie
  - **Winter Wonderland** (December) — Currency: Snowflakes, Items: Hot Cocoa, Gingerbread Cookie
- Each event follows the Spring Carnival structure: name, month, currency, emoji, characters hash, items hash
- New helper functions for event system:
  - `get_active_event()` — Returns current month's event config or nil
  - `event_active?()` — Boolean check for any active event
  - `get_event_characters()` — Returns character pools for current event
  - `event_has_characters?()` — Checks if event has non-empty character pools (ready for gacha)
- Existing Spring Carnival preserved unchanged

### Changed

#### New Command Categories

- Added `trivia`, `boss` to Arcade category (now 12 commands)
- Added `heist`, `automod`, `bosssetup` to Admin category (now 12 commands)

#### Database Schema

- New tables: `automod_config`, `automod_words`, `boss_battles`, `boss_participants`
- New `server_configs` columns: `heist_channel BIGINT`, `boss_channel BIGINT`
- 15 new DB methods in `data/database/admin.rb`:
  - Automod: `get_automod_config`, `toggle_automod_setting`, `get_automod_words`, `add_automod_word`, `remove_automod_word`
  - Heist: `get_heist_channel`, `set_heist_channel`, `get_all_heist_channels`
  - Boss: `get_current_boss`, `create_boss`, `boss_attack`, `boss_defeat`, `get_boss_participants`, `get_boss_participant`, `get_boss_channel`, `set_boss_channel`

#### Global State

- New tracking hashes: `ACTIVE_TRIVIA` (per-user trivia sessions), `ACTIVE_HEISTS` (per-server heist events)
- New economy constants: `TRIVIA_`*, `HEIST_*`, `BOSS_*`, `SPAM_*` (16 new constants)
- New boss name pool: `BOSS_NAMES` (12 entries)

#### Background Loops

- Added hourly heist spawner thread (offset from lottery by 30 min)
- Heist execution runs in spawned sub-threads after 5-min join window

#### Entry Point

- `main.rb` now loads `data/trivia.rb` after character pools for question generation

---

## [v1.1.0] - 2026-04-08

### Summary

Major economy overhaul: daily login calendar with visual grid and milestone bonuses, passive income investments for premium users, random coin happy hours, auto-claim daily, and remindme opened to all users. Adds 4 new economy commands, 2 new DB tables, 2 new background loops, and modifies the core `award_coins()` function.

---

### Added

#### Daily Login Calendar — `/daily` Rewrite

- Completely replaced the basic daily command with a visual monthly calendar grid
- Calendar rendered in a code block showing the full month:
  - `██` = Claimed day
  - `▶▶` = Today (claimable)
  - `··` = Missed day (past, unclaimed)
  - `--` = Future day
- New milestone bonuses at 14 and 28 claimed days per month:
  - 14-day: 1,000 coins (2,000 for Premium)
  - 28-day: 5,000 coins (10,000 coins + 10 Prisma for Premium)
- Calendar grid displays even when on cooldown so users can always track progress
- Milestone progress shown below grid: "Milestones: X/14 (★ Bonus) │ X/28 (★★ Mega Bonus)"
- Happy hour indicator shown when active
- All existing daily mechanics preserved: 24h cooldown, 48h streak grace, Neon Sign x2, marriage bonus, Prisma reward
- New database table: `daily_calendar (user_id, claim_date)` tracks individual claim dates
- New DB methods: `add_calendar_claim()`, `get_calendar_claims()`, `get_monthly_claim_count()`
- New economy constants: `CALENDAR_MILESTONE_14/28`, reward amounts for free and premium

#### Passive Income System (Premium) — `/invest`, `/portfolio`, `/withdraw`

- `/invest <amount>` — Lock coins into a compounding interest portfolio
- `/portfolio` — View investment with visual progress bar (`█` filled / `░` empty)
- `/withdraw` — Cash out principal plus all earned profit at any time
- Rate: 0.5% per hour (compounding via `(1 + rate)^hours` formula)
- Max return: 2x principal (100% profit cap) — prevents infinite growth
- Minimum investment: 1,000 coins
- One active investment per user (must withdraw before investing again)
- Portfolio shows: principal, profit, current value, time invested, progress %
- "MAX PROFIT REACHED!" indicator when cap is hit
- New DB table: `investments (user_id, principal, invested_at)`
- New DB methods: `get_investment()`, `create_investment()`, `delete_investment()`
- New helper: `calculate_investment_value()` in `economy_engine.rb`
- New command file: `commands/economy/invest.rb`

#### Happy Hour — Random Coin Multiplier Events

- 10% chance each hour to trigger a 30-minute happy hour
- During happy hour: all `award_coins()` calls apply multiplier
  - Free users: 2x coins
  - Premium users: 3x coins (replaces normal 10% bonus, not stacked)
- Global mutable state: `$happy_hour = { multiplier:, ends_at: }` or nil
- Background thread aligned to top of each hour for consistent timing
- Happy hour status shown on daily command and other earning responses
- New helper: `happy_hour_active?()` in `economy_engine.rb`
- New constants: `HAPPY_HOUR_CHANCE`, `HAPPY_HOUR_DURATION`, `HAPPY_HOUR_MULTIPLIER`

#### Auto-Claim Daily (Premium) — `/autoclaim`

- Toggle automatic daily reward claiming for premium subscribers
- Background loop checks every 2 minutes for eligible users
- Full reward calculation: streak, base + bonus, marriage, Neon Sign, premium 10%, happy hour
- Prisma earned automatically (1-3 base × streak multiplier)
- Calendar claims tracked automatically
- Milestone bonuses (14-day, 28-day) awarded when hit
- Achievement checks run silently
- DM sent to user with: reward amount, Prisma, streak count, calendar progress, milestones
- Auto-disables if user loses premium status (checked each cycle)
- New DB column: `global_users.autoclaim_daily INTEGER DEFAULT 0`
- New DB methods: `get_autoclaim()`, `toggle_autoclaim()`, `get_autoclaim_users()`
- New command file: `commands/economy/autoclaim.rb`

### Changed

#### RemindMe — No Longer Premium Only

- `/remindme` is now available to all users, not just Premium subscribers
- Removed premium gate check from the command (was lines 16-22)
- Removed premium status verification from the background reminder loop
- Reminder pings now fire for any user with a reminder channel set
- Premium users now have the superior `/autoclaim` feature as their exclusive daily helper

#### Economy Engine (`helpers/economy_engine.rb`)

- `award_coins()` now checks for active happy hours before applying multiplier:
  - Happy hour active + premium → 3x
  - Happy hour active + free → 2x
  - No happy hour + premium → 1.1x (unchanged)
  - No happy hour + free → 1x (unchanged)
- New `happy_hour_active?()` helper function
- New `calculate_investment_value()` helper for compound interest calculations

#### Command Categories

- Added `invest`, `portfolio`, `withdraw`, `autoclaim` to Economy category (now 17 commands)

#### Database Schema

- New tables: `daily_calendar`, `investments`
- New column: `global_users.autoclaim_daily`

---

## [v1.0.0] - 2026-04-08

### Summary

Initial documented release of Blossom Bot — a full-featured Discord bot built with Ruby (discordrb) for content creator communities. Includes economy, gacha collection, arcade games, social interactions, leveling, moderation, server administration, and premium subscriber features.

---

### Added

#### Core Systems

- Dual command invocation: prefix (`b!`) and Discord slash commands (`/`) for all commands
- CV2 (Components v2) rendering system for modern Discord UI with styled containers
- V1 component system (discordrb Views) for interactive buttons, select menus, and pagination
- SQLite database backend with modular schema (economy, gacha, leveling, etc.)
- Premium subscriber system with Ko-fi webhook integration
- Achievement engine with automatic milestone tracking and configurable notifications
- XP and leveling system (5 XP per message, 10-second cooldown)
- Community level system for servers with toggleable announcements
- Hourly lottery system with global prize pool

#### Economy Commands (13)

- `/daily` — Daily coin claim with streak bonuses (350 base + 30 per streak day)
- `/work` — Earn 35-75 coins (10 min cooldown)
- `/stream` — Go live on a random game for 75-150 coins (30 min cooldown)
- `/post` — Upload to a random social platform for 15-35 coins (5 min cooldown)
- `/collab` — Request collaboration partner, both earn 150 coins (30 min cooldown)
- `/balance` — Profile dashboard with coins, Prisma, rep, cosmetics, and navigation menu
- `/givecoins` — Transfer coins to another player
- `/sell` — Mass-sell duplicate cards with filters (all, over5, rarity)
- `/cooldowns` — Paginated cooldown status dashboard (3 pages)
- `/lottery` — Purchase lottery tickets (100 coins each)
- `/lotteryinfo` — View lottery status and prize pool
- `/remindme` — Toggle daily reminder DM notifications (Premium)
- `/event` — Seasonal event hub access

#### Gacha & Collection Commands (12)

- `/summon` — Gacha pull system with rarity tiers (150 coins, 10 min cooldown)
- `/shop` — Interactive shop browser for characters and items
- `/buy` — Direct purchase of characters and Black Market items
- `/view` — Character detail viewer with ownership info and art
- `/collection` — Paginated collection browser with rarity filtering
- `/trade` — 1-for-1 card trade proposals with timed acceptance window
- `/givecard` — One-way card gifting
- `/giftlog` — Paginated gift history browser
- `/ascend` — Fuse 5 duplicates into 1 Shiny Ascended card (5,000 coins)
- `/autosell` — Toggle auto-sell commons during summon (Premium)
- `/shinymode` — Toggle doubled summon cost for doubled shiny chance (Premium)
- `/custombanner` — Create custom 1-hour summon banner for 20 Prisma (Premium)

#### Gacha Mechanics

- Four rarity tiers: Common, Rare, Legendary, Goddess
- Pity system: Guaranteed Legendary/Goddess after 30 pulls below Legendary or Goddess—Rare pulls count toward pity (Premium)
- Shiny Ascended variants: 1% base chance, 2% with Shiny Hunting Mode
- Event pull chance: 5% during active event months
- Custom banner system with user-selected character pools
- Auto-sell for commons owned 5+ times during summon

#### Arcade Commands (10)

- `/coinflip` — 50/50 coin flip (2x payout)
- `/slots` — 3-reel slot machine (5x jackpot, 2x partial match)
- `/blackjack` — Full blackjack with Hit/Stand/Double Down (2.5x on natural 21)
- `/roulette` — European roulette with number, color, and parity bets (up to 36x)
- `/dice` — High/Low/Lucky 7 dice game (2x or 4x payout)
- `/cups` — 1-in-3 shell game (3x payout)
- `/scratch` — 500-coin scratch tickets (up to 10,000 coin jackpot)
- `/spin` — Free daily prize wheel with coins, Prisma, and card rewards
- `/rps` — PvP Rock Paper Scissors with coin betting
- `/fish` — Fishing minigame with 13 base catches and 3 Premium catches (5 min cooldown)

#### Fun & Social Commands (12)

- `/hug` — Send hugs with random GIFs and stat tracking
- `/slap` — Send slaps with random GIFs and stat tracking
- `/pat` — Send head pats with random GIFs and stat tracking
- `/interactions` — View aggregated sent/received stats for all interaction types
- `/rep` — Give reputation (1/day free, 3/day Premium)
- `/marry` — Proposal system with acceptance buttons and +50 daily bonus
- `/divorce` — End marriage
- `/birthday` — Set birthday (once) for 1,000 coin reward on your day
- `/level` — XP/level profile card with progress bar
- `/leaderboard` — Server and global rankings for coins, Prisma, and levels
- `/serverinfo` — Server stats and community level display
- `/giveaway` — Timed giveaway creation with participation button (Admin)
- `/kettle` — Inside-joke command

#### Moderation Commands (4)

- `/kick` — Kick members with DM notification and mod logging
- `/ban` — Ban by mention or user ID with DM notification and mod logging
- `/timeout` — Timed communication restriction with duration parsing (m/h/d)
- `/purge` — Bulk message deletion (1-100 messages)

#### Server Administration Commands (8)

- `/logsetup` — Set mod log destination channel
- `/logtoggle` — Toggle log categories (deletes, edits, mod, dms, joins, leaves)
- `/levelup` — Configure level-up notification channel or toggle on/off
- `/bomb` — Enable/disable random bomb drop events in a channel
- `/welcomer` — Welcome message system with custom text and placeholders
- `/verifysetup` — Button-based member verification gate
- `/achievements` — Toggle server-wide achievement announcements
- `/commleveltoggle` — Toggle community level-up announcements
- `/reactionrole` — Create and manage reaction role panels (prefix only)

#### Voice Commands (4)

- `/join` — Connect Blossom to voice channel
- `/leave` — Disconnect from voice channel
- `/play` — Play MP3 from music library
- `/stop` — Stop audio playback

#### Utility Commands (8)

- `/ping` — Latency check
- `/help` — Command navigation hub with category browsing
- `/about` — Bot info and developer credits
- `/support` — Official support server invite link
- `/suggest` — Send suggestions directly to the developer via DM
- `/stats` — Comprehensive lifetime statistics dashboard
- `/notifications` — Configure achievement notification delivery (channel, DM, silent)
- `/profile` — Premium profile customization (color, bio, favorites, pet, title, theme, badge)

#### Developer Commands (9)

- `dcoin` — Adjust user coin balance
- `dpremium` / `givepremium` / `removepremium` — Manage Premium status
- `blacklist` — Block users from using the bot
- `card` — Grant cards directly to users
- `prisma` — Adjust user Prisma balance
- `dbomb` — Force-trigger a bomb event
- `dreset` — Reset user data
- `syncachievements` — Sync achievement database
- `devhelp` — Developer command reference

#### Items & Black Market

- **Tech Upgrades (permanent, one-time purchase):**
  - Headset (500 coins) — +25% post payouts
  - RGB Keyboard (2,000 coins) — +25% work payouts
  - Studio Mic (10,000 coins) — +10% stream payouts
  - Holographic Neon Sign (25,000 coins) — x2 daily reward
  - Gacha Pass (15,000 coins) — Halves summon cooldown
- **Consumables (single-use):**
  - Stamina Pill (1,500 coins) — Bypass summon cooldown
  - Gamer Fuel (2,500 coins) — Bypass content command cooldown
  - RNG Manipulator (5,000 coins) — Guarantee Rare+ on next summon

#### Achievement System (100+ achievements across 14 categories)

- **Economy & Streaks:** 7, 30, 69, 100, 365-day streak milestones
- **Wealth Milestones:** 0, 10K, 100K, 1M, 10M coin thresholds
- **First Activities:** First stream, collab, work, post, gift
- **Coin Gifting:** 10K and 100K total coins given, first sell
- **Leveling:** Level 5, 10, 25, 50, 100
- **Gacha & Pulls:** First pull, Goddess luck, 100/500/1000 pulls, Legendary pull, back-to-back
- **Collection Size:** 10, 50, 100, 200 unique characters
- **Rarity Collectors:** 25 Rares, 10/25 Legendaries, 5 Goddesses
- **Ascension:** First, 5, 10, 25 ascensions; 100 dupes
- **Trading & Gifting Cards:** First trade, 10 trades, first gift, 10 gifts
- **Items & Black Market:** First upgrade, max upgrades, first consumable, use milestones
- **Social Interactions:** Hug/slap/pat milestones at 1, 10, 50, 100 (sent and received)
- **Arcade & Gambling:** Game-specific milestones, high roller, jackpots, lottery
- **Activity Streaks:** 7, 14, 30, 60, 100-day activity
- **Meta:** 10, 25, 50 total achievements unlocked
- **Event:** Carnival ring toss, balloon pop, snack, character, ticket milestones

#### Premium Perks

- 50% cooldown reduction on work, stream, post, and fish
- +10% coin bonus on all earning commands
- Prisma currency earned from daily claims (1-3, scales with streak)
- Pity system on gacha pulls (Premium): guaranteed Legendary or Goddess after 30 pulls below those tiers—Rare pulls count toward the counter
- Shiny Hunting Mode toggle (2x cost for 2x shiny chance)
- Auto-sell commons toggle during summon
- Custom banner creation (20 Prisma, 1 hour duration)
- 5-minute sell undo window
- Daily reminder DM notifications
- Extended trade window (180s vs 60s) and collab window (300s vs 180s)
- Free daily spin reroll
- 3 reputation per day (vs 1)
- Full profile customization (color, bio, favorites, pets, titles, themes, badges)
- Gold Fishing Rod with 3 exclusive catches
- Up to 3 favorite card slots on profile

#### Seasonal Events

- **Spring Carnival (April):**
  - Event currency: Carnival Tickets
  - Exclusive characters: Rainbow Sparkles, Toma (Rare), EmieVT, Necronival, Umaru Polka (Legendary)
  - Carnival treats: Cotton Candy (50 tickets), Candy Apple (75 tickets)
  - Dedicated carnival achievements (ring toss, balloon pop, snack, character, ticket milestones)

#### Passive Systems & Events

- XP gain on messages (5 XP per message, 10-second cooldown)
- Passive coin gain on messages (5 coins per message)
- Bomb drop events (random after 100-300 messages in configured channels)
- Hourly lottery drawings
- Welcome messages for new members
- Message delete/edit logging
- Member join/leave logging
- Mod action logging with DM notifications
- Reaction role assignment
- Button-based member verification

#### Bot Identity

- Blossom persona: Sarcastic, high-energy streamer and Neon Arcade manager
- Custom response flavor text via `mom_remark()` Easter eggs
- Special interactions when targeting Blossom (hug, slap, pat)
- Neon aesthetic with randomized accent colors from `NEON_COLORS` pool
- 38 custom Discord emojis (animated and static)

#### Documentation

- `COMMANDS.md` — Complete user-facing command reference
- `CLAUDE.md` — Developer context and codebase documentation
- `CHANGELOG.md` — This file

---

*Blossom Bot is developed by baonuki.*