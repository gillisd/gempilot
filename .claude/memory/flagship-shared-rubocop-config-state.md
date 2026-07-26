---
name: flagship-shared-rubocop-config-state
description: "Status of issue 79AE436E (shared RuboCop config + eject) — designed 2026-07-20, not yet built"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8ab20c6a-4c03-4f0a-9acd-e12099699ad8
---

The flagship **79AE436E** ("own shared RuboCop config via `inherit_gem` + eject hatch") is **designed but not implemented** as of 2026-07-20. Design spec committed at `docs/superpowers/specs/2026-07-20-shared-rubocop-config-eject-design.md` on branch `file-issue-own-shared-config` (that branch = the flagship WIP: issue-filing commit + design doc only; the 6 backlog fixes that were briefly on it shipped separately via PR #20 and are now in master).

Approved direction: `inherit_gem`; gempilot ships `config/rubocop/{base,minitest,rspec}.yml`; generated `.rubocop.yml` shrinks to near-zero (gem-name excludes become globs `*.gemspec`/`lib/*-*.rb`; drop `TargetRubyVersion` since RuboCop reads it from the gemspec's `required_ruby_version`); new `gempilot eject` inlines config + cuts the link; generated Gemfile pins gempilot.

Before/while building: **(1) OPEN decision** — CI-break mitigation policy; **pin** is the recommended default but David has NOT confirmed it. **(2) First step is a SPIKE** — verify RuboCop loads `plugins:` (rubocop-claude etc.) *through* an `inherit_gem` config; if not, the plugins list stays in the local file. See [[gempilot-generated-gem-rubocop-gate]].

Other open backlog item: **741FFD05** (reduce deps). The gemspec's 4 runtime deps (`command_kit`, `rake`, `warning`, `zeitwerk`) are all used — leave them; reduction is purely Gemfile dev deps. Recommended: drop `benchmark`/`observer`/`rbs`; keep `irb`/`repl_type_completor` (bin/console), `rdoc` (docs), `debug`. (`warning` is the one narrow runtime dep — only silences the VERSION-reload warnings in `Project#fetch_version`.)
