module Phoenix.PortsAPI exposing (..)

import Json.Encode as JE
import Phoenix.Channel exposing (Topic)
import Phoenix.ChannelStates exposing (ChannelObj)
import Phoenix.Types exposing (..)


{-| Defines the API for the ports that are required to interface with JS

The real ports are defined in PhoenixPorts

-}
type alias ChannelMsg =
    ( Topic, Event, JE.Value )


type alias OnHandlers =
    { onOk : Bool, onError : Bool, onTimeout : Bool }


type alias JoinParams =
    { topic : Topic, payload : JE.Value, onHandlers : OnHandlers, presence : Bool }


type alias PushParams =
    { ref : Int, channel : ChannelObj, event : Event, payload : JE.Value, onHandlers : OnHandlers }


type alias PushReply =
    { eventName : String, topic : Topic, pushType : String, ref : Maybe Int, payload : JE.Value }


type alias ConnectParams =
    { endpoint : String, params : JE.Value }


type alias SocketCloseParams =
    { code : Int, reason : String, wasClean : Bool }


type alias PresenceUpdate =
    { eventName : String, topic : Topic, presences : List ( String, List JE.Value ) }


{-| Functions that need to implemented by Ports
-}
type alias Ports msg =
    { channelMessage : (( Topic, String, JE.Value ) -> msg) -> Sub msg
    , pushReply : (PushReply -> msg) -> Sub msg
    , channelsCreated : (List ( Topic, ChannelObj ) -> msg) -> Sub msg
    , channelError : (Topic -> msg) -> Sub msg
    , socketOpened : (() -> msg) -> Sub msg
    , socketClosed : (SocketCloseParams -> msg) -> Sub msg
    , presenceUpdated : (PresenceUpdate -> msg) -> Sub msg
    , connectSocket : ConnectParams -> Cmd msg
    , joinChannels : List JoinParams -> Cmd msg
    , leaveChannel : ChannelObj -> Cmd msg
    , pushChannel : PushParams -> Cmd msg
    }
