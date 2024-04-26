use tokio::net::{ TcpListener, TcpStream };
use tokio::io::AsyncReadExt;

const ADDR: &str = "192.168.1.11";
const PORT: &str = "6667";

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

    async fn handler(mut self, mut socket: TcpStream) {
        println!("Client socket opened!");

        let mut buf = [0; 1024];

        loop {
            let n = match socket.read(&mut buf).await {
                Ok(n) if n == 0 => {
                    println!("Client {} closed socket", self.nick);
                    return;
                }
                Ok(n) => n,
                Err(e) => {
                    eprintln!("Failed to read from socket. Error: {:?}", e);
                    return;
                }
            };
    
            let bytes = &buf[0..n];
            let stream = String::from_utf8(bytes.to_vec()).unwrap();
    
            for line in stream.lines() {
                msg_handler(line, &mut self).await;
            }
        }
    }
}

async fn msg_handler(line: &str, client: &mut Client) {
    println!("Command: {}", line);

    let parts: Vec<&str> = line.split(':').collect();
    let args: Vec<&str> = parts[0].split_whitespace().collect();
    let cmd = args[0].to_string();
    let params: Vec<String> = args[1..].iter().map(|&s| s.to_string()).collect();
    let context = parts[1..].join(" ");

    match cmd.as_str() {
        "PASS" => {} // no password
        "NICK" => {
            client.nick = params[0].clone();
            //client.hopcount = params[1];
    
            if !client.nick.is_empty() {
                client.got_nick = true;
            }
        }
        "USER" => {
            client.user = params[0].clone();
            client.host = params[1].clone();
            client.server = params[2].clone();
            client.real = context.clone();
    
            if params.len() > 2 && !context.is_empty() {
                client.got_user = true;
            }
        }
        _ => println!("Invalid command: {}", cmd)
    }
    
    if !client.registered && client.got_nick && client.got_user {
        println!("{} registered!", client.nick);

        client.registered = true;
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let listener = TcpListener::bind(format!("{ADDR}:{PORT}")).await?;

    loop {
        let (socket, _) = listener.accept().await?;
        let client = Client::new();

        tokio::spawn(async move {
            client.handler(socket).await;
        });
    }
}