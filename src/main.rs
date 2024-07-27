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
struct Channel {
    clients: Vec<Client>,
    name: String
}

impl Channel {
    fn new(name: &str) -> Self {
        Self {
            clients: Vec::new(),
            name: name.to_string()
        }
    }

    fn join(&mut self, client: &Client) {
        if !self.clients.iter().any(|c| c.addr == client.addr) {
            self.clients.push(client.clone());

            println!("{} joined channel '{}'", client.nickname, self.name);
        }
    }
}

#[derive(Clone)]
struct Client {
    server: Arc<Mutex<Server>>,
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
    fn new(server: Arc<Mutex<Server>>, addr: String, tx: Sender<(String, String)>) -> Self {
        Self {
            server,
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

    async fn user_msg(&mut self, prefix: String, params: Vec<String>) {
        let server = self.server.lock().await;

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

        // Send responses 
        // 001 (RPL_WELCOME): Welcome message.
        let rpl_welcome = format!(":{} 001 {} :Welcome to the Internet Relay Network {}\r\n", 
            server.addr, self.nickname, self.nickname);
        self.tx.send((rpl_welcome, self.addr.clone())).unwrap();

        // 002 (RPL_YOURHOST): Information about the server.
        let rpl_yourhost = format!(":{} 002 {} :Your host is {}, running version {}\r\n", 
            server.addr, self.nickname, server.addr, env!("CARGO_PKG_VERSION"));
        self.tx.send((rpl_yourhost, self.addr.clone())).unwrap();

        // 003 (RPL_CREATED): The server creation date.
        let rpl_created = format!(":{} 003 {} :This server was last built {}\r\n", 
            server.addr, self.nickname, std::env::var("BUILD_DATE").unwrap_or_else(|_| String::from("unknown")));
        self.tx.send((rpl_created, self.addr.clone())).unwrap();
        
        // 004 (RPL_MYINFO): Server details including supported modes.
        let rpl_myinfo = format!(":{} 004 {} {} {} {} {}\r\n", 
            server.addr, self.nickname, server.addr, env!("CARGO_PKG_VERSION"), "OQRSZaghilsvb", "CFILPQbcefgijklmnopqrstvz");
        self.tx.send((rpl_myinfo, self.addr.clone())).unwrap();

        // 005 (RPL_ISUPPORT): Server capabilities such as channel types, prefixes, and channel modes.
        let rpl_isupport = format!(":{} 005 {} PREFIX=(ov)@+ CHANTYPES=#& :are supported by this server\r\n", 
            server.addr, self.nickname);
        self.tx.send((rpl_isupport, self.addr.clone())).unwrap();

    }

    async fn join_msg(&self, params: Vec<String>) {
        let channel_names: Vec<&str> = params[0].split(',').collect();
        let mut server = self.server.lock().await;

        for name in channel_names {
            if !server.channels.iter().any(|c| c.name == name) {
                let mut channel = Channel::new(name);
                server.channels.push(channel.clone());

                channel.join(self);

                // send join message (RPL_JOIN)
                let rpl_join = format!(":{} JOIN :{}\r\n", self.nickname, name);
                self.tx.send((rpl_join, self.addr.clone())).unwrap();
                
                // send topic (RPL_TOPIC)
                let rpl_topic = format!(":{} 332 {} {} :No topic is set\r\n", server.addr, self.nickname, name);
                self.tx.send((rpl_topic, self.addr.clone())).unwrap();

                // send list of clients in channel (RPL_NAMREPLY)
                let nicklist = channel.clients.iter().map(|c| c.nickname.clone()).collect::<Vec<String>>().join(" ");
                let rpl_namreply = format!(":{} 353 {} = {} :{}\r\n", 
                    server.addr, self.nickname, channel.name, nicklist);
                self.tx.send((rpl_namreply, self.addr.clone())).unwrap();

                // RPL_ENDOFNAMES
                let rpl_endofnames = format!(":{} 366 {} {} :End of /NAMES list\r\n", 
                    server.addr, self.nickname, channel.name);
                self.tx.send((rpl_endofnames, self.addr.clone())).unwrap();
            }
        }

        drop(server);
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
    port: String, 
    clients: Vec<Client>,
    channels: Vec<Channel>
}

impl Server {
    fn new(addr: String, port: String) -> Self {
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

    async fn run(self) {
        let listen_addr = format!("{}:{}", self.addr, self.port);
        let listener = TcpListener::bind(&listen_addr).await.unwrap();
        let (tx, _) = broadcast::channel(10);

        println!("Listening on {}", listen_addr);

        self.accept(listener, tx).await;
    }
}

#[tokio::main]
async fn main() {
    let addr = String::from("192.168.1.56");
    let port = String::from("6667");
    let server = Server::new(addr, port);

    server.run().await;
}