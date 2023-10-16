import strformat, strutils
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

# joinedChannel
# Channel is available, user is joining
proc joinedChannel(c: Client, ch: ChatChannel) =
  echo fmt"Joined {ch.name}"
  ch.clients.add(c)
  discard sendTopic(c, ch)
  discard sendNames(c, ch)

# joinChannel
# Received the JOIN command
proc joinChannel(c: Client, args: seq[string]) =
  let channelName = args[0]
  echo fmt"User {c.nickname} joining channel {channelName}"
  var channel: ChatChannel = getChannelByName(channelName)
  if channel.isNil:
    channel = createChannel(channelName)
  
  if channel.isNil:
    echo "Couldn't create channel"
    return

  joinedChannel(c, channel)

# sendMessageToChannel
# Sends a message to a channel
proc sendMessageToChannel(c: Client, sender: string, target: string, message: string) =
  let channel = getChannelByName(target)
  if channel.isNil:
    echo "TODO: didn't find channel"
    return

  let outMsg = fmt":{sender} PRIVMSG {target} :{message}"
  echo outMsg

# sendMessageToUser
# Sends a mesage to a user
proc sendMessageToUser(c: Client, sender: string, target: string, message: string) =
  let recipient = getClientbyNickname(target)
  
  if recipient.isNil:
    echo "TODO: didn't find recipient"
    return

  let outMsg = fmt":{sender} PRIVMSG {recipient.nickname} :{message}"
  echo fmt"Sending: {outMsg} to {recipient.nickname}"
  discard sendClient(recipient, outMsg)

# privMessage
# Received the PRIVMSG command
proc privMessage(c: Client, args: seq[string], message: string) =
  echo fmt"got message with text: {message} from {args[0]}"
  let sender = fmt"{c.nickname}!{c.username}@{c.hostname}"
  let target = args[0]

  if target.startsWith('#'): 
    sendMessageToChannel(c, sender, target, message)
  else:
    sendMessageToUser(c, sender, target, message)

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