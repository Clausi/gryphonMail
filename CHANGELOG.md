# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Inbox filters "Unread" and "Read".

### Fixed

- "Open Filtered" keeps working on a mail that changes during the run, e.g. becomes read or has its
  gold taken; previously the remaining attachments were skipped.

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

[Unreleased]: https://github.com/Clausi/gryphonMail/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Clausi/gryphonMail/releases/tag/v0.2.0
