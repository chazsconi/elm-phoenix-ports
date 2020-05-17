port module PhoenixPorts exposing (ports)

import Json.Encode as JE
import Phoenix.Channel exposing (Topic)
import Phoenix.ChannelStates exposing (ChannelObj)
import Phoenix.PortsAPI exposing (..)


{-| This is not included in the package as Port modules
are not allowed in packages

So you need to import/copy this into your own project

-}
ports : Ports msg
ports =
    { channelMessage = channelMessage
    , pushReply = pushReply
    , channelsCreated = channelsCreated
    , channelError = channelError
    , connectSocket = connectSocket
    , joinChannels = joinChannels
    , leaveChannel = leaveChannel
    , pushChannel = pushChannel
    }


port channelMessage : (( Topic, String, JE.Value ) -> msg) -> Sub msg


port pushReply : (PushReply -> msg) -> Sub msg


port channelsCreated : (List ( Topic, ChannelObj ) -> msg) -> Sub msg


port channelError : (Topic -> msg) -> Sub msg


port connectSocket : ConnectParams -> Cmd msg


port joinChannels : List JoinParams -> Cmd msg


port leaveChannel : ChannelObj -> Cmd msg


port pushChannel : PushParams -> Cmd msg
