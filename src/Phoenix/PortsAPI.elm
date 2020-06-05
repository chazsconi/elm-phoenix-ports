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
