mod channel;
mod client;
mod server;
mod configuration;

use crate::server::Server;
use crate::configuration::Configuration;

#[tokio::main]
async fn main() {
    let config = Configuration::new(String::from("config/config.toml"));
    let server = Server::new(config.load().await);

    server.run().await;
}