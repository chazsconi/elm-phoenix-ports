module Phoenix.Push exposing
    ( Push
    , init, withPayload, onOk, onError, onTimeout, map
    )

{-| A message to push informations to a channel.


# Definition

@docs Push


# Helpers

@docs init, withPayload, onOk, onError, onTimeout, map

-}

import Json.Encode exposing (Value)


{-| The message abstraction
-}
type alias Push msg =
    PhoenixPush msg


type alias PhoenixPush msg =
    { topic : String
    , event : String
    , payload : Value
    , onOk : Maybe (Value -> msg)
    , onError : Maybe (Value -> msg)
    , onTimeout : Maybe msg
    }


type alias Topic =
    String


type alias Event =
    String


{-| Initialize a message with a topic and an event.

    init "room:lobby" "new_msg"

-}
init : Topic -> Event -> Push msg
init topic event =
    PhoenixPush topic event (Json.Encode.object []) Nothing Nothing Nothing


{-| Attach a payload to a message

    payload =
        Json.Encode.object [("msg", "Hello Phoenix")]

    init "room:lobby" "new_msg"
        |> withPayload

-}
withPayload : Value -> Push msg -> Push msg
withPayload payload push =
    { push | payload = payload }


{-| Callback if the server replies with an "ok" status.

    type Msg = MessageArrived | ...

    payload =
        Json.Encode.object [("msg", "Hello Phoenix")]

    init "room:lobby" "new_msg"
        |> withPayload
        |> onOk (\_ -> MessageArrived)

-}
onOk : (Value -> msg) -> Push msg -> Push msg
onOk cb push =
    { push | onOk = Just cb }


{-| Callback if the server replies with an "error" status.

    type Msg = MessageFailed Value | ...

    payload =
        Json.Encode.object [("msg", "Hello Phoenix")]

    init "room:lobby" "new_msg"
        |> withPayload
        |> onError MessageFailed

-}
onError : (Value -> msg) -> Push msg -> Push msg
onError cb push =
    { push | onError = Just cb }


{-| Callback if the push times-out.

    type Msg = MessageTimeout | ...

    payload =
        Json.Encode.object [("msg", "Hello Phoenix")]

    init "room:lobby" "new_msg"
        |> withPayload
        |> onTimeout MessageTimeout

-}
onTimeout : msg -> Push msg -> Push msg
onTimeout cb push =
    { push | onTimeout = Just cb }


{-| Applies the function on the onOk, onError and onTimeout callbacks
-}
map : (a -> b) -> Push a -> Push b
map func push =
    let
        f =
            Maybe.map ((<<) func)
    in
    { topic = push.topic, event = push.event, payload = push.payload, onOk = f push.onOk, onError = f push.onError, onTimeout = Maybe.map func push.onTimeout }
