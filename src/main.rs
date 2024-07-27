mod channel;
mod client;
mod server;

use crate::server::Server;

#[tokio::main]
async fn main() {
    let addr = String::from("192.168.0.202");
    let port = String::from("6668");
    let server = Server::new(addr, port);

    server.run().await;
}