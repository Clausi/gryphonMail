# GryphonMail

World of Warcraft addon that extends the default mailbox.

**Load the `wow-lua` skill (`.claude/skills/wow-lua/`) before working on code.** It holds the rules
shared by all WoW addons (luacheck, locales, addon structure, Blizzard UI, secret values, names,
compatibility, changelog). The git workflow and commit messages are in the global `CLAUDE.md`. This
file only adds what is specific to GryphonMail.

## Target clients

- One package for five clients, all listed in `## Interface:` (`11509, 16001, 20506, 50504, 120105`).
  MoP Classic is called "Classic" by Blizzard (game folder `_classic_`).
- Mail frame code: `Blizzard_MailFrame/` on Forever and Retail; on Classic Era, Anniversary and
  MoP Classic the mail frame is part of `Blizzard_UIPanels_Game/Classic/MailFrame.lua`, not the
  load-on-demand `Blizzard_MailFrame`.
- `Core/Names.lua` is the reference implementation of `ns.Names` for the other addons.

## Names and mail

- **Forever:** trading and mail only work within the same ruleset and faction. A full name is unique
  across rulesets, so characters are keyed by name; the ruleset is stored as `realm` per character.
- **Classic Era, Anniversary, MoP Classic, Retail:** the APIs leave out the realm for the own realm
  (mail sender, friends), the guild roster always includes it. `Names.Normalize` gives the key of
  `ns.db.characters`; `Names.ToDisplay` is also the form to enter as mail recipient. Mail only works
  within the same faction and realm, on Retail also between connected realms
  (`C_AutoComplete.GetAutoCompleteRealms()`).

## Locales

`enUS` (base), `deDE`, `frFR`.

## Saved variables

`GryphonMailDB` (account-wide) and `GryphonMailCharDB` (per character, e.g. the mail log).

## Blizzard UI writes

Documented writes to Blizzard frames: `InboxFrame.pageNum` and the replaced `OpenAllMail` methods in
`InboxView.lua`.

## Commit scopes

`inbox-search`, `inbox-filter`, `inbox-view`, `characters`, `mail-log`, `core`, `locales`, `toc`.
