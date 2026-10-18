# GryphonMail

World of Warcraft: Forever addon that extends the default mailbox.

## Target client

- WoW Forever, `## Interface: 16001`. Forever uses the **Mainline (retail) UI and API**, not Classic Era.
  Do not use Classic-only APIs or Classic UI assumptions.
- Reference for Blizzard UI code: the `forever` branch of https://github.com/Gethe/wow-ui-source
  (e.g. `Interface/AddOns/Blizzard_MailFrame/`). Read the actual Blizzard source before hooking or
  mirroring Blizzard behavior instead of relying on memory.
- Always use `ns.Names` (`Core/Names.lua`) to build, compare and show names; never use `Ambiguate`.
  The rules differ per client (`ns.Compat.HasRealmNames()`):
  - **Forever:** names are "First Surname" (separator from
    `Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR`, a space) and carry no
    realm suffix. `UnitName(unit)` returns first name and **surname**, not name and realm. Each
    ruleset (PvE, PvP, RP) is its own realm, e.g. `GetRealmName()` = "Classic Beta PvE". Trading and
    mail only work within the same ruleset and faction. A full name is unique across rulesets, so
    characters are keyed by name; the ruleset is stored as `realm` per character.
  - **Classic Era, Anniversary, Retail:** names are "Name-Realm" with the realm from
    `GetNormalizedRealmName()` (no spaces). The APIs leave out the realm for the own realm (mail
    sender, friends), the guild roster always includes it. `Names.Normalize` fills in the own realm
    for comparing and as key of `ns.db.characters`; `Names.ToDisplay` gives the short name for the
    own realm, which is also the form to enter as mail recipient. Mail only works within the same
    faction and realm, on Retail also between connected realms (`C_AutoComplete.GetAutoCompleteRealms()`).
- Lua 5.1 (WoW flavor): no `goto`, `//`, bitwise operators, `require`, `io` or `os`.

## Mandatory checks

- **luacheck must be green (0 warnings / 0 errors) after every change.** Run it from the repo root:

  ```
  ./.tools/luacheck.exe .
  ```

- Fix warnings in the code. Only change `.luacheckrc` when the warning is a false positive, e.g. a new
  WoW API global (add it to `read_globals`) or an intentional write to a Blizzard frame field.
  Never silence warnings globally or with inline `-- luacheck: ignore` without a reason in a comment.
- Code cannot be tested in-game from here. After a change, tell the user what to verify in-game.

## Language

- Code, identifiers, comments, commit messages and docs are in **English**.
- Never hardcode user-facing text. Every string goes through `L["KEY"]`:
  1. Add the key to `Locales/enUS.lua` (base locale, must contain every key).
  2. Add the German translation to `Locales/deDE.lua`.
  Missing translations fall back to English.
- `|` starts an escape sequence in WoW text (`|n` newline, `|c` color, ...). Write a literal pipe
  as `||` in user-facing strings.

## Architecture

- All files share the addon namespace via `local addonName, ns = ...`. Do not create new globals;
  the only allowed globals are the ones listed under `globals` in `.luacheckrc`.
- Features live in `Modules/` and register with `ns:RegisterModule("Name")`:
  - `OnInitialize()` runs on `ADDON_LOADED` (saved variables are available).
  - `OnEnable()` runs on `PLAYER_LOGIN`.
- Use `ns:RegisterEvent`, `ns:Print` and `ns:Debug` from `Core/` instead of own event frames or `print`.
- Slash subcommands are registered with `ns:RegisterCommand(name, handler, helpLines)`, never by
  extending the handler in `Core/Main.lua`.
- Saved variables (defaults in `Core/Init.lua`):
  - `GryphonMailDB` / `ns.db` (account-wide, `ns.defaults`): settings and data shared by all characters.
  - `GryphonMailCharDB` / `ns.charDb` (per character, `ns.charDefaults`): data only the logged-in
    character needs, e.g. the mail log. Prefer this for growing per-character data, so a login does
    not load the data of all characters.
- Every new file must be added to `GryphonMail.toc`. Locales first, `Core\Main.lua` last.

## Working with the Blizzard UI

- Prefer `hooksecurefunc` and `HookScript` over replacing Blizzard functions, methods or scripts,
  to avoid taint.
- Keep writes to Blizzard frames minimal and document why, in the code and in `.luacheckrc` (see
  `InboxFrame.pageNum` and the replaced `OpenAllMail` methods in `InboxView.lua`).
- Values returned by the API may be secret values on Forever. Guard string or number operations on
  them with `issecretvalue`.

## Housekeeping

- Record every user-visible change in `CHANGELOG.md` under `[Unreleased]`
  ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format: Added, Changed, Fixed, Removed).
  On a release, move the entries to a new version section and bump `## Version` in `GryphonMail.toc`.
- Keep the structure section in `README.md` up to date when files are added or removed.
- Do not commit or push unless asked.

## Git workflow

- `main` is protected: no direct commits or pushes, every change goes through a pull request.
- Start each change on a new branch from an up-to-date `main`:
  `git checkout main`, `git pull`, `git checkout -b <type>/<short-name>`, using the commit types below
  (e.g. `feat/inbox-filter`, `fix/log-double-count`, `docs/readme`).
- Split work into meaningful commits; each commit must pass luacheck on its own.
- Push with `git push -u origin <branch>`, then create the pull request with
  `gh pr create --base main` and give the user the PR link. The PR title follows the commit message
  format below; title and description are in English.
- After the merge: `git checkout main`, `git pull`, and delete the local branch. GitHub deletes the
  remote branch automatically. Pull requests are merged by rebase, so the commits get new hashes and
  `git branch -d` does not recognize them as merged: check the PR state with `gh pr view` and use
  `git branch -D`.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <description>

<body>

<footer>
```

- **type** (required):
  - `feat`: new user-visible feature
  - `fix`: bug fix
  - `docs`: documentation only (README, CHANGELOG, CLAUDE.md, comments)
  - `refactor`: code change without behavior change
  - `perf`: performance improvement
  - `style`: formatting only
  - `test`: tests
  - `build`: TOC, packaging, deploy scripts
  - `ci`: CI configuration
  - `chore`: tooling and maintenance (e.g. `.luacheckrc`, `.gitignore`)
  - `revert`: reverts a previous commit
- **scope** (optional): the affected area in kebab-case, usually the module, e.g. `inbox-search`,
  `inbox-filter`, `inbox-view`, `characters`, `mail-log`, `core`, `locales`, `toc`.
- **description**: imperative, lowercase start, no trailing period, at most 72 characters including
  type and scope, e.g. `fix(mail-log): count each attachment only once`.
- **body** (optional): explains what and why, not how; wrap at 72 characters.
- **footer**: `BREAKING CHANGE: <description>` (or `!` after the type/scope) for changes that break
  saved variables or slash commands; attribution trailers go here as well.
