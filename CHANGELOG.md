# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - Unreleased

### Added

- Addon skeleton for WoW Forever (Interface 16001): namespace, module registry, event dispatcher,
  saved variables (`GryphonMailDB`) and `/gryphonmail` slash command.
- Localization with English base locale and German translation.
- Inbox search box that filters mails by sender or subject, including paging through the results.
- "Open All" only opens the filtered mails while a filter is active; the button then reads "Open Filtered".
- Own characters are remembered on login (full name with surname), so mail from alts can be filtered.
- Character names use Forever's first name + surname format throughout; there are no realm suffixes.
- `/gryphonmail debug` toggles debug output in the chat.
- `/gryphonmail chars` lists known characters, `/gryphonmail chars remove <number|name>` forgets one.
