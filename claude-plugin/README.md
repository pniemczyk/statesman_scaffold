# statesman_scaffold — Claude Code Plugin

A Claude Code plugin that teaches Claude how to install and use the
[`statesman_scaffold`](https://github.com/pniemczyk/statesman_scaffold) gem in
any Rails application.

## What's Included

```
claude-plugin/
├── .claude-plugin/
│   └── plugin.json                          # Plugin metadata
└── skills/
    └── statesman-scaffold/
        ├── SKILL.md                         # Core skill — auto-loaded when relevant
        ├── references/
        │   ├── installation.md              # Full setup guide with troubleshooting
        │   └── patterns.md                  # Guards, callbacks, scopes, metadata, namespaced models
        └── examples/
            ├── activerecord.rb              # Complete top-level model example
            ├── namespaced.rb                # Namespaced model (Admin::Order)
            └── testing.rb                   # Minitest + RSpec test patterns
```

## Installing the Plugin

### Option A — Point Claude Code at the plugin directory

```bash
# One-off session
claude --plugin-dir /path/to/statesman_scaffold/claude-plugin

# Or copy the plugin directory to your project
cp -r /path/to/statesman_scaffold/claude-plugin /your/project/.claude-plugins/statesman-scaffold
```

### Option B — Install globally in `~/.claude`

```bash
mkdir -p ~/.claude/plugins/statesman-scaffold
cp -r /path/to/statesman_scaffold/claude-plugin/* ~/.claude/plugins/statesman-scaffold/
```

## How the Skill Activates

The skill automatically activates when you ask Claude things like:

- "Add statesman_scaffold to this project"
- "Add a state machine to the Order model"
- "Scaffold a Statesman state machine for Project"
- "Add `with_state_machine` to my model"
- "Add transition history to a Rails model"
- "Generate state machine files for User"
- "Add `.in_state?` and `.transition_to!` to a model"
- "How do I add Statesman guards?"
- "How do I handle concurrent state transitions?"

Claude will then know:

1. How to add the gems and run the installer
2. How to generate state machine files with the rake task
3. How to define states, transitions, guards, and callbacks in `StateMachine`
4. How to wire up the model with `with_state_machine`
5. How namespaced models work and the foreign key nuance
6. How to write tests for state machine models
7. Common errors and how to fix them
