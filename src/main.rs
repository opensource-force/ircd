use std::sync::Arc;

use tokio::{
    io::{
        AsyncBufReadExt,
        AsyncWriteExt,
        BufReader
    },
    net::{
        TcpListener,
        TcpStream
    },
    sync::{broadcast::{self, Sender}, Mutex}
};

#[derive(Clone)]
struct Client {
    addr: String,
    tx: Sender<(String, String)>,
    nickname: String,
    hopcount: u8,
    got_nick: bool,
    username: String,
    hostname: String,
    servername: String,
    realname: String,
    got_user: bool,
    registered: bool
}

impl Client {
    fn new(addr: String, tx: Sender<(String, String)>) -> Self {
        Self {
            addr,
            tx,
            nickname: String::new(),
            hopcount: 0,
            got_nick: false,
            username: String::new(),
            hostname: String::new(),
            servername: String::new(),
            realname: String::new(),
            got_user: false,
            registered: false
        }
    }

    fn nick_msg(&mut self, params: Vec<String>) {
        if !params.is_empty() {
            self.nickname = params[0].clone();
            self.got_nick = true;
        }
        
        if params.len() > 1 {
            self.hopcount = params[1].parse::<u8>().unwrap_or(0);
        }
    }

    fn user_msg(&mut self, prefix: String, params: Vec<String>) {
        match params.as_slice() {
            [user, host, server, ..] => {
                self.username = user.clone();
                self.hostname = host.clone();
                self.servername = server.clone();
        
                if !prefix.is_empty() {
                    self.realname = prefix;
                    self.got_user = true;
                }
            }
            _ => {}
        }
    }

    fn try_register(&mut self) {
        if self.got_nick && self.got_user && !self.registered {
            println!("{} registered as {}", self.addr, self.nickname);
            self.registered = true;
        }
    }
}

#[derive(Clone)]
struct Server {
    addr: String,
    clients: Vec<Client>
}

impl Server {
    fn new() -> Self {
        Self {
            addr: String::new(),
            clients: Vec::new()
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

    async fn accept(
        this: Arc<Mutex<Server>>,
        mut client: Client,
        socket: TcpStream
    ) {
        let mut rx = client.tx.subscribe();
        let (reader, mut writer) = socket.into_split();
        let mut reader = BufReader::new(reader);
        let mut buf = String::new();

        { this.lock().await.add_client(client.clone()); }

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
                        let parts: Vec<&str> = line.split(':').collect();
                        let args: Vec<&str> = parts[0].split_whitespace().collect();
                        let prefix = parts[1..].join(" ");
                        let cmd = args[0];
                        let params: Vec<String> = args[1..].iter().map(|s| s.to_string()).collect();
                        
                        match cmd {
                            "PASS" => {}
                            "NICK" => client.nick_msg(params),
                            "USER" => client.user_msg(prefix, params),
                            _ => {}
                        }

                        client.try_register();
                    }

                    /*
                    if addr == SOME_addr || addr == this.lock().await.addr {
                        writer.write(line.as_bytes()).await.unwrap();
                        writer.flush().await.unwrap();
                    }
                    */
                }
            }
        }
    }

    async fn run(self, listen_addr: &str) {
        let listener = TcpListener::bind(listen_addr).await.unwrap();
        let (tx, _) = broadcast::channel(10);
        let this = Arc::new(Mutex::new(self));

        { this.lock().await.addr = listen_addr.to_string(); }

        println!("Listening on {}", listen_addr);

        loop {
            let this = Arc::clone(&this);
            let (socket, addr) = listener.accept().await.unwrap();
            let client = Client::new(addr.to_string(), tx.clone());

            tokio::spawn(Self::accept(this, client, socket));
        }
    }
}

#[tokio::main]
async fn main() {
    let server = Server::new();

    server.run("192.168.1.56:6667").await;
}