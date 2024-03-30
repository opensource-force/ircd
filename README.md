<div align="center">
<h1>OSFIRCd :speech_balloon:</h1>
<p>A super minimal IRC server written in Nim</p>
<a href='#'><img src="https://img.shields.io/badge/Made%20with-Nim-&?style=flat-square&labelColor=232329&color=FFE953&logo=nim"/></a>
<a href='#'><img src="https://img.shields.io/badge/Maintained%3F-Yes-green.svg?style=flat-square&labelColor=232329&color=5277C3"></img></a>
<br/>
<a href='#'><img src="https://img.shields.io/github/size/opensource-force/ircd/osfircd.nim?branch=main&color=%231DBF73&label=Size&logo=files&logoColor=%231DBF73&style=flat-square&labelColor=232329"/></a>
<br/>
<a href="https://discord.gg/W4mQqNnfSq">
<img src="https://discordapp.com/api/guilds/913584348937207839/widget.png?style=shield"/></a>
</div>

## Acquisition
Using Docker
```docker
docker compose up -d
docker compose down
```

Compiling from source
```bash
git clone https://github.com/opensource-force/ircd; cd ircd/
```

```bash
nim c osfircd.nim
```

## Execution
Execute client from within downloaded directory
```bash
./osfircd
```
---

## Implementation
Messages:
- `PASS <password>`
- `NICK <nickname> [hopcount]`
- `USER <username> <hostname> <servername> <:realname>`

Other features:
- Client registration

## Contributing
Contributions are much appreciated! We are always looking to improve the IRCd and welcome contributions from anyone!

See the [STYLE GUIDE](./STYLE_GUIDE.MD)

Join us on [Discord](https://discord.gg/W4mQqNnfSq)