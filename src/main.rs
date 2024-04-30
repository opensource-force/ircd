use std::sync::Arc;

use tokio::sync::RwLock;
use tokio::net::{ TcpListener, TcpStream };
use tokio::io::AsyncReadExt;

const ADDR: &str = "192.168.1.11";
const PORT: &str = "6667";

#[derive(Clone)]
struct Client {
    nick: String,
    user: String,
    host: String,
    server: String,
    real: String,
    got_nick: bool,
    got_user: bool,
    registered: bool
}

struct Server {
    clients: Arc<RwLock<Vec<Client>>>
}

impl Server {
    fn new() -> Self { Self { clients: Arc::new(RwLock::new(Vec::new())) } }

    async fn run(self) -> Result<(), Box<dyn std::error::Error>> {
        let listener = TcpListener::bind(format!("{ADDR}:{PORT}")).await?;

        loop {
            let (socket, _) = listener.accept().await?;
            let client = Client::new();

            let clients = self.clients.clone();

            tokio::spawn(client.handler(socket, clients));
        }
    }
}

impl Client {
    fn new() -> Self {
        Self {
            nick: String::new(),
            user: String::new(),
            host: String::new(),
            server: String::new(),
            real: String::new(),
            got_nick: false,
            got_user: false,
            registered: false
        }
    }

    async fn handler(self, mut socket: TcpStream, clients: Arc<RwLock<Vec<Client>>>) {
        println!("Client socket opened!");
    
        // add client
        let mut clients_guard = clients.write().await;
        clients_guard.push(self.clone());

        println!("{} sockets open", clients_guard.len());

        drop(clients_guard);
        //

        let mut buf = [0; 1024];

        loop {
            let n = match socket.read(&mut buf).await {
                Ok(n) if n == 0 => {
                    // drop client
                    let mut clients_guard = clients.write().await;

                    println!("Client {} closed socket. {} sockets remain", self.nick, clients_guard.len());
                    clients_guard.retain(|c| c.nick != self.nick);

                    drop(clients_guard);  // just in case drop the guard even if it returns afterward.
                    return;
                }
                Ok(n) => n,
                Err(e) => {
                    eprintln!("Failed to read from socket. Error: {:?}", e);
                    return;
                }
            };
    
            let bytes = &buf[0..n];
            let stream = String::from_utf8_lossy(bytes);
    
            for line in stream.lines() {
                let client = self.clone();
                client.msg_handler(line).await;
            }
        }
    }
    
    async fn msg_handler(mut self, line: &str) {
        println!("Command: {}", line);
    
        let parts: Vec<&str> = line.split(':').collect();
        let args: Vec<&str> = parts[0].split_whitespace().collect();
        let cmd = args[0].to_string();
        let params: Vec<String> = args[1..].iter().map(|&s| s.to_string()).collect();
        let context = parts[1..].join(" ");
    
        match cmd.as_str() {
            "PASS" => {} // no password
            "NICK" => {
                self.nick = params[0].clone();
                //client.hopcount = params[1];
    
                if !self.nick.is_empty() {
                    self.got_nick = true;
                }
            }
            "USER" => {
                self.user = params[0].clone();
                self.host = params[1].clone();
                self.server = params[2].clone();
                self.real = context.clone();
    
                if params.len() > 2 && !context.is_empty() {
                    self.got_user = true;
                }
            }
            _ => println!("Invalid command: {}", cmd)
        }
    
        if !self.registered && self.got_nick && self.got_user {
            println!("{} registered!", self.nick);
            self.registered = true;
        }
    }    
}

#[tokio::main]
async fn main() {
    let server = Server::new();
    
    server.run().await.unwrap();
}