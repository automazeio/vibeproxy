# Known Issues

- Canonical VibeProxy is detached and reports no branch, so this pass does not
  integrate into canonical.
- Older `vibeproxy-wtrees/sladge-badge` is stale and dirty due an unrelated
  workflow modification.
- `make test` is blocked before source compilation because SwiftPM and clang
  cannot access or write user cache paths in this sandbox:
  `~/Library/org.swift.swiftpm`, `~/Library/Caches/org.swift.swiftpm`, and
  `~/.cache/clang/ModuleCache`.
