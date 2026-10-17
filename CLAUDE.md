# GryphonMail

World of Warcraft: Forever addon that extends the default mailbox.

## Target client

- WoW Forever, `## Interface: 16001`. Forever uses the **Mainline (retail) UI and API**, not Classic Era.
  Do not use Classic-only APIs or Classic UI assumptions.
- Reference for Blizzard UI code: the `forever` branch of https://github.com/Gethe/wow-ui-source
  (e.g. `Interface/AddOns/Blizzard_MailFrame/`). Read the actual Blizzard source before hooking or
  mirroring Blizzard behavior instead of relying on memory.
- Character names on Forever are "First Surname" (separator from
  `Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR`, a space) and there are no
  realms. `UnitName(unit)` returns first name and **surname**, not name and realm. Always use
  `ns.Names` (`Core/Names.lua`) to build and compare names; never use `Ambiguate` or realm APIs.
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
- Keep writes to Blizzard frames minimal and document why (see `InboxFrame.pageNum` in `InboxSearch.lua`).
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
  `git checkout main`, `git pull`, `git checkout -b feature/<short-name>` (`fix/<short-name>` for fixes).
- Split work into meaningful commits; each commit must pass luacheck on its own.
- Push with `git push -u origin <branch>`, then create the pull request with
  `gh pr create --base main` (title and description in English) and give the user the PR link.
  `gh` is installed at `C:\Program Files\GitHub CLI\gh.exe`; use the full path if `gh` is not on `PATH`.
- After the merge: `git checkout main`, `git pull`, and delete the merged branch.
- The addon has not been released yet: do not write migration code for saved variables. Change the
  data format directly; testers clear their data if needed. Revisit this rule after the first release.
