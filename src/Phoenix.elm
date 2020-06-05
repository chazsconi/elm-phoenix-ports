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
import Phoenix.Config exposing (Config)
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
push : Config msg -> Push msg -> Cmd msg
push config p =
    Cmd.map config.parentMsg <|
        Task.perform (\_ -> SendPush p) (Task.succeed Ok)


{-| Update the model
-}
update : Config msg -> Socket msg -> (channelsModel -> List (Channel msg)) -> channelsModel -> Msg msg -> Model msg channelsModel -> ( Model msg channelsModel, Cmd msg )
update config socket channelsFn channelsModel msg model =
    let
        _ =
            if socket.debug then
                Debug.log "msg model" ( msg, model )

            else
                ( msg, model )

        ( updateModel, cmd, parentMsgs ) =
            case config.ports of
                Nothing ->
                    ( model, Cmd.none, [] )

                Just ports ->
                    internalUpdate ports socket channelsFn channelsModel msg model

        allCmd =
            Cmd.batch <| Cmd.map config.parentMsg cmd :: List.map (\parentMsg -> Task.perform (\_ -> parentMsg) (Task.succeed Ok)) parentMsgs
    in
    ( updateModel, allCmd )


internalUpdate : Ports msg -> Socket msg -> (channelsModel -> List (Channel msg)) -> channelsModel -> Msg msg -> Model msg channelsModel -> ( Model msg channelsModel, Cmd (Msg msg), List msg )
internalUpdate ports socket channelsFn channelsModel msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none, [] )

        Tick _ ->
            case model.socketState of
                Disconnected ->
                    ( { model | socketState = Connected }
                    , ports.connectSocket
                        { endpoint = socket.endpoint
                        , params = JE.dict identity JE.string (Dict.fromList socket.params)
                        }
                    , []
                    )

                Connected ->
                    if Just channelsModel == model.previousChannelsModel then
                        ( model, Cmd.none, [] )

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
                                                , presence = c.presence /= Nothing
                                                }
                                            )
                                            newChannels

                            onRequestJoinMsgs =
                                List.filterMap .onRequestJoin newChannels

                            cmds =
                                [ newChannelsCmd ]
                                    ++ List.map ports.leaveChannel removedChannelObjs
                        in
                        ( { model | previousChannelsModel = Just channelsModel, channelStates = updatedChannelStates }, Cmd.batch cmds, onRequestJoinMsgs )

        SocketOpened ->
            ( model, Cmd.none, maybeToList socket.onOpen )

        SocketClosed params ->
            ( model, Cmd.none, maybeToList <| Maybe.map (\onCloseMsg -> onCloseMsg params) socket.onClose )

        SendPush p ->
            case ChannelStates.getJoinedChannelObj p.topic model.channelStates of
                Nothing ->
                    let
                        _ =
                            Debug.log "Push on unjoined channel - queueing: " p.topic
                    in
                    ( { model | pushes = Pushes.queue p model.pushes }, Cmd.none, [] )

                Just channelObj ->
                    -- TOOD: Do not store if no onHandlers
                    let
                        ( pushRef, updatedPushes ) =
                            Pushes.insert p model.pushes
                    in
                    ( { model | pushes = updatedPushes }
                    , pushChannel ports pushRef channelObj p
                    , []
                    )

        ChannelPushOk topic pushRef payload ->
            case Pushes.pop pushRef model.pushes of
                Nothing ->
                    ( model, Cmd.none, [] )

                Just ( p, updatedPushes ) ->
                    ( { model | pushes = updatedPushes }, Cmd.none, maybeToList <| Maybe.map (\c -> c payload) p.onOk )

        ChannelPushError topic pushRef payload ->
            case Pushes.pop pushRef model.pushes of
                Nothing ->
                    ( model, Cmd.none, [] )

                Just ( p, updatedPushes ) ->
                    ( { model | pushes = updatedPushes }, Cmd.none, maybeToList <| Maybe.map (\c -> c payload) p.onError )

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
            , []
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
                            ( updatedModel, Cmd.none, [] )

                        Just onJoinMsg ->
                            ( updatedModel, Cmd.none, [ onJoinMsg payload ] )

                Nothing ->
                    -- let
                    --     _ =
                    --         Debug.log "ChannelJoinOk for channel no longer subscribed to: " topic
                    -- in
                    ( updatedModel, Cmd.none, [] )

        ChannelJoinError topic payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case channel.onJoinError of
                        Nothing ->
                            ( model, Cmd.none, [] )

                        Just onJoinError ->
                            ( model, Cmd.none, [ onJoinError payload ] )

                Nothing ->
                    ( model, Cmd.none, [] )

        ChannelLeaveOk topic payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    let
                        updatedModel =
                            { model | channelStates = ChannelStates.remove topic model.channelStates }
                    in
                    case channel.onLeave of
                        Nothing ->
                            ( updatedModel, Cmd.none, [] )

                        Just onLeaveMsg ->
                            ( updatedModel, Cmd.none, [ onLeaveMsg payload ] )

                Nothing ->
                    ( model, Cmd.none, [] )

        ChannelLeaveError topic payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    let
                        -- Not sure what to do here, or how a leave error can occur
                        -- but the channel is removed anyway
                        updatedModel =
                            { model | channelStates = ChannelStates.remove topic model.channelStates }
                    in
                    case channel.onLeaveError of
                        Nothing ->
                            ( updatedModel, Cmd.none, [] )

                        Just onLeaveError ->
                            ( updatedModel, Cmd.none, [ onLeaveError payload ] )

                Nothing ->
                    ( model, Cmd.none, [] )

        ChannelMessage topic event payload ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case Dict.get event channel.on of
                        Nothing ->
                            ( model, Cmd.none, [] )

                        Just onMsg ->
                            ( model, Cmd.none, [ onMsg payload ] )

                Nothing ->
                    ( model, Cmd.none, [] )

        ChannelError topic ->
            case ChannelStates.getChannel topic model.channelStates of
                Just channel ->
                    case channel.onError of
                        Just onErrorMsg ->
                            ( model, Cmd.none, [ onErrorMsg ] )

                        Nothing ->
                            ( model, Cmd.none, [] )

                Nothing ->
                    ( model, Cmd.none, [] )

        PresenceUpdated event topic presences ->
            let
                handler =
                    case event of
                        Synced ->
                            .onChange

                        Joined ->
                            .onJoins

                        Left ->
                            .onLeaves

                newMsg =
                    ChannelStates.getChannel topic model.channelStates
                        |> Maybe.andThen .presence
                        |> Maybe.andThen handler
                        |> Maybe.map (\onChangeMsg -> onChangeMsg presences)
            in
            ( model, Cmd.none, maybeToList newMsg )


maybeToList : Maybe a -> List a
maybeToList m =
    case m of
        Just a ->
            [ a ]

        Nothing ->
            []


{-| Connect the socket
-}
connect : Config msg -> Sub msg
connect config =
    let
        tickInterval =
            if config.debug then
                1000

            else
                100
    in
    case config.ports of
        Nothing ->
            Sub.none

        Just ports ->
            Sub.map config.parentMsg <|
                Sub.batch
                    [ ports.channelsCreated ChannelsCreated
                    , ports.channelMessage (\( topic, event, payload ) -> ChannelMessage topic event payload)
                    , ports.channelError ChannelError
                    , ports.pushReply parsePushReply
                    , ports.socketOpened (\_ -> SocketOpened)
                    , ports.socketClosed SocketClosed
                    , ports.presenceUpdated parsePresenceUpdated
                    , Time.every tickInterval Tick
                    ]


pushChannel : Ports msg -> PushRef -> ChannelObj -> Push msg -> Cmd (Msg msg)
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


parsePresenceUpdated : PortsAPI.PresenceUpdate -> Msg msg
parsePresenceUpdated { topic, eventName, presences } =
    let
        presenceDict =
            Dict.fromList presences
    in
    case eventName of
        "synced" ->
            PresenceUpdated Synced topic presenceDict

        "joined" ->
            PresenceUpdated Joined topic presenceDict

        "left" ->
            PresenceUpdated Left topic presenceDict

        _ ->
            NoOp


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

        SocketOpened ->
            SocketOpened

        SocketClosed a ->
            SocketClosed a

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

        PresenceUpdated a b c ->
            PresenceUpdated a b c
