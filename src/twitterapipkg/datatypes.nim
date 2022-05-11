type

  ReqType* {.pure.} = enum

    Get, Tweet, Put, Delete

  ParamType* {.pure.} = enum

    UserParam, TweetParam, SearchParam

  TimeLineParams* = object

    case kind*: ParamType

    of UserParam:

      screen_name*: string
    of TweetParam:

      userId*: string
      include_tweet_replies*, withSuperFollowsTweetFields*, withCommunity*,
        withDownvotePerspective*, withReactionsMetadata*, withReactionsPerspective*,
        includePromotedContent*, withVoice*, withV2Timeline*: bool
    of SearchParam:
      
      q*, tweet_search_mode*, query_source*, result_filter* : string
      pc*, spelling_corrections* : int

    include_profile_interstitial_type*, include_blocking*, include_blocked_by*,
      include_followed_by*, include_want_retweets*, include_mute_edge*, include_can_dm*,
      include_can_media_tag*, skip_status*, include_cards*, include_reply_count*,
      include_ext_has_nft_avatar*, count* : int

    include_composer_source*, include_entities*, include_user_entities*, include_ext_media_color*,
      send_error_codes*, simple_quoted_tweet*, include_quote_count*, withSuperFollowsUserFields*: bool

    cards_platform*, tweet_mode*: string

  ## Datatypes for user and tweet objects
  MinUser = object

    screen_name*, name*, id_str* : string
    indices* : seq[int]

  Url = object

    display_url*, expanded_url*, url* : string
    indices* : seq[int]

  EntityObj = object

    urls* : seq[Url]

  Entity = object

    description*, url* : EntityObj
    hashtags*, symbols* : seq[string]
    user_mentions* : seq[MinUser]

  ## Datatypes for user object
  User* = object

    rest_id*, created_at*, description*, location*, name*, profile_image_url_https*, profile_interstitial_type*, 
      screen_name*, translator_type*, url* : string
    default_profile*, default_profile_image*, has_custom_timelines*, is_translator*, protected*, verified* : bool
    fast_followers_count*, favourites_count*, followers_count*, friends_count*, media_count*, normal_followers_count*, statuses_count* : int
    withheld_in_countries* : seq[string]
    entities* : Entity

  ## Datatypes for tweet object
  Tweet* = object

    created_at*, conversation_id_str*, full_text*, lang*, user_id_str*, id_str*, in_reply_to_status_id_str*, 
      in_reply_to_user_id_str*, in_reply_to_screen_name* : string
    favorite_count*, quote_count*, reply_count*, retweet_count* : int
    favorited*, is_quote_status*, possibly_sensitive*, possibly_sensitive_editable*, retweeted* : bool
    entities* : Entity
