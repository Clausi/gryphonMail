# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/Clausi/gryphonMail/compare/v0.11.0...HEAD
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
