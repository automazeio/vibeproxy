//! Keyring integration using secret-service (libsecret)

use anyhow::{Context, Result};
use secret_service::{Collection, EncryptionType, SecretService};
use std::collections::HashMap;
use tracing::{error, info, warn};

const SERVICE_NAME: &str = "vibeproxy";
const COLLECTION_NAME: &str = "default";

pub struct Keyring {
    service: SecretService,
    collection: Collection<'static>,
}

impl Keyring {
    pub fn new() -> Result<Self> {
        info!("Initializing keyring");

        // Connect to secret service
        let service = SecretService::connect(EncryptionType::Dh)
            .context("Failed to connect to secret service")?;

        // Get default collection
        let collection = service
            .get_default_collection()
            .context("Failed to get default collection")?;

        // Unlock collection if needed
        if collection.is_locked().unwrap_or(false) {
            collection
                .unlock()
                .context("Failed to unlock keyring collection")?;
        }

        info!("Keyring initialized successfully");

        Ok(Self {
            service,
            collection,
        })
    }

    /// Store a secret in the keyring
    pub fn store(&self, key: &str, value: &str) -> Result<()> {
        info!("Storing secret: {}", key);

        let label = format!("{}/{}", SERVICE_NAME, key);
        let attributes = HashMap::from([
            ("service", SERVICE_NAME),
            ("key", key),
        ]);

        // Create or update item
        match self.collection.search_items(attributes.clone()) {
            Ok(mut items) => {
                if let Some(item) = items.pop() {
                    // Update existing item
                    item.set_secret(value.as_bytes(), "text/plain")
                        .context("Failed to update secret")?;
                    info!("Updated existing secret: {}", key);
                } else {
                    // Create new item
                    self.collection
                        .create_item(&label, attributes, value.as_bytes(), "text/plain", true)
                        .context("Failed to create secret")?;
                    info!("Created new secret: {}", key);
                }
            }
            Err(e) => {
                warn!("Search failed, creating new item: {}", e);
                self.collection
                    .create_item(&label, attributes, value.as_bytes(), "text/plain", true)
                    .context("Failed to create secret")?;
            }
        }

        Ok(())
    }

    /// Retrieve a secret from the keyring
    pub fn retrieve(&self, key: &str) -> Result<Option<String>> {
        info!("Retrieving secret: {}", key);

        let attributes = HashMap::from([
            ("service", SERVICE_NAME),
            ("key", key),
        ]);

        match self.collection.search_items(attributes) {
            Ok(mut items) => {
                if let Some(item) = items.pop() {
                    let secret = item.get_secret().context("Failed to get secret")?;
                    let value = String::from_utf8(secret)
                        .context("Secret is not valid UTF-8")?;
                    info!("Retrieved secret: {}", key);
                    Ok(Some(value))
                } else {
                    info!("Secret not found: {}", key);
                    Ok(None)
                }
            }
            Err(e) => {
                error!("Failed to search for secret: {}", e);
                Ok(None)
            }
        }
    }

    /// Delete a secret from the keyring
    pub fn delete(&self, key: &str) -> Result<()> {
        info!("Deleting secret: {}", key);

        let attributes = HashMap::from([
            ("service", SERVICE_NAME),
            ("key", key),
        ]);

        match self.collection.search_items(attributes) {
            Ok(mut items) => {
                for item in items {
                    item.delete().context("Failed to delete secret")?;
                }
                info!("Deleted secret: {}", key);
            }
            Err(e) => {
                warn!("Failed to search for secret to delete: {}", e);
            }
        }

        Ok(())
    }

    /// List all stored keys
    pub fn list_keys(&self) -> Result<Vec<String>> {
        let attributes = HashMap::from([("service", SERVICE_NAME)]);

        match self.collection.search_items(attributes) {
            Ok(items) => {
                let keys: Vec<String> = items
                    .iter()
                    .filter_map(|item| {
                        item.get_attributes()
                            .ok()?
                            .get("key")
                            .cloned()
                    })
                    .collect();
                Ok(keys)
            }
            Err(e) => {
                error!("Failed to list keys: {}", e);
                Ok(vec![])
            }
        }
    }
}

impl Default for Keyring {
    fn default() -> Self {
        Self::new().expect("Failed to initialize keyring")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_keyring_operations() {
        let keyring = Keyring::new().expect("Failed to create keyring");

        // Test store and retrieve
        keyring
            .store("test_key", "test_value")
            .expect("Failed to store secret");
        let value = keyring
            .retrieve("test_key")
            .expect("Failed to retrieve secret");
        assert_eq!(value, Some("test_value".to_string()));

        // Test delete
        keyring
            .delete("test_key")
            .expect("Failed to delete secret");
        let value = keyring
            .retrieve("test_key")
            .expect("Failed to retrieve secret");
        assert_eq!(value, None);
    }
}
