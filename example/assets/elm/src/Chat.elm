module Chat exposing (..)

import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as JD exposing (Decoder)
import Json.Encode as JE
import Phoenix
import Phoenix.Channel as Channel exposing (Channel)
import Phoenix.Config
import Phoenix.Presence as Presence exposing (Presence)
import Phoenix.Push as Push
import Phoenix.Socket as Socket exposing (AbnormalClose, Socket)
import PhoenixPorts


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { userName : String
    , state : State
    , presence : Dict String (List JD.Value)
    , isActive : Bool
    , messages : List Message
    , composedMessage : String
    , connectionStatus : ConnectionStatus
    , phoenixModel : Phoenix.Model Msg ChannelModel
    }


type ConnectionStatus
    = Connected
    | Disconnected


type State
    = JoiningLobby
    | JoinedLobby
    | LeavingLobby
    | LeftLobby


type Message
    = Message { userName : String, message : String }


type alias ChannelModel =
    { isActive : Bool, userName : String }


initModel : Model
initModel =
    { userName = "User1"
    , messages = []
    , isActive = False
    , state = LeftLobby
    , presence = Dict.empty
    , composedMessage = ""
    , connectionStatus = Disconnected
    , phoenixModel = Phoenix.new
    }


init : ( Model, Cmd Msg )
init =
    ( initModel, Cmd.none )



-- UPDATE


type Msg
    = UpdateUserName String
    | UpdateState State
    | UpdateComposedMessage String
    | Join
    | Leave
    | NewMsg JD.Value
    | UpdatePresence (Dict String (List JD.Value))
    | SendComposedMessage
    | ConnectionStatusChanged ConnectionStatus
    | PhoenixMsg (Phoenix.Msg Msg)


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UpdateUserName name ->
            ( { model | userName = name }, Cmd.none )

        UpdateState state ->
            ( { model | state = state }, Cmd.none )

        UpdateComposedMessage composedMessage ->
            ( { model | composedMessage = composedMessage }, Cmd.none )

        Join ->
            ( { model | isActive = True }, Cmd.none )

        Leave ->
            ( { model | isActive = False, presence = Dict.empty }, Cmd.none )

        SendComposedMessage ->
            let
                push =
                    Push.init "room:lobby" "new_msg"
                        |> Push.withPayload (JE.object [ ( "msg", JE.string model.composedMessage ) ])
            in
            ( { model | composedMessage = "" }, Phoenix.push phoenixConfig push )

        NewMsg payload ->
            case JD.decodeValue decodeNewMsg payload of
                Ok msg ->
                    ( { model | messages = List.append model.messages [ msg ] }, Cmd.none )

                Err err ->
                    ( model, Cmd.none )

        UpdatePresence presenceState ->
            ( { model | presence = Debug.log "presenceState " presenceState }
            , Cmd.none
            )

        ConnectionStatusChanged connectionStatus ->
            ( { model | connectionStatus = connectionStatus }, Cmd.none )

        PhoenixMsg phoenixMsg ->
            let
                channelModel =
                    { isActive = model.isActive, userName = model.userName }

                ( phoenixModel, cmd ) =
                    Phoenix.update phoenixConfig socket channels channelModel phoenixMsg model.phoenixModel
            in
            ( { model | phoenixModel = phoenixModel }, cmd )



-- Decoder


decodeNewMsg : Decoder Message
decodeNewMsg =
    JD.map2 (\userName msg -> Message { userName = userName, message = msg })
        (JD.field "user_name" JD.string)
        (JD.field "msg" JD.string)



-- SUBSCRIPTIONS


phoenixConfig =
    Phoenix.Config.new PhoenixMsg PhoenixPorts.ports


endpoint : String
endpoint =
    "ws://localhost:4000/socket"


{-| Initialize a socket with the default heartbeat intervall of 30 seconds
-}
socket : Socket Msg
socket =
    Socket.init endpoint
        |> Socket.onOpen (ConnectionStatusChanged Connected)
        |> Socket.onClose (\_ -> ConnectionStatusChanged Disconnected)


channels { isActive, userName } =
    if isActive then
        [ lobby userName ]

    else
        []


lobby : String -> Channel Msg
lobby userName =
    let
        presence =
            Presence.create
                |> Presence.onChange UpdatePresence
    in
    Channel.init "room:lobby"
        |> Channel.withPayload (JE.object [ ( "user_name", JE.string userName ) ])
        |> Channel.onRequestJoin (UpdateState JoiningLobby)
        |> Channel.onJoin (\_ -> UpdateState JoinedLobby)
        |> Channel.onLeave (\_ -> UpdateState LeftLobby)
        |> Channel.on "new_msg" (\msg -> NewMsg msg)
        |> Channel.withPresence presence
        |> Channel.withDebug


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ phoenixSubscription model ]


phoenixSubscription model =
    Phoenix.connect phoenixConfig



--
-- VIEW


view : Model -> Html Msg
view model =
    Html.div []
        [ enterLeaveLobby model
        , chatUsers model.presence
        , chatMessages model.messages
        , composeMessage model
        ]


enterLeaveLobby : Model -> Html Msg
enterLeaveLobby model =
    let
        inputDisabled =
            case model.state of
                LeftLobby ->
                    False

                _ ->
                    True

        socketStatusClass =
            "socket-status socket-status--" ++ (String.toLower <| toString <| model.connectionStatus)
    in
    Html.div [ Attr.class "enter-lobby" ]
        [ Html.label []
            [ Html.text "Name"
            , Html.input [ Attr.class "user-name-input", Attr.disabled inputDisabled, Attr.value model.userName, Events.onInput UpdateUserName ] []
            ]
        , button model
        , Html.div [ Attr.class socketStatusClass ] []
        ]


button : Model -> Html Msg
button model =
    let
        buttonClass disabled =
            Attr.classList [ ( "button", True ), ( "button-disabled", disabled ) ]
    in
    case model.state of
        LeavingLobby ->
            Html.button [ Attr.disabled True, buttonClass True ] [ Html.text "Leaving lobby..." ]

        LeftLobby ->
            Html.button [ Events.onClick Join, buttonClass False ] [ Html.text "Join lobby" ]

        JoiningLobby ->
            Html.button [ Attr.disabled True, buttonClass True ] [ Html.text "Joining lobby..." ]

        JoinedLobby ->
            Html.button [ Events.onClick Leave, buttonClass False ] [ Html.text "Leave lobby" ]


chatUsers : Dict String (List JD.Value) -> Html Msg
chatUsers presence =
    Html.div [ Attr.class "chat-users" ]
        (List.map chatUser (Dict.toList presence))


chatUser : ( String, List JD.Value ) -> Html Msg
chatUser ( user_name, payload ) =
    Html.div [ Attr.class "chat-user" ]
        [ Html.span [ Attr.class "chat-user-user-name" ] [ Html.text user_name ] ]


chatMessages : List Message -> Html Msg
chatMessages messages =
    Html.div [ Attr.class "chat-messages" ]
        (List.map chatMessage messages)


chatMessage : Message -> Html Msg
chatMessage msg =
    case msg of
        Message { userName, message } ->
            Html.div [ Attr.class "chat-message" ]
                [ Html.span [ Attr.class "chat-message-user-name" ] [ Html.text (userName ++ ":") ]
                , Html.span [ Attr.class "chat-message-message" ] [ Html.text message ]
                ]


composeMessage : Model -> Html Msg
composeMessage { state, composedMessage } =
    let
        cannotSend =
            case state of
                JoinedLobby ->
                    False

                _ ->
                    True
    in
    Html.form [ Attr.class "send-form", Events.onSubmit SendComposedMessage ]
        [ Html.input [ Attr.class "send-input", Attr.value composedMessage, Events.onInput UpdateComposedMessage ] []
        , Html.button [ Attr.class "send-button", Attr.disabled cannotSend ] [ Html.text "Send" ]
        ]
