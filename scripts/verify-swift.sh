#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../src"
swift build
swift test
mkdir -p .build/verification
common=(Sources/ConfigComposer.swift Sources/CustomProviders.swift Sources/ProviderCatalog.swift)
swiftc "${common[@]}" Verification/ConfigComposerSpec.swift -o .build/verification/config-composer
swiftc Sources/ConfigInputFingerprint.swift Verification/ConfigInputFingerprintSpec.swift -o .build/verification/config-fingerprint
swiftc "${common[@]}" Sources/CustomProviderCredentialStore.swift Verification/CustomProviderCredentialStoreSpec.swift -o .build/verification/custom-credentials
swiftc "${common[@]}" Sources/ZAIAPIKeyStore.swift Verification/ZAIAPIKeyStoreSpec.swift -o .build/verification/zai-credentials
for spec in .build/verification/*; do "$spec"; done
