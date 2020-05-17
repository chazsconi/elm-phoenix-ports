module Phoenix exposing (connect, new, push, update, mapMsg)

{-| Entrypoint for Phoenix


# Definition

@docs connect, new, push, update, mapMsg

-}

import Dict
import Json.Decode as JD
import Json.Encode as JE
import Phoenix.Channel exposing (Channel, Topic)
import Phoenix.ChannelStates as ChannelStates exposing (ChannelObj)
import Phoenix.PortsAPI as PortsAPI exposing (Ports)
import Phoenix.Push exposing (Push)
import Phoenix.Pushes as Pushes exposing (PushRef)
import Phoenix.Socket exposing (Socket)
import Phoenix.Types exposing (..)
import Task
import Time



-- Based on: https://sascha.timme.xyz/elm-phoenix/
-- Code:  https://github.com/saschatimme/elm-phoenix


{-| Initialise the model
-}
new : Model msg channelsModel
new =
    { socketState = Disconnected, channelStates = ChannelStates.new, pushes = Pushes.new, previousChannelsModel = Nothing }


{-| Push an event to a channel
-}
push : String -> (Msg msg -> msg) -> Push msg -> Cmd msg
push endpoint parentMsg p =
    Cmd.map parentMsg <|
        Task.perform (\_ -> SendPush p) (Task.succeed Ok)


{-| Update the model
-}
update : Ports msg -> Socket msg -> (channelsModel -> List (Channel msg)) -> channelsModel -> Msg msg -> Model msg channelsModel -> ( Model msg channelsModel, Cmd msg, Maybe msg )
update ports socket channelsFn channelsModel msg model =
    let
        _ =
            if socket.debug then
                Debug.log "msg model" ( msg, model )

            else
                ( msg, model )
    in
    case msg of
        NoOp ->
            ( model, Cmd.none, Nothing )

        Tick _ ->
            case model.socketState of
                Disconnected ->
                    ( { model | socketState = Connected }
                    , ports.connectSocket
                        { endpoint = socket.endpoint
                        , params = JE.dict identity JE.string (Dict.fromList socket.params)
                        }
                    , Nothing
                    )

                Connected ->
                    if Just channelsModel == model.previousChannelsModel then
                        ( model, Cmd.none, Nothing )

                    else
                        let
                            ( updatedChannelStates, newChannels, removedChannelObjs ) =
                                ChannelStates.update (channelsFn channelsModel) model.channelStates

                            newChannelsCmd =
                                if newChannels == [] then
                                    Cmd.none

                                else
                                    ports.joinChannels <|
                                        List.map
                                            (\c ->
                                                { topic = c.topic
                                                , payload = Maybe.withDefault JE.null c.payload
                                                , onHandlers = { onOk = c.onJoin /= Nothing, onError = c.onJoinError /= Nothing, onTimeout = False }
                                                }
                                            )
                                            newChannels

                            cmds =
                                [ newChannelsCmd ]
                                    ++ List.map ports.leaveChannel removedChannelObjs
                        in
                        ( { model | previousChannelsModel = Just channelsModel, channelStates = updatedChannelStates }, Cmd.batch cmds, Nothing )

        SendPush p ->
            case ChannelStates.getJoinedChannelObj p.topic model.channelStates of
                Nothing ->
                    let
                        _ =
                            Debug.log "Push on unjoined channel - queueing: " p.topic
                    in
                    ( { model | pushes = Pushes.queue p model.pushes }, Cmd.none, Nothing )

                Just channelObj ->
                    -- TOOD: Do not store if no onHandlers
                    let
                        ( pushRef, updatedPushes ) =
                            Pushes.insert p model.pushes
                    in
                    ( { model | pushes = updatedPushes }
                    , pushChannel ports pushRef channelObj p
                    , Nothing
                    )

        ChannelPushOk topic pushRef payload ->
            case Pushes.pop pushRef model.pushes of
                Nothing ->
                    ( model, Cmd.none, Nothing )

                Just ( p, updatedPushes ) ->
                    ( { model | pushes = updatedPushes }, Cmd.none, Maybe.map (\c -> c payload) p.onOk )

        ChannelPushError topic pushRef payload ->
            case Pushes.pop pushRef model.pushes of
                Nothing ->
                    ( model, Cmd.none, Nothing )

                Just ( p, updatedPushes ) ->
                    ( { model | pushes = updatedPushes }, Cmd.none, Maybe.map (\c -> c payload) p.onError )

        ChannelsCreated channelsCreated ->
            let
                updatedChannelStates =
                    List.foldl
                        (\( topic, channelObj ) acc ->
                            ChannelStates.setCreated topic channelObj acc
                        )
                        model.channelStates
                        channelsCreated

                topics =
                    List.map (\( topic, _ ) -> topic) channelsCreated

                -- Need to send the pushes that have been queued
                ( queuedPushList, updatedPushes ) =
                    Pushes.insertQueuedByTopics topics model.pushes

                queuedPushcmds =
                    List.foldl
                        (\( pushRef, p ) acc ->
                            case ChannelStates.getJoinedChannelObj p.topic updatedChannelStates of
                                -- Should not happen
                                Nothing ->
                                    acc

                                Just channelObj ->
                                    pushChannel ports pushRef channelObj p
                                        :: acc
                        )
                        []
                        queuedPushList
            in
            ( { model
                | channelStates = updatedChannelStates
                , pushes = updatedPushes
              }
            , Cmd.batch queuedPushcmds
            , Nothing
            )

        ChannelJoinOk topic payload ->
            let
                updatedModel =
                    { model | channelStates = ChannelStates.setJoined topic model.channelStates }
            in
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case channel.onJoin of
                        Nothing ->
                            ( updatedModel, Cmd.none, Nothing )

                        Just onJoinMsg ->
                            ( updatedModel, Cmd.none, Just (onJoinMsg payload) )

                Nothing ->
                    -- let
                    --     _ =
                    --         Debug.log "ChannelJoinOk for channel no longer subscribed to: " topic
                    -- in
                    ( updatedModel, Cmd.none, Nothing )

        ChannelJoinError topic payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case channel.onJoinError of
                        Nothing ->
                            ( model, Cmd.none, Nothing )

                        Just onJoinError ->
                            ( model, Cmd.none, Just (onJoinError payload) )

                Nothing ->
                    ( model, Cmd.none, Nothing )

        ChannelLeaveOk topic payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case channel.onLeave of
                        Nothing ->
                            ( model, Cmd.none, Nothing )

                        Just onLeaveMsg ->
                            ( model, Cmd.none, Just (onLeaveMsg payload) )

                Nothing ->
                    ( model, Cmd.none, Nothing )

        ChannelLeaveError topic payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case channel.onLeaveError of
                        Nothing ->
                            ( model, Cmd.none, Nothing )

                        Just onLeaveError ->
                            ( model, Cmd.none, Just (onLeaveError payload) )

                Nothing ->
                    ( model, Cmd.none, Nothing )

        ChannelMessage topic event payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case Dict.get event channel.on of
                        Nothing ->
                            ( model, Cmd.none, Nothing )

                        Just onMsg ->
                            ( model, Cmd.none, Just (onMsg payload) )

                Nothing ->
                    ( model, Cmd.none, Nothing )

        ChannelError topic ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case channel.onError of
                        Just onErrorMsg ->
                            ( model, Cmd.none, Just onErrorMsg )

                        Nothing ->
                            ( model, Cmd.none, Nothing )

                Nothing ->
                    ( model, Cmd.none, Nothing )


{-| Connect the socket
-}
connect : Ports (Msg msg) -> Socket msg -> (Msg msg -> msg) -> Sub msg
connect ports socket parentMsg =
    let
        tickInterval =
            if socket.debug then
                1000

            else
                100
    in
    Sub.map parentMsg <|
        Sub.batch
            [ ports.channelsCreated ChannelsCreated
            , ports.channelMessage (\( topic, event, payload ) -> ChannelMessage topic event payload)
            , ports.channelError ChannelError
            , ports.pushReply parsePushReply
            , Time.every tickInterval Tick
            ]


pushChannel : Ports msg -> PushRef -> ChannelObj -> Push msg -> Cmd msg
pushChannel ports pushRef channelObj p =
    ports.pushChannel
        { ref = pushRef
        , channel = channelObj
        , event = p.event
        , payload = p.payload
        , onHandlers =
            { onOk = p.onOk /= Nothing
            , onError = p.onError /= Nothing
            , onTimeout = True
            }
        }


parsePushReply : PortsAPI.PushReply -> Msg msg
parsePushReply { topic, eventName, pushType, ref, payload } =
    case eventName of
        "ok" ->
            case ( pushType, ref ) of
                ( "join", _ ) ->
                    ChannelJoinOk topic payload

                ( "leave", _ ) ->
                    ChannelLeaveOk topic payload

                ( "msg", Just r ) ->
                    ChannelPushOk topic r payload

                _ ->
                    -- Unknown push type
                    NoOp

        "error" ->
            case ( pushType, ref ) of
                ( "join", _ ) ->
                    ChannelJoinError topic payload

                ( "leave", _ ) ->
                    ChannelLeaveError topic payload

                ( "msg", Just r ) ->
                    ChannelPushError topic r payload

                _ ->
                    -- Unknown push type
                    NoOp

        _ ->
            -- Unknown event type
            NoOp


{-| Map the msg
-}
mapMsg : (a -> b) -> Msg a -> Msg b
mapMsg func msg =
    case msg of
        SendPush push_ ->
            SendPush (Phoenix.Push.map func push_)

        NoOp ->
            NoOp

        Tick time ->
            Tick time

        ChannelsCreated v ->
            ChannelsCreated v

        ChannelJoinOk a b ->
            ChannelJoinOk a b

        ChannelJoinError a b ->
            ChannelJoinError a b

        ChannelLeaveOk a b ->
            ChannelLeaveOk a b

        ChannelLeaveError a b ->
            ChannelLeaveError a b

        ChannelPushOk a b c ->
            ChannelPushOk a b c

        ChannelPushError a b c ->
            ChannelPushError a b c

        ChannelMessage a b c ->
            ChannelMessage a b c

        ChannelError a ->
            ChannelError a
