module Phoenix.PortsAPI exposing
    ( Ports
    , ChannelMsg, OnHandlers, JoinParams, PushParams, PushReply, ConnectParams, SocketCloseParams, PresenceUpdate
    )

{-| Defines the API for the ports that are required to interface with JS.

This is just an internal implementation, but exposed so the types are available via
the implementation of the ports in `PhoenixPorts` (which must be installed via NPM). See `README.md`
for details.


# External Ports API

This is the API that the ports module must implement.

@docs Ports


# Internal types

These types are used internally to communicate between Elm and the JS ports code.

@docs ChannelMsg, OnHandlers, JoinParams, PushParams, PushReply, ConnectParams, SocketCloseParams, PresenceUpdate

-}

import Json.Encode as JE
import Phoenix.Channel exposing (Topic)
import Phoenix.Internal.ChannelStates exposing (ChannelObj)
import Phoenix.Internal.Types exposing (Event, Msg)


{-| Message from a channel
-}
type alias ChannelMsg =
    ( Topic, Event, JE.Value )


{-| Handlers to invoke on a push
-}
type alias OnHandlers =
    { onOk : Bool, onError : Bool, onTimeout : Bool }


{-| Channel join params
-}
type alias JoinParams =
    { topic : Topic, payload : JE.Value, onHandlers : OnHandlers, presence : Bool }


{-| Push params
-}
type alias PushParams =
    { ref : Int, channel : ChannelObj, event : Event, payload : JE.Value, onHandlers : OnHandlers }


{-| Push reply params
-}
type alias PushReply =
    { eventName : String, topic : Topic, pushType : String, ref : Maybe Int, payload : JE.Value }


{-| Socket connect params
-}
type alias ConnectParams =
    { endpoint : String, params : JE.Value }


{-| Socket closed params
-}
type alias SocketCloseParams =
    { code : Int, reason : String, wasClean : Bool }


{-| Presence update reply params
-}
type alias PresenceUpdate =
    { eventName : String, topic : Topic, presences : List ( String, List JE.Value ) }


{-| Functions that need to implemented by Ports
-}
type alias Ports msg =
    { channelMessage : (( Topic, String, JE.Value ) -> Msg msg) -> Sub (Msg msg)
    , pushReply : (PushReply -> Msg msg) -> Sub (Msg msg)
    , channelsCreated : (List ( Topic, ChannelObj ) -> Msg msg) -> Sub (Msg msg)
    , channelError : (Topic -> Msg msg) -> Sub (Msg msg)
    , socketOpened : (() -> Msg msg) -> Sub (Msg msg)
    , socketClosed : (SocketCloseParams -> Msg msg) -> Sub (Msg msg)
    , presenceUpdated : (PresenceUpdate -> Msg msg) -> Sub (Msg msg)
    , connectSocket : ConnectParams -> Cmd (Msg msg)
    , joinChannels : List JoinParams -> Cmd (Msg msg)
    , leaveChannel : ChannelObj -> Cmd (Msg msg)
    , pushChannel : PushParams -> Cmd (Msg msg)
    }
