import parseopt, logging, httpclient, twitterapipkg / [api]
from os import commandLineParams, getAppFilename
from strutils import split, strip, parseInt
from strformat import fmt
from sequtils import foldl
from options import isSome, get
from json import pretty
from std / jsonutils import toJson

let logger = newConsoleLogger(fmtStr = "$levelname :: [$datetime] ")
logger.addHandler()

when isMainModule and not defined(js):

  type

    Action {.pure.} = enum
      GetUser, GetUserTweets, SearchUsers, SearchTweets, None

  ## Get and parse cmd parameters
  let
    cmdparams = commandLineParams()
    appname = getAppFilename().split("/")[^1]
    help = fmt"""
      {appname}

      Usage:

        {appname} [options] [argument]

      Options:

        --user     | -u:username              Username for get user information and tweets
        --count    | -c:count limit           Count limit for when getting tweets or searching
        --keyword  | -k:search keyword        Search keyword for searching
        --output   | -o:output file           Path to output file to store output. When not given print output to stdout
        --help     | -h                       Print this help message
      
      Arguments:

        {GetUser}                               Get user information. Requires option user
        {GetUserTweets}                         Get user tweets. Requires option user and count
        {SearchUsers}                           Search for users. Requires option keyword and count
        {SearchTweets}                          Search for tweets. Requires option keyword and count"""

  if cmdparams.len != 0:

    var 
      run_info : tuple[user, keyword, output : string, count : int, action : Action] = ("", "", "", 10, None)
      params = initOptParser(cmdparams.foldl("{a} {b}".fmt))

    while true:

      params.next()
      case params.kind

      of cmdEnd: break

      of cmdShortOption, cmdLongOption:
                
        if params.key == "user" or params.key == "u":

          run_info.user = params.val
        elif params.key == "count" or params.key == "c":

          try:

            run_info.count = params.val.parseInt
          except ValueError:

            fatal("Option count has a non numerical value")
            info("Quiting..")
            quit(-1)
        elif params.key == "keyword" or params.key == "k":

          run_info.keyword = params.val
        elif params.key == "output" or params.key == "o":
            
          run_info.output = params.val
        elif params.key == "help" or params.key == "h":

          for line in help.split("\n"):

            stdout.writeLine line.strip
          
          quit(0)

      of cmdArgument:

        case params.key

        of $GetUser:

          run_info.action = GetUser
        of $GetUserTweets:

          run_info.action = GetUserTweets
        of $SearchUsers:

          run_info.action = SearchUsers
        of $SearchTweets:

          run_info.action = SearchTweets
        else:

          debug(fmt"Unsupported argument {params.key}")
          info("Quiting...")
          quit(-1)

    var client = newHttpClient(timeout = 3000)
    client.setReqHeaders()
    case run_info.action

    of GetUser:

      let user = client.getUser(run_info.user)
      if user.isSome:

        let data = user.get.toJson.pretty
        if run_info.output.len == 0:

          for line in data.split('\n'):

            stdout.writeLine(line)
        else:

          writeFile(run_info.output, data)

    of GetUserTweets:

      let user = client.getUser(run_info.user)
      if user.isSome:

        let 
          tweet = client.getUserTweets(user.get, run_info.count)
          data = tweet.toJson.pretty
        if run_info.output.len == 0:

          for line in data.split('\n'):

            stdout.writeLine(line)
        else:

          writeFile(run_info.output, data)
      else:

        debug(fmt"Cannot find user {run_info.user}")

    of SearchUsers:

      if run_info.keyword.len != 0:

        let 
          users = client.searchUsers(run_info.keyword, run_info.count)
          data = users.toJson.pretty

        if run_info.output.len == 0:

          for line in data.split('\n'):

            stdout.writeLine(line)
        else:

          writeFile(run_info.output, data)
      else:

        debug("Keyword option is not given")

    of SearchTweets:

      if run_info.keyword.len != 0:

        let 
          tweets = client.searchTweets(run_info.keyword, run_info.count)
          data = tweets.toJson.pretty

        if run_info.output.len == 0:

          for line in data.split('\n'):

            stdout.writeLine(line)
        else:

          writeFile(run_info.output, data)
      else:

        debug("Keyword option is not given")

    else:

      discard

  else:

    for line in help.split("\n"):

      stdout.writeLine line.strip

    quit(0)