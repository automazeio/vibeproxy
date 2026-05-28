# VibeProxy Documentation

VibeProxy is a cross-platform proxy application with Rust core library, macOS Swift app, and Windows WinUI3 app.

## Quick Navigation

- **[setup/](setup/)** - Installation and setup guides
- **[architecture/](architecture/)** - Architecture and design
- **[guides/](guides/)** - How-to guides and tutorials
- **[reference/](reference/)** - Reference materials and changelogs

## Getting Started

### Installation

See [setup/INSTALLATION.md](setup/INSTALLATION.md) for platform-specific installation instructions.

### Development Setup

See [setup/DEV_SETUP.md](setup/DEV_SETUP.md) for development environment setup.

### Factory Setup

See [setup/FACTORY_SETUP.md](setup/FACTORY_SETUP.md) for factory configuration.

### Injection Setup

See [setup/INJECT_SETUP.md](setup/INJECT_SETUP.md) for injection setup.

## Architecture

- **[Monorepo Migration](architecture/MONOREPO_MIGRATION.md)** - Monorepo structure and migration
- **[Services Configuration](architecture/SERVICES_CONFIG.md)** - Service configuration details

## Guides

- **[Windows UI](guides/WINDOWS_UI.md)** - Windows UI implementation
- **[Dual Router](guides/DUAL_ROUTER.md)** - Dual router implementation

## Reference

- **[Changelog](reference/CHANGELOG.md)** - Version history
- **[Fork Attribution](reference/FORK_ATTRIBUTION.md)** - Attribution and credits
- **[Migration Complete](reference/MIGRATION_COMPLETE.md)** - Migration status
- **[Completion Summary](reference/COMPLETION_SUMMARY.md)** - Project completion summary

## Project Structure

```
vibeproxy/
├── README.md                 # Main README
├── docs/                     # Documentation
│   ├── README.md            # This file
│   ├── setup/               # Setup guides
│   ├── architecture/        # Architecture docs
│   ├── guides/              # How-to guides
│   └── reference/           # Reference materials
├── src/                     # Rust source
├── apps/                    # Platform apps
│   ├── macos/              # macOS Swift app
│   └── windows/            # Windows WinUI3 app
└── shared/                 # Shared code
```

## Support

For issues and questions, see the main README.md in the project root.

