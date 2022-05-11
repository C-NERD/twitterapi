import httpclient, logging, datatypes
from zippy import CompressedDataFormat, uncompress
from strformat import fmt
from re import findAll, re
from uri import encodeUrl, decodeUrl
from sequtils import concat, anyIt
from net import TimeoutError
from tables import `[]`, `[]=`, TableRef, hasKey
from options import Option, some
from strutils import split, strip, format, toLowerAscii, parseInt, removeSuffix
from json import `$`, `{}`, parseJson, JsonNode, getStr, getElems, hasKey, pairs
from std / jsonutils import toJson, fromJson, Joptions

const
  COOKIEURL = "https://twitter.com"
  USERINFOURL = "https://api.twitter.com/graphql/7mjxD3-C6BxitPMVQ6w0-Q/UserByScreenName?variables=$1"
  USERTWEETURL = "https://api.twitter.com/graphql/Vg5aF036K40ST3FWvnvRGA/UserTweetsAndReplies?variables=$1"
  SEARCHUSERS = "https://twitter.com/i/api/2/search/adaptive.json?$1"
  SEARCHTWEETS = "https://twitter.com/i/api/2/search/adaptive.json?$1"

## Client setup code
template requestWrapper(client : HttpClient, url, body, status: string, headers: TableRef[string, seq[string]],
    reqtype : ReqType = Get, action: untyped) =

  var attempts {.inject.} : int 

  ## If request TIMEOUT try again 5 times
  while true:

    try:

      var resp : Response
      case reqtype:

      of ReqType.Get:

        resp = client.get(url)
      of ReqType.Tweet:

        resp = client.post(url, body)
        body = ""
      else:

        discard
      
      headers = resp.headers.table
      status = resp.status

      if headers.hasKey("content-encoding"):

        if headers["content-encoding"].anyIt(it == "gzip"):

          body = uncompress(resp.body, dfGzip)
        elif headers["content-encoding"].anyIt(it == "deflate"):

          body = uncompress(resp.body, dfDeflate)
        else:

          error(fmt"""User content is encoded as {headers["content-encoding"]}""")
          quit(-1)
      else:

        body = resp.body

      action
      break
    
    except TimeoutError:

      if attempts < 5:

        error("Request TIMEOUT, trying again...")
        attempts.inc()
        continue
      
      fatal(fmt"Request TIMEOUT after {attempts} attempts, quitting..")
      quit(-1)

proc genParams(kind: ParamType): TimeLineParams =

  result = TimeLineParams(
    include_profile_interstitial_type: 0,
    include_blocking: 0,
    include_blocked_by: 0,
    include_followed_by: 0,
    include_want_retweets: 0,
    include_mute_edge: 0,
    include_can_dm: 0,
    include_can_media_tag: 1,
    include_ext_has_nft_avatar: 1,
    skip_status: 1,
    cards_platform: "Web-12",
    include_cards: 1,
    include_composer_source: false,
    include_reply_count: 1,
    tweet_mode: "extended",
    include_entities: true,
    include_user_entities: true,
    include_ext_media_color: false,
    send_error_codes: true,
    simple_quoted_tweet: true,
    include_quote_count: true,
    withSuperFollowsUserFields: true,
    kind: kind
  )

proc paramsToQuery(params : TimeLineParams) : string =

  for name, value in params.fieldPairs:

    when name != "kind":

      result.add("$1=$2&".format(name, $value))
  
  result.removeSuffix('&')
  #result = result.encodeUrl

proc setReqHeaders*(client : var HttpClient) =

  info("Pinging Twitter")
  var
    body, status: string
    headers: TableRef[string, seq[string]]
  requestWrapper client, COOKIEURL, body, status, headers, Get:

    proc getCookies(): seq[string] {.closure.} =

      info("Getting cookies")
      for header in headers["set-cookie"]:

        result.add(header.split(';')[0])

      if result.len == 0:

        fatal("Twitter didn't respond with cookies")

    proc getGuestToken(): tuple[ascookies, asheader: seq[string]] {.closure.} =

      result.ascookies = body.findAll(re(r"gt=(\d+)"))
      for each in result.ascookies:

        result.asheader.add(each.split("=")[1])

      if result.asheader.len == 0:

        fatal("Could not find guest token")

    let token = getGuestToken()
    client.headers.table["connection"] = @["keep-alive"]
    client.headers.table["authorization"] = @["Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"]
    client.headers.table["content-type"] = @["application/json"]
    client.headers.table["x-guest-token"] = token.asheader
    client.headers.table["x-twitter-active-user"] = @["yes"]
    client.headers.table["authority"] = @["api.twitter.com"]
    client.headers.table["accept-encoding"] = @["gzip, deflate"]
    client.headers.table["accept-language"] = @["en-US,en;q=0.5"]
    client.headers.table["cookie"] = getCookies().concat(token.ascookies)
    client.headers.table["accept"] = @["*/*"]
    client.headers.table["DNT"] = @["1"]

## Twitter api code
proc getUser*(client : HttpClient, username : string) : Option[User] =

  ## Get twitter user's information with username
  info("Getting $1 user information".format([username]))
  var
    variables = genParams(kind = UserParam)
    body, status: string
    headers: TableRef[string, seq[string]]

  variables.screen_name = username.toLowerAscii
  requestWrapper client, USERINFOURL.format(encodeUrl($(variables.toJson))), body, status, headers, Get:

    if status == "200 OK":

      try:

        var user : User
        let resultdict = parseJson(body){"data", "user", "result"}

        user.rest_id = resultdict{"rest_id"}.getStr("")
        user.fromJson(resultdict{"legacy"}, opt = Joptions(allowExtraKeys : true, allowMissingKeys : true))
        result = some(user)
      except Exception as e:

        fatal(e.msg)
    else:

      debug(fmt"Twitter responded with {status} when getting User")

proc getUserTweets*(client : HttpClient, user : User, count : int = 10, replies : bool = false) : seq[Tweet] =

  ## Get twitter user's posts
  info(fmt"Getting {user.name} tweets with a count of {count}")
  var
    variables = genParams(kind = TweetParam)
    body, status: string
    headers: TableRef[string, seq[string]]

  variables.userId = user.rest_id
  variables.count = count
  variables.include_tweet_replies = replies
  variables.withSuperFollowsTweetFields = true
  requestWrapper client, USERTWEETURL.format(encodeUrl($(variables.toJson))), body, status, headers, Get:

    if status == "200 OK":

      try:

        let userinfoJson = parseJson(body)
        var posts : JsonNode

        for instruction in userinfoJson{"data", "user", "result", "timeline", "timeline", "instructions"}.getElems:

          if instruction.hasKey("entries"):

            posts = instruction{"entries"}
            break

        for post in posts.getElems:

          var tweet : Tweet
          let resultdict = post{"content", "itemContent", "tweet_results", "result", "legacy"}
          
          tweet.fromJson(resultdict, opt = Joptions(allowExtraKeys : true, allowMissingKeys : true))
          result.add(tweet)

      except Exception as e:

        fatal(e.msg)
    else:

      debug(fmt"Twitter responded with {status} when getting tweets from user {user.name}")

proc searchUsers*(client : HttpClient, keyword : string, count : int = 10) : seq[User] =

  ## Search twitter for users
  info(fmt"Searching for users with keyword {keyword} and a count of {count}")
  var
    variables = genParams(kind = SearchParam)
    body, status: string
    headers: TableRef[string, seq[string]]

  variables.q = keyword
  #variables.tweet_search_mode = "live"
  variables.result_filter = "user"
  variables.query_source = "typed_query"
  variables.pc = 1
  variables.spelling_corrections = 1
  variables.count = count
  requestWrapper client, SEARCHUSERS.format(paramsToQuery(variables)), body, status, headers, Get:

    if status == "200 OK":

      try:

        for key, val in (parseJson(body){"globalObjects", "users"}).pairs:

          var user : User
          user.fromJson(val, opt = Joptions(allowExtraKeys : true, allowMissingKeys : true))

          result.add(user)

      except Exception as e:

        fatal(e.msg)
    else:

      debug(fmt"Twitter responded with {status} when searching for user {keyword}")

proc searchTweets*(client : HttpClient, keyword : string, count : int = 10) : seq[Tweet] =

  ## Search twitter for users
  info(fmt"Searching for tweets with keyword {keyword} and a count of {count}")
  var
    variables = genParams(kind = SearchParam)
    body, status: string
    headers: TableRef[string, seq[string]]

  variables.q = keyword
  variables.tweet_search_mode = "live"
  #variables.result_filter = "user"
  variables.query_source = "typed_query"
  variables.pc = 1
  variables.spelling_corrections = 1
  variables.count = count
  requestWrapper client, SEARCHTWEETS.format(paramsToQuery(variables)), body, status, headers, Get:

    if status == "200 OK":

      try:

        for key, val in (parseJson(body){"globalObjects", "tweets"}).pairs:

          var tweet : Tweet
          tweet.fromJson(val, opt = Joptions(allowExtraKeys : true, allowMissingKeys : true))

          result.add(tweet)

      except Exception as e:

        fatal(e.msg)
    else:

      debug(fmt"Twitter responded with {status} when searching for tweets with the keyword {keyword}")

