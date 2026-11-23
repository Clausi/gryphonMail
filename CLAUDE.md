# GryphonMail

World of Warcraft addon that extends the default mailbox.

**Load the `wow-lua` skill (`.claude/skills/wow-lua/`) before working on code.** It holds the rules
shared by all WoW addons (luacheck, locales, addon structure, Blizzard UI, secret values, names,
compatibility, changelog). The git workflow and commit messages are in the global `CLAUDE.md`. This
file only adds what is specific to GryphonMail.

## Target clients

- **WoW Forever** only (16001, `_forever_`, `forever` branch of wow-ui-source, Mainline UI and API).
  Mail frame code: the load-on-demand `Blizzard_MailFrame/`.
- Classic Era, Anniversary, MoP Classic and Retail are no longer supported: 1.2.4 was the last
  version for them. Do not add code for them.
- `Core/Compat.lua`, `Core/Names.lua` and `Modules/Characters.lua` still have branches for the
  other clients ("Name-Realm" names, mail realms, connected realms on Retail, the Classic mail
  frame). They are left in for now; new code does not need a client check.
- `Core/Names.lua` is the reference implementation of `ns.Names` for the other addons; they take it
  over without `Compat.HasRealmNames()`.

## Names and mail

- Trading and mail only work within the same ruleset and faction. A full name is unique across
  rulesets, so characters are keyed by name. A ruleset is a mega server made up of many realms.
  Since build 71037 the realm name is empty: the ruleset of the logged-in character comes from its
  game rules (`Compat.GetRuleset()`), and a realm name stored before ("CAMWOW US1 Realm 10 RP")
  still names the ruleset (`GetRulesetName` in `Modules/Characters.lua`).

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
