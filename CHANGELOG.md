# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Favorites: an account-wide list of characters, e.g. recent allies, friends' alts or any other
  name. Add the name in the "To" field of "Send Mail" with the last entry of the recipient dropdown
  (the same entry removes it again), or use `/gryphonmail fav add <name>`. Favorites that can
  receive mail from the current character are listed in the recipient dropdown below your own
  characters and are suggested by the search box. The inbox and the mail log have a new filter
  "Favorites". `/gryphonmail fav` lists them, `/gryphonmail fav remove <number|name>` removes one.

### Changed

- "Send Mail": the attach menu shows the number of items besides the number of stacks, e.g.
  "Iron Ore (3 stacks, 60 items)". Entries whose stacks are single items show only the items.
  The option "Item counts in the attach menu" turns it off (on by default, for all characters).
- "Send Mail": the attach menu stays open after an entry is clicked, so several categories can be
  attached one after another. Its counts show what is left, entries with nothing left turn gray.
  The option "Keep the attach menu open" turns it off (on by default, for all characters).

### Fixed

- The placeholder text of the search box fits on one line in the German and French clients
  ("Name, Betreff, Item", "Nom, objet, PJ").

## [1.0.1] - 2026-11-07

### Changed

- Forever: the character list shows only the ruleset instead of the long realm name, e.g.
  "(PvE, Horde)".

### Fixed

- Forever: own characters of the same ruleset are mail targets again when they are on different
  realms of the mega server (e.g. "CAMWOW US1 Realm 10 RP" and "CAMWOW US2 Realm 11 RP"). This
  covers the "Send Mail" recipient dropdown, the search suggestions and `/gryphonmail chars`.

## [1.0.0] - 2026-11-05

First stable release.

### Fixed

- Searching in the game settings no longer reports a blocked action for GryphonMail
  (`ADDON_ACTION_FORBIDDEN` for `IsUserOAuthed`). The "Remove" button of the options page no longer
  appears in the settings search.

## [0.15.0] - 2026-11-03

### Added

- "Send Mail": right-click an empty attachment slot for a menu that attaches all items of a
  category from the bags: item class, subclass or a single item (with icon), or poor quality.

## [0.14.0] - 2026-11-03

### Added

- "Send Mail": Alt-click an item in the bags to attach all its stacks, Alt-right-click an
  attachment slot to remove all attachments.

## [0.13.0] - 2026-10-31

### Changed

- The days the mail log keeps are set per character. Each character starts with the value that was
  set for all characters before.

## [0.12.0] - 2026-10-27

### Added

- Options page in the game settings (Esc > Options > AddOns > GryphonMail) for the automatic
  messages and the days the mail log keeps, also opened with `/gryphonmail options`.
- Known characters can be removed on the options page, like with `/gryphonmail chars remove`.
- Releases are also published on [WoWInterface](https://www.wowinterface.com/downloads/info27278).
- Friends submenu in the recipient dropdown of "Send Mail".

### Changed

- `/gryphonmail chat on|off` is now `/gryphonmail notify on|off`, as in GryphonChat. The setting
  itself is kept.

## [0.11.0] - 2026-10-25

### Added

- Support for Mists of Pandaria Classic.

## [0.10.0] - 2026-10-23

### Added

- French translation.
- Releases are also published on [Wago Addons](https://addons.wago.io/addons/gryphonmail).

## [0.9.0] - 2026-10-22

### Added

- The search box of the inbox and the log also finds mail by the name of an attached item.
- `/gryphonmail chars` marks the characters the current one can send mail to with a mailbox
  icon.

## [0.8.0] - 2026-10-20

### Added

- Classic Era and Anniversary: with an active search or filter, "Open All" becomes "Open Filtered"
  and only opens the matching mail, as on Forever and Retail.

## [0.7.0] - 2026-10-18

### Added

- Support for WoW Classic Era (11509), Anniversary (20506) and Retail (120105) next to Forever, in
  one package. Inbox search, filters, paging, the mail log and the recipient dropdown work on all
  clients, and the search boxes, the filter dropdown and the log tab fit the mail frame of each
  client. In Classic Era and Anniversary, "Open All" keeps its name and opens all mail, also with an
  active filter: opening only the filtered mail is not possible there.
- Outside Forever, characters are told apart by realm: characters with the same name on different
  realms are listed separately, the filters compare names with realm, and only own characters of
  the same faction on the same realm (Retail: also connected realms) are offered as recipients.
  Characters on other realms are shown as "Name-Realm".
- `/gryphonmail chars` also shows the faction of each character, next to its realm.
- `/gryphonmail chat on|off` turns the automatic chat messages of the current character on or off:
  the login message, the summary after "Open All" and the recent allies hints. Answers to commands
  are always shown.

## [0.6.0] - 2026-10-18

### Added

- The mail log also records sent mail: recipient, subject, gold, items and the requested C.O.D.
  amount. Sent mail is shown as "To: <recipient>" in blue.
- The mail log also records deleted and returned mail, including the gold and items it still
  contained. Deleted mail is shown as "Deleted: <sender>" in gray, returned mail as "Returned to:
  <sender>" in orange, each with its own filter.
- The mail log has the same search box and filter dropdown as the inbox. Instead of "Unread" and
  "Read", the filters "From" (received) and "To" (sent) are offered.

### Changed

- The retention of the mail log moved from the header into the title, e.g. "Mail Log (30 days)".
- The filter dropdowns of inbox and log only build their menu while it is open, which saves memory.

## [0.5.0] - 2026-10-18

### Added

- Inbox filter "Recent Allies": mail from characters in the "Recent Allies" tab of the friends
  list. A chat message explains when that list is empty or not loaded yet.
- The recipient dropdown of "Send Mail" has submenus "Guild" and "Recent Allies" next to your own
  characters. Lists with more than 20 entries are split into submenus by name range.
- Debug mode (`/gryphonmail debug`) prints how much memory the loaded files and each module keep
  after loading.

### Fixed

- The recipient dropdown of "Send Mail" only builds its menu while it is open, which saves memory.

## [0.4.0] - 2026-10-17

### Added

- Dropdown next to the "To" field of "Send Mail" to pick one of your own characters of the same
  faction and ruleset (PvE, PvP, RP) as recipient.
- `/gryphonmail chars` shows the ruleset of each character.

### Changed

- The search box only suggests own characters of the same faction and ruleset, since mail from other
  characters cannot arrive.
- Inbox filter presets are grouped and reordered: My Characters, Friends, Guild | Unread, Read |
  Auction House, Gold, C.O.D.

## [0.3.0] - 2026-10-17

### Added

- Inbox filters "Unread" and "Read".
- The mail log records the C.O.D. amount paid for a mail ("C.O.D. paid" in the entry and its tooltip).

### Fixed

- "Open Filtered" keeps working on a mail that changes during the run, e.g. becomes read or has its
  gold taken; previously the remaining attachments were skipped.
- "Open All" / "Open Filtered" no longer requests the same attachment twice, which the game answered
  with "The item was not found".

## [0.2.0] - 2026-10-17

### Added

- Addon skeleton for WoW Forever (Interface 16001): namespace, module registry, event dispatcher,
  saved variables (`GryphonMailDB`) and `/gryphonmail` slash command.
- Localization with English base locale and German translation.
- Inbox search box that filters mails by sender or subject, including paging through the results.
- "Open All" only opens the filtered mails while a filter is active; the button then reads "Open Filtered".
- Filter dropdown in the inbox with predefined filters: Friends, Guild, My Characters, Auction House,
  C.O.D. and Gold. Combines with the search box.
- Own characters are remembered on login (full name with surname), so mail from alts can be filtered.
- Character names use Forever's first name + surname format throughout; there are no realm suffixes.
- The search box suggests own characters while typing (Tab/arrow keys to select, Enter or click to accept).
- New "Log" tab in the mail frame: lists collected mails (sender, subject, gold, items) per character,
  stored in the character's own saved variables.
  Entries are kept for 30 days by default, configurable with `/gryphonmail log days <n>`.
- Chat summary after "Open All" / "Open Filtered" with the collected item quantity and the gold amount.
- `/gryphonmail debug` toggles debug output in the chat.
- `/gryphonmail chars` lists known characters, `/gryphonmail chars remove <number|name>` forgets one.

[Unreleased]: https://github.com/Clausi/gryphonMail/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/Clausi/gryphonMail/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/Clausi/gryphonMail/compare/v0.15.0...v1.0.0
[0.15.0]: https://github.com/Clausi/gryphonMail/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/Clausi/gryphonMail/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/Clausi/gryphonMail/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/Clausi/gryphonMail/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/Clausi/gryphonMail/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/Clausi/gryphonMail/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/Clausi/gryphonMail/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/Clausi/gryphonMail/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/Clausi/gryphonMail/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/Clausi/gryphonMail/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Clausi/gryphonMail/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Clausi/gryphonMail/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Clausi/gryphonMail/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Clausi/gryphonMail/releases/tag/v0.2.0
