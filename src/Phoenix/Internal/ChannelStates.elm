module Phoenix.Internal.ChannelStates exposing (ChannelObj, ChannelStates, getChannel, getJoinedChannelObj, new, remove, setCreated, setJoined, update)

import Dict exposing (Dict)
import Json.Encode as JE
import Phoenix.Channel exposing (Channel, Topic)


type ChannelStates msg
    = ChannelStates (Dict Topic (InternalChannel msg))


{-| JS channel object
-}
type alias ChannelObj =
    JE.Value


type alias InternalChannel msg =
    { state : ChannelState, channel : Channel msg }


type ChannelState
    = Creating
    | PendingJoin ChannelObj
    | Joined ChannelObj
    | PendingLeave


new : ChannelStates msg
new =
    ChannelStates Dict.empty


getJoinedChannelObj : Topic -> ChannelStates msg -> Maybe ChannelObj
getJoinedChannelObj topic (ChannelStates internalChannels) =
    Dict.get topic internalChannels
        |> Maybe.andThen
            (\{ state } ->
                case state of
                    Creating ->
                        Nothing

                    PendingJoin channelObj ->
                        Just channelObj

                    Joined channelObj ->
                        Just channelObj

                    PendingLeave ->
                        Nothing
            )


getChannel : Topic -> ChannelStates msg -> Maybe (Channel msg)
getChannel topic (ChannelStates internalChannels) =
    Dict.get topic internalChannels |> Maybe.map .channel


updateState : Topic -> (ChannelState -> ChannelState) -> ChannelStates msg -> ChannelStates msg
updateState topic_ func (ChannelStates channelStates) =
    ChannelStates <|
        Dict.update topic_
            (Maybe.map (\ic -> { ic | state = func ic.state }))
            channelStates


setCreated : Topic -> ChannelObj -> ChannelStates msg -> ChannelStates msg
setCreated topic_ channelObj channelStates =
    updateState topic_ (\_ -> PendingJoin channelObj) channelStates


setJoined : Topic -> ChannelStates msg -> ChannelStates msg
setJoined topic_ channelStates =
    updateState topic_
        (\state ->
            case state of
                PendingJoin obj ->
                    Joined obj

                Joined obj ->
                    Joined obj

                other ->
                    other
        )
        channelStates


setPendingLeave : Topic -> ChannelStates msg -> ChannelStates msg
setPendingLeave topic_ channelStates =
    updateState topic_ (\_ -> PendingLeave) channelStates


insert : Channel msg -> ChannelStates msg -> ChannelStates msg
insert channel (ChannelStates channelStates) =
    ChannelStates <| Dict.insert channel.topic { channel = channel, state = Creating } channelStates


remove : Topic -> ChannelStates msg -> ChannelStates msg
remove topic1 (ChannelStates cs) =
    ChannelStates <| Dict.remove topic1 cs


member : Topic -> ChannelStates msg -> Bool
member topic (ChannelStates cs) =
    Dict.member topic cs


foldl : (Topic -> InternalChannel msg -> b -> b) -> b -> ChannelStates msg -> b
foldl func acc (ChannelStates cs) =
    Dict.foldl func acc cs


{-| Topics that are in the list of topics but not in channel state
-}
newChannels : List (Channel msg) -> ChannelStates msg -> List (Channel msg)
newChannels channels channelStates =
    List.foldl
        (\channel acc ->
            if member channel.topic channelStates then
                acc

            else
                channel :: acc
        )
        []
        channels


removedTopics : List Topic -> ChannelStates msg -> ( List Topic, List ChannelObj )
removedTopics topics channelStates =
    foldl
        (\topic internalChannel ( topicAcc, objAcc ) ->
            if List.member topic topics then
                ( topicAcc, objAcc )

            else
                case internalChannel.state of
                    -- Shouldn't happen
                    Creating ->
                        ( topicAcc, objAcc )

                    -- Shouldn't happen
                    PendingLeave ->
                        ( topicAcc, objAcc )

                    PendingJoin obj ->
                        ( topic :: topicAcc, obj :: objAcc )

                    Joined obj ->
                        ( topic :: topicAcc, obj :: objAcc )
        )
        ( [], [] )
        channelStates


addChannels : List (Channel msg) -> ChannelStates msg -> ChannelStates msg
addChannels channels channelStates =
    List.foldl insert channelStates channels


setPendingLeaveTopics : List Topic -> ChannelStates msg -> ChannelStates msg
setPendingLeaveTopics topics channelStates =
    List.foldl setPendingLeave channelStates topics


update : List (Channel msg) -> ChannelStates msg -> ( ChannelStates msg, List (Channel msg), List ChannelObj )
update channels channelStates =
    let
        newChannels_ =
            newChannels channels channelStates

        ( removedTopics_, removedChannelObjs ) =
            removedTopics (List.map .topic channels) channelStates

        updatedChannelStates =
            channelStates
                |> addChannels newChannels_
                |> setPendingLeaveTopics removedTopics_
    in
    ( updatedChannelStates, newChannels_, removedChannelObjs )
