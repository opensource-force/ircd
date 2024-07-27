use tokio::fs;
use serde_derive::Deserialize;

#[derive(Clone)]
pub struct Configuration {
    path: String,
}

impl Configuration {
    pub fn new(path: String) -> Self {
        Self {
            path
        }
    }

    pub async fn load(&self) -> Config {
        let config_str = fs::read_to_string(&self.path).await.unwrap();
        let config: Config = toml::from_str(&config_str).unwrap();

        config
    }
}

#[derive(Debug, Deserialize, Clone)]
pub struct Config { 
    pub server: ServerConfig,
    pub messages: Messages,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ServerConfig {
    pub addr: String,
    pub port: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Messages {
    pub welcome: String,
}