use std::sync::Arc;
use crate::channel::Channel;
use crate::client::Client;

use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{TcpListener, TcpStream},
    sync::{broadcast::{self, Sender}, Mutex}
};

#[derive(Clone)]
pub struct Server {
    pub addr: String,
    port: String, 
    clients: Vec<Client>,
    pub channels: Vec<Channel>
}

impl Server {
    pub fn new(addr: String, port: String) -> Self {
        Self {
            addr,
            port,
            clients: Vec::new(),
            channels: Vec::new()
        }
    }

    fn add_client(&mut self, client: Client) {
        self.clients.push(client.clone());

        println!("Socket opened by {}", client.addr);
        println!("{} sockets open", self.clients.len());
    }

    fn drop_client(&mut self, client: Client) {
        self.clients.retain(|c| c.addr != client.addr);

        println!("Socket closed by {}", client.addr);
        println!("{} sockets remain", self.clients.len());
    }

    async fn handle(
        this: Arc<Mutex<Server>>,
        mut client: Client,
        socket: TcpStream
    ) {
        let mut rx = client.tx.subscribe();
        let (reader, mut writer) = socket.into_split();
        let mut reader = BufReader::new(reader);
        let mut buf = String::new();

        { this.lock().await.add_client(client.clone()); }
        client.server = Arc::clone(&this);

        loop {
            tokio::select! {
                stream = reader.read_line(&mut buf) => {
                    if stream.unwrap() == 0 {
                        { this.lock().await.drop_client(client); }
                        break;
                    }

                    client.tx.send((buf.clone(), client.addr.clone())).unwrap();
                    buf.clear();
                }
                stream = rx.recv() => {
                    let (line, addr) = stream.unwrap();

                    if addr == client.addr {
                        writer.write(line.as_bytes()).await.unwrap();
                        writer.flush().await.unwrap();

                        let parts: Vec<&str> = line.split(':').collect();
                        let args: Vec<&str> = parts[0].split_whitespace().collect();
                        let prefix = parts[1..].join(" ");
                        if let Some(cmd) = args.get(0) {
                            let params: Vec<String> = args[1..].iter().map(|s| s.to_string()).collect();
                            
                            match *cmd {
                                "PASS" => {}
                                "NICK" => client.nick_msg(params),
                                "USER" => client.user_msg(prefix, params).await,
                                "JOIN" => client.join_msg(params).await,
                                _ => {}
                            }
                        }

                        client.try_register();
                    }
                }
            }
        }
    }

    async fn accept(self, listener: TcpListener, tx: Sender<(String, String)>) {
        let this = Arc::new(Mutex::new(self));

        loop {
            let this = Arc::clone(&this);
            let (socket, addr) = listener.accept().await.unwrap();
            let client = Client::new(Arc::clone(&this), addr.to_string(), tx.clone());

            tokio::spawn(Self::handle(this, client, socket));
        }
    }

    pub async fn run(self) {
        let listen_addr = format!("{}:{}", self.addr, self.port);
        let listener = TcpListener::bind(&listen_addr).await.unwrap();
        let (tx, _) = broadcast::channel(10);

        println!("Listening on {}", listen_addr);

        self.accept(listener, tx).await;
    }
}