# Ruby conventions

Prefer grouped `private` sections over `private_class_method`.
For class helpers, use `class << self` with private helpers below `private`.

Use single-quoted Ruby strings unless interpolation or escapes require double quotes.
Keep application messages in locale files and use `I18n.t` (or `t` in Rails views/controllers).
The custom cops in `config/rubocop` and the lint-gate probes enforce these conventions.
