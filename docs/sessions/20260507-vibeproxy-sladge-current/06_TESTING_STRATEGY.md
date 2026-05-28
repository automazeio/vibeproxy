# Testing Strategy

Completed checks:

- `git diff --check`: passed.
- README/session badge search with `rg`: passed.

Blocked checks:

- `make test`: blocked by SwiftPM/clang user-cache permission errors before
  source compilation.
