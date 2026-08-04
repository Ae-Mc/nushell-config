# Repository Guidelines

## Project Structure & Module Organization

This repository contains a cross-platform Nushell configuration. `env.nu` sets the editor, paths, platform-specific dependencies, and generated integrations; `config.nu` loads the prompt, zoxide data, and discovered modules. Keep command aliases in `aliases/<command>/mod.nu` and completion definitions in `completions/`. `sources-generator.nu` discovers installed commands and generates `.sources.nu`. Prompt configuration lives in `oh-my-posh/themes/`, while `vendor/autoload/` contains generated startup scripts.

Files such as `.sources.nu`, `.zoxide.nu`, `history.txt`, and most runtime files are intentionally ignored. Do not add machine-specific output or credentials.

## Development and Validation Commands

There is no build step or automated test suite. Use Nushell itself for validation:

```sh
nu --ide-check 100 config.nu
nu --ide-check 100 env.nu
nu --ide-check 100 aliases/git/mod.nu
nu --ide-check 100 completions/arc-completions/mod.nu
nu -c 'use aliases/git *; scope aliases | where name == ga'
```

`nu --ide-check` reports parser diagnostics without starting the full interactive configuration. The final command smoke-tests module exports. To exercise the complete setup, launch `nu` in an environment where `carapace`, `oh-my-posh`, and `zoxide` may be installed; note that `env.nu` can attempt platform-specific installations and regenerate files.

## Coding Style & Naming Conventions

Use four-space indentation for Nushell blocks and pipelines, and keep related pipelines split across readable lines. Prefer `snake_case` for definitions and variables, uppercase `SCREAMING_SNAKE_CASE` for path constants, and short conventional prefixes for aliases (`g*` for Git, `a*` for Arc). Export commands intended for interactive use. Keep alias groups alphabetized and add brief comments where external-command behavior is non-obvious. Quote paths and use `$nu.config-path` or `$nu.data-dir` instead of hard-coded user directories.

## Testing Guidelines

Run syntax checks on every changed `.nu` file. For aliases or completions, load the module in a clean `nu -c` invocation and test both normal output and missing-tool behavior. Verify platform branches carefully when changing `env.nu`; contributors should avoid assuming macOS-only paths apply on Linux or Windows.

## Commit & Pull Request Guidelines

Recent history follows Conventional Commit-style subjects, primarily `feat:` and `fix:` (for example, `fix: align arc aliases and completions with real arc behavior`). Use an imperative, concise subject and keep each commit focused. Pull requests should explain the user-visible shell behavior, list tested operating systems and Nushell version, include validation commands, and link relevant issues. Add screenshots only for prompt/theme changes.
