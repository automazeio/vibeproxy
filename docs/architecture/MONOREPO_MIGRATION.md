# VibeProxy Monorepo Migration Guide

## ✅ Completed

### Phase 1: Directory Structure
- ✅ Created monorepo structure:
  - `apps/macos/` - macOS Swift app
  - `apps/windows/` - Windows WinUI3 app (placeholder)
  - `apps/linux/` - Linux GTK4 app (placeholder)
  - `shared/core/` - Rust library with FFI
  - `shared/bindings/` - Platform-specific bindings
  - `proto/` - Protocol definitions
  - `scripts/` - Build scripts

### Phase 2: Shared Core (Rust)
- ✅ Created `shared/core/Cargo.toml` with dependencies
- ✅ Created `shared/core/src/lib.rs` with:
  - `BackendConfig` - Bifrost backend configuration
  - `SLMConfig` - SLM server configuration
  - `TunnelConfig` - Cloudflare tunnel configuration
  - `AppConfig` - Main application configuration
  - `BackendClient` - HTTP client for bifrost-enhanced
  - `SLMClient` - HTTP client for SLM server
  - FFI functions for C bindings

### Phase 3: macOS App Migration
- ✅ Created `apps/macos/Package.swift` (updated from original)
- ✅ Existing Swift source files remain in `apps/macos/Sources/`
- ⚠️ **TODO**: Update imports to use shared core bindings

### Phase 4: Build Scripts
- ✅ Created `scripts/build-all.sh` - Build all platforms
- ✅ Created `scripts/build-macos.sh` - Build macOS only
- ⚠️ **TODO**: Create `scripts/build-windows.ps1`
- ⚠️ **TODO**: Create `scripts/build-linux.sh`

### Phase 5: Swift Bindings
- ✅ Created `shared/bindings/swift/VibeProxyCore.swift`
- ⚠️ **TODO**: Test Swift bindings integration
- ⚠️ **TODO**: Update macOS app to use shared core

## 🔜 Next Steps

### Immediate (High Priority)
1. **Test Rust Core Build**
   ```bash
   cd shared/core
   cargo build
   cargo test
   ```

2. **Generate C Headers**
   ```bash
   cd shared/core
   cargo build  # This runs build.rs and generates bindings/c/vibeproxy_core.h
   ```

3. **Update macOS App**
   - Import `VibeProxyCore` in Swift files
   - Replace direct HTTP calls with `BackendClient`
   - Use `AppConfig` from shared core

### Short Term (Medium Priority)
4. **Windows App Setup**
   - Create WinUI3 project structure
   - Create C# bindings for Rust core
   - Implement main window and tray icon

5. **Linux App Setup** (Optional)
   - Create GTK4 project structure
   - Use C bindings directly
   - Implement system tray

### Long Term (Low Priority)
6. **Protocol Buffers**
   - Generate Go/TypeScript code from `proto/config.proto`
   - Use for cross-language configuration sync

7. **CI/CD**
   - GitHub Actions for macOS build
   - GitHub Actions for Windows build
   - GitHub Actions for Linux build

## Migration Checklist

- [x] Create monorepo directory structure
- [x] Create Rust shared core library
- [x] Create Swift bindings
- [x] Create build scripts
- [x] Create protocol definitions
- [ ] Move macOS app source files (in progress)
- [ ] Update macOS app to use shared core
- [ ] Test macOS build
- [ ] Create Windows app structure
- [ ] Create C# bindings
- [ ] Create Linux app structure (optional)
- [ ] Update documentation

## File Locations

### Before (Old Structure)
```
vibeproxy/
├── src/
│   ├── Package.swift
│   └── Sources/
│       ├── main.swift
│       ├── ServerManager.swift
│       └── ...
```

### After (New Structure)
```
vibeproxy/
├── apps/
│   └── macos/
│       ├── Package.swift
│       └── Sources/
│           ├── main.swift
│           ├── ServerManager.swift
│           └── ...
├── shared/
│   ├── core/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── lib.rs
│   └── bindings/
│       └── swift/
│           └── VibeProxyCore.swift
└── scripts/
    ├── build-all.sh
    └── build-macos.sh
```

## Notes

- The original `src/` directory should be removed after migration is complete
- All platform-specific code should be in `apps/{platform}/`
- All shared logic should be in `shared/core/`
- FFI bindings are platform-specific but generated from shared core
