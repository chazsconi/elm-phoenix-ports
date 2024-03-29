module Phoenix.Channel exposing
    ( Channel
    , Topic
    , init, withPayload, on, onDisconnect, onJoin, onRejoin, onRequestJoin, onJoinError, onJoinTimeout, onError, onLeave, onLeaveError, onLeaveTimeout, withDebug, withPresence, map
    )

{-| A channel declares which topic should be joined, registers event handlers and has various callbacks for possible lifecycle events.


# Definition

@docs Channel
@docs Topic


# Helpers

@docs init, withPayload, on, onDisconnect, onJoin, onRejoin, onRequestJoin, onJoinError, onJoinTimeout, onError, onLeave, onLeaveError, onLeaveTimeout, withDebug, withPresence, map

-}

import Dict exposing (Dict)
import Json.Decode exposing (Value)
import Phoenix.Presence as Presence exposing (Presence)



-- CHANNEL


{-| Representation of a Phoenix Channel
-}
type alias Channel msg =
    PhoenixChannel msg


{-| Topic of channel
-}
type alias Topic =
    String


type alias PhoenixChannel msg =
    { topic : Topic
    , payload : Maybe Value
    , onRequestJoin : Maybe msg
    , onJoin : Maybe (Value -> msg)
    , onJoinError : Maybe (Value -> msg)
    , onJoinTimeout : Maybe msg
    , onDisconnect : Maybe msg
    , onError : Maybe msg
    , onRejoin : Maybe (Value -> msg)
    , onLeave : Maybe (Value -> msg)
    , onLeaveError : Maybe (Value -> msg)
    , onLeaveTimeout : Maybe msg
    , on : Dict String (Value -> msg)
    , presence : Maybe (Presence msg)
    , debug : Bool
    }


{-| Initialize a channel to a given topic.

    init "room:lobby"

-}
init : Topic -> Channel msg
init topic =
    { topic = topic
    , payload = Nothing
    , onRequestJoin = Nothing
    , onJoin = Nothing
    , onJoinError = Nothing
    , onJoinTimeout = Nothing
    , onDisconnect = Nothing
    , onError = Nothing
    , onRejoin = Nothing
    , onLeave = Nothing
    , onLeaveError = Nothing
    , onLeaveTimeout = Nothing
    , on = Dict.empty
    , presence = Nothing
    , debug = False
    }


{-| Attach a payload to the join message. You can use this to submit e.g. a user id or authentication infos. This will be the second argument in your `join/3` callback on the server.

    payload =
        Json.Encode.object [("user_id", "123")]

    init "room:lobby"
        |> withPayload payload

-}
withPayload : Value -> Channel msg -> Channel msg
withPayload payload_ chan =
    { chan | payload = Just payload_ }


{-| Register an event handler for a event.

    type Msg = NewMsg Value | ...

    init "roomy:lobby"
        |> on "new_msg" NewMsg

-}
on : String -> (Value -> msg) -> Channel msg -> Channel msg
on event cb chan =
    { chan | on = Dict.insert event cb chan.on }


{-| Set a callback which will be called after you request to join the channel.

    type Msg =
        JoinLobbyRequested

    init "room:lobby"
        |> onRequestJoin JoinLobbyRequested

-}
onRequestJoin : msg -> Channel msg -> Channel msg
onRequestJoin onRequestJoin_ chan =
    { chan | onRequestJoin = Just onRequestJoin_ }


{-| Set a callback which will be called after you sucessfully joined the channel. It will also be called after you rejoined the channel after a disconnect unless you specified an `onRejoin` handler.

    type Msg =
        IsOnline Json.Encode.Value | ...

    init "room:lobby"
        |> onJoin IsOnline

-}
onJoin : (Value -> msg) -> Channel msg -> Channel msg
onJoin onJoin_ chan =
    case chan.onRejoin of
        Nothing ->
            { chan | onJoin = Just onJoin_, onRejoin = Just onJoin_ }

        Just _ ->
            { chan | onJoin = Just onJoin_ }


{-| Set a callback which will be called if the server declined your request to join the channel.

    type Msg =
        CouldNotJoin Json.Encode.Value | ...

    init "room:lobby"
        |> onJoinError CouldNotJoin

**Note**: If a channel declined a request to join a topic the effect manager won\_t try again.

-}
onJoinError : (Value -> msg) -> Channel msg -> Channel msg
onJoinError onJoinError_ chan =
    { chan | onJoinError = Just onJoinError_ }


{-| Set a callback which will be called if a timeout occurred on your request to join the channel.

    type Msg =
        JoinTimeout | ...

    init "room:lobby"
        |> onJoinTimeout JoinTimeout

-}
onJoinTimeout : msg -> Channel msg -> Channel msg
onJoinTimeout onJoinTimeout_ chan =
    { chan | onJoinTimeout = Just onJoinTimeout_ }


{-| Set a callback which will be called if the channel process on the server crashed. The effect manager will automatically rejoin the channel after a crash.

    type Msg =
         ChannelCrashed | ...

    init "room:lobby"
        |> onError ChannelCrashed

-}
onError : msg -> Channel msg -> Channel msg
onError onError_ chan =
    { chan | onError = Just onError_ }


{-| NOT YET IMPLEMENTED - Set a callback which will be called if the socket connection got interrupted. Useful to switch the online status to offline.

    type Msg =
        IsOffline | ...

    init "room:lobby"
        |> onDisconnect IsOffline

**Note**: The effect manager will automatically try to reconnect to the server and to rejoin the channel. See `onRejoin` for details.

-}
onDisconnect : msg -> Channel msg -> Channel msg
onDisconnect onDisconnect_ chan =
    { chan | onDisconnect = Just onDisconnect_ }


{-| NOT YET IMPLEMENTED - Set a callback which will be called after you sucessfully rejoined the channel after a disconnect. Useful if you want to catch up missed messages.

    type Msg =
        IsOnline Json.Encode.Value | ...

    init "room:lobby"
        |> onRejoin IsOnline

-}
onRejoin : (Value -> msg) -> Channel msg -> Channel msg
onRejoin onRejoin_ chan =
    { chan | onRejoin = Just onRejoin_ }


{-| Set a callback which will be called after you sucessfully left a channel.

    type Msg =
        LeftLobby Json.Encode.Value | ...

    init "room:lobby"
        |> onLeave LeftLobby

-}
onLeave : (Value -> msg) -> Channel msg -> Channel msg
onLeave onLeave_ chan =
    { chan | onLeave = Just onLeave_ }


{-| Set a callback which will be called if the server declined your request to left a channel.
_(It seems that Phoenix v1.2 doesn_t send this)\_
-}
onLeaveError : (Value -> msg) -> Channel msg -> Channel msg
onLeaveError onLeaveError_ chan =
    { chan | onLeaveError = Just onLeaveError_ }


{-| Set a callback which will be called if a timeout occurred on your request to leave the channel.

    type Msg =
        LeaveTimeout | ...

    init "room:lobby"
        |> onLeaveTimeout LeaveTimeout

-}
onLeaveTimeout : msg -> Channel msg -> Channel msg
onLeaveTimeout onLeaveTimeout_ chan =
    { chan | onLeaveTimeout = Just onLeaveTimeout_ }


{-| Set a callback which will be called when there is a change in the presence state caused by "presence\_state" and "presence\_diff" events.

    type Msg =
        PresenceChange (Dict String (List Json.Encode.Value)) | ...

    init "room:lobby"
        |> onPresenceChange PresenceChange

-}
withPresence : Presence msg -> Channel msg -> Channel msg
withPresence presence chan =
    { chan | presence = Just presence }


{-| Composes each callback with the function `a -> b`.
-}
map : (a -> b) -> Channel a -> Channel b
map func chan =
    let
        f =
            Maybe.map ((<<) func)

        channel =
            { topic = chan.topic
            , payload = chan.payload
            , onRequestJoin = Maybe.map func chan.onRequestJoin
            , onJoin = f chan.onJoin
            , onJoinError = f chan.onJoinError
            , onJoinTimeout = Maybe.map func chan.onJoinTimeout
            , onError = Maybe.map func chan.onError
            , onDisconnect = Maybe.map func chan.onDisconnect
            , onRejoin = f chan.onRejoin
            , onLeave = f chan.onLeave
            , onLeaveError = f chan.onLeaveError
            , onLeaveTimeout = Maybe.map func chan.onLeaveTimeout
            , presence = Maybe.map (Presence.map func) chan.presence
            , on = Dict.map (\_ a -> func << a) chan.on
            , debug = chan.debug
            }
    in
    channel


{-| Print all status changes.
-}
withDebug : Channel msg -> Channel msg
withDebug channel =
    { channel | debug = True }
