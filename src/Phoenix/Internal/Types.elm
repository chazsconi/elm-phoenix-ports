module Phoenix.Internal.Types exposing (..)

import Dict exposing (Dict)
import Json.Decode as JD
import Phoenix.Channel exposing (Topic)
import Phoenix.Internal.ChannelStates exposing (ChannelStates)
import Phoenix.Internal.Pushes exposing (PushRef, Pushes)
import Phoenix.Push exposing (Push)
import Time exposing (Time)


type alias Event =
    String


type PresenceEvent
    = Synced
    | Joined
    | Left


type Msg msg
    = NoOp
    | Tick Time
    | SocketOpened
    | SocketClosed { code : Int, reason : String, wasClean : Bool }
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
    | PresenceUpdated PresenceEvent Topic (Dict String (List JD.Value))


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
