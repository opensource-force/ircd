use crate::client::Client;

#[derive(Clone)]
pub struct Channel {
    pub name: String,
    pub clients: Vec<Client>,
}

impl Channel {
    pub fn new(name: &str) -> Self {
        Self {
            clients: Vec::new(),
            name: name.to_string()
        }
    }

    pub fn join(&mut self, client: &Client) {
        if !self.clients.iter().any(|c| c.addr == client.addr) {
            self.clients.push(client.clone());

            println!("{} joined channel '{}'", client.nickname, self.name);
        }
    }
}