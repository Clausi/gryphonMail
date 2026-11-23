# GryphonMail

World of Warcraft addon that extends the default mailbox.

**Load the `wow-lua` skill (`.claude/skills/wow-lua/`) before working on code.** It holds the rules
shared by all WoW addons (luacheck, locales, addon structure, Blizzard UI, secret values, names,
compatibility, changelog). The git workflow and commit messages are in the global `CLAUDE.md`. This
file only adds what is specific to GryphonMail.

## Target clients

- One package for WoW Forever (16001, `_forever_`, `forever` branch of wow-ui-source) and Retail
  (120105, `_retail_`, `live` branch), both listed in `## Interface:`. Both use the Mainline UI and
  API; the mail frame is the load-on-demand `Blizzard_MailFrame/`. Check both branches when hooking
  Blizzard code.
- Classic Era, Anniversary and MoP Classic are no longer supported: 1.2.4 was the last version for
  them. Do not add code for them.
- Client differences go through `Core/Compat.lua` (inbox update and page buttons, names with or
  without realm).
- `Core/Names.lua` is the reference implementation of `ns.Names` for the other addons.

## Names and mail

- **Forever:** trading and mail only work within the same ruleset and faction. A full name is unique
  across rulesets, so characters are keyed by name. A ruleset is a mega server made up of many
  realms. Since build 71037 the realm name is empty: the ruleset of the logged-in character comes
  from its game rules (`Compat.GetRuleset()`), and a realm name stored before
  ("CAMWOW US1 Realm 10 RP") still names the ruleset (`GetRulesetName` in `Modules/Characters.lua`).
- **Retail:** the APIs leave out the realm for the own realm (mail sender, friends), the guild
  roster always includes it. `Names.Normalize` gives the key of `ns.db.characters`;
  `Names.ToDisplay` is also the form to enter as mail recipient. Mail only works within the same
  faction and realm or connected realms (`C_AutoComplete.GetAutoCompleteRealms()`).

## Locales

`enUS` (base), `deDE`, `frFR`.

## Saved variables

`GryphonMailDB` (account-wide) and `GryphonMailCharDB` (per character, e.g. the mail log).

## Blizzard UI writes

Documented writes to Blizzard frames: `InboxFrame.pageNum` and the replaced `OpenAllMail` methods in
`InboxView.lua`.

## Commit scopes

`inbox-search`, `inbox-filter`, `inbox-view`, `send-mail`, `send-mail-recipients`, `characters`,
`contacts`, `favorites`, `mail-log`, `options`, `core`, `locales`, `toc`.
