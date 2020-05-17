module Phoenix.Types exposing (..)

import Dict exposing (Dict)
import Json.Decode as JD
import Phoenix.Channel exposing (Topic)
import Phoenix.ChannelStates exposing (..)
import Phoenix.Push exposing (Push)
import Phoenix.Pushes exposing (PushRef, Pushes)
import Time


type alias Event =
    String


type Msg msg
    = NoOp
    | Tick Time.Posix
    | SendPush (Push msg)
    | ChannelsCreated (List ( Topic, JD.Value ))
    | ChannelJoinOk Topic JD.Value
    | ChannelJoinError Topic JD.Value
    | ChannelLeaveOk Topic JD.Value
    | ChannelLeaveError Topic JD.Value
    | ChannelPushOk Topic PushRef JD.Value
    | ChannelPushError Topic PushRef JD.Value
    | ChannelMessage Topic Event JD.Value
    | ChannelError Topic


type SocketState
    = Disconnected
    | Connected


type alias Model msg channelsModel =
    { socketState : SocketState
    , channelStates : ChannelStates msg
    , pushes : Pushes msg

    -- This is stored as calculating the channels can be expensive
    -- so we only want to do it if the model has changed
    , previousChannelsModel : Maybe channelsModel
    }
