
use crate::channel::Channel;
use crate::server::Server;

use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::sync::broadcast::Sender;

#[derive(Clone)]
pub struct Client {
    pub addr: String,
    pub server: Arc<Mutex<Server>>,
    pub tx: Sender<(String, String)>,
    pub nickname: String,
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
    pub fn new(server: Arc<Mutex<Server>>, addr: String, tx: Sender<(String, String)>) -> Self {
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

    pub fn send_msg(&self, msg: String) {
        self.tx.send((msg, self.addr.clone())).unwrap();
    }

    pub fn nick_msg(&mut self, params: Vec<String>) {
        if !params.is_empty() {
            self.nickname = params[0].clone();
            self.got_nick = true;
        }
        
        if params.len() > 1 {
            self.hopcount = params[1].parse::<u8>().unwrap_or(0);
        }
    }

    pub async fn user_msg(&mut self, prefix: String, params: Vec<String>) {
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
        let rpl_welcome = format!(":{} 001 {} :{}\r\n", 
            server.addr, self.nickname, &server.config.messages.welcome);
        self.send_msg(rpl_welcome);

        // 002 (RPL_YOURHOST): Information about the server.
        let rpl_yourhost = format!(":{} 002 {} :Your host is {}, running version {}\r\n", 
            server.addr, self.nickname, server.addr, env!("CARGO_PKG_VERSION"));
        self.send_msg(rpl_yourhost);

        // 003 (RPL_CREATED): The server creation date.
        //let rpl_created = format!(":{} 003 {} :This server was last built {}\r\n", 
        //    server.addr, self.nickname, std::env::var("BUILD_DATE").unwrap_or_else(|_| String::from("unknown")));
        //self.send_msg(rpl_created);
        
        // 004 (RPL_MYINFO): Server details including supported modes.
        //let rpl_myinfo = format!(":{} 004 {} {} {} {} {}\r\n", 
        //    server.addr, self.nickname, server.addr, env!("CARGO_PKG_VERSION"), "OQRSZaghilsvb", "CFILPQbcefgijklmnopqrstvz");
        //self.tx.send((rpl_myinfo, self.addr.clone())).unwrap();

        // 005 (RPL_ISUPPORT): Server capabilities such as channel types, prefixes, and channel modes.
        //let rpl_isupport = format!(":{} 005 {} PREFIX=(ov)@+ CHANTYPES=#& :are supported by this server\r\n", 
        //    server.addr, self.nickname);
        //self.tx.send((rpl_isupport, self.addr.clone())).unwrap();

    }

    pub async fn join_msg(&self, params: Vec<String>) {
        let channel_names: Vec<&str> = params[0].split(',').collect();
        let mut server = self.server.lock().await;

        for name in channel_names {
            if !server.channels.iter().any(|c| c.name == name) {
                let mut channel = Channel::new(name);
                server.channels.push(channel.clone());

                channel.join(self);

                // send join message (RPL_JOIN)
                let rpl_join = format!(":{} JOIN :{}\r\n", self.nickname, name);
                self.send_msg(rpl_join);
                
                // send topic (RPL_TOPIC)
                let rpl_topic = format!(":{} 332 {} {} :No topic is set\r\n", server.addr, self.nickname, name);
                self.send_msg(rpl_topic);
                
                // send list of clients in channel (RPL_NAMREPLY)
                let nicklist = channel.clients.iter().map(|c| c.nickname.clone()).collect::<Vec<String>>().join(" ");
                let rpl_namreply = format!(":{} 353 {} = {} :{}\r\n", 
                    server.addr, self.nickname, channel.name, nicklist);
                self.send_msg(rpl_namreply);

                // RPL_ENDOFNAMES
                let rpl_endofnames = format!(":{} 366 {} {} :End of /NAMES list\r\n", 
                    server.addr, self.nickname, channel.name);
                self.send_msg(rpl_endofnames);
            }
        }

        drop(server);
    }

    pub fn try_register(&mut self) {
        if self.got_nick && self.got_user && !self.registered {
            println!("{} registered as {}", self.addr, self.nickname);
            self.registered = true;
        }
    }
}