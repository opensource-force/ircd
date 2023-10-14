import strutils, strformat
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
  
  echo(args)

# setNick
# Received the NICK command
proc setNick(c: Client, args: seq[string]) =
  if args.len == 0:
    errNeedMoreParams(c)
    return
  
  c.nickname = args[0]
  c.gotNick = true

  echo(args)

# setUser
# Received the USER command
proc setUser(c: Client, args: seq[string], message: string) =
  echo fmt"arg0: {args[0]}"
  echo fmt"arg1: {args[1]}"
  echo fmt"message: {message}"
  if c.registered:
    return
  
  if args.len < 4:
    errNeedMoreParams(c)
    return
  
  c.username = args[0]
  c.hostname = args[1]
  c.realname = message
  c.gotUser = true

  echo(args)

# joinChannel
# Received the JOIN command
proc joinChannel(c: Client, args: seq[string]) =
  echo "JOIN not implemented yet."

# privMessage
# Received the PRIVMSG command
proc privMessage(c: Client, args: seq[string], message: string) =
  # TODO: Need to finish this
  echo fmt"got a message with text: {message} from {args[0]}"
  let sender = fmt"{c.nickname}!{c.username}@{c.hostname}"
  let recipient = getClientByNickname(args[0])

  if recipient.isNil:
    return

  let msg = fmt":{sender} PRIVMSG {recipient.nickname} :{message}"


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