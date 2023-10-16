import strformat
import ./data
import ./helpers

# setPass
# Received the PASS command
proc setPass(c: Client, args: seq[string]) =
  if c.registered:
    errAlreadyRegistered(c)
    return

  if args.len == 0:
    errNeedMoreParams(c)
    return

  c.gotPass = true
  c.timestamp = getEpochTime()

  echo(fmt"{c.timestamp}: {args}")

# setNick
# Received the NICK command
proc setNick(c: Client, args: seq[string]) =
  if args.len == 0:
    errNeedMoreParams(c)
    return
  
  c.nickname = args[0]
  c.gotNick = true
  c.timestamp = getEpochTime()

  echo(fmt"{c.timestamp}: {args}")

# setUser
# Received the USER command
proc setUser(c: Client, args: seq[string], message: string) =
  if c.registered:
    return
  
  if args.len < 3:
    errNeedMoreParams(c)
    return
  
  c.username = args[0]
  c.hostname = args[1]
  c.realname = message
  c.gotUser = true
  c.timestamp = getEpochTime()

  echo(fmt"{c.timestamp}: {args}")

# joinChannel
# Received the JOIN command
proc joinChannel(c: Client, args: seq[string]) =
  echo "JOIN not implemented yet."

  c.timestamp = getEpochTime()

# privMessage
# Received the PRIVMSG command
proc privMessage(c: Client, args: seq[string], message: string) =
  echo fmt"got message with text: {message}"
  let sender = fmt"{c.nickname}!{c.username}@{c.hostname}"
  let recipient = getClientByNickname(args[0])

  if recipient.isNil:
    echo "didn't find recipient"
    return

  let msg = fmt":{sender} PRIVMSG {recipient.nickname} :{message}"
  echo fmt"sending: {msg} to {recipient.nickname}"
  discard sendClient(recipient, msg)

  c.timestamp = getEpochTime()

# cmdHandler
# Handles incoming commands from Client sockets.
proc cmdHandler*(c: Client, command: string, args: seq[string], message: string) =
  # Handle pre-registration commands
  case command:
  of "PASS": setPass(c, args)
  of "NICK": setNick(c, args)
  of "USER": setUser(c, args, message)

  if c.gotPass and c.gotNick and c.gotUser and c.registered == false:
    c.registered = true
    
    echo(fmt"{c.nickname} Registered!")
    discard sendMotd(c)
    discard sendLuser(c)
  
  # Handle post-registration commands
  case command:
  of "JOIN": joinChannel(c, args)
  of "PRIVMSG": privMessage(c, args, message)