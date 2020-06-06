module Phoenix.Config exposing (Config, map, new, withDebug)

import Phoenix.Internal.Types exposing (Msg)
import Phoenix.PortsAPI exposing (Ports)


type alias Config msg =
    { parentMsg : Msg msg -> msg
    , debug : Bool
    , ports : Maybe (Ports msg)
    }


new : (Msg msg -> msg) -> Ports msg -> Config msg
new parentMsg ports =
    { parentMsg = parentMsg, debug = False, ports = Just ports }


{-| Enable debug logs. Every incoming and outgoing message will be printed.
-}
withDebug : Config msg -> Config msg
withDebug config =
    { config | debug = True }


{-| Maps the config. The ports is not mapped as it is only needed at the top level update/subscriptions
-}
map : (Msg b -> b) -> Config a -> Config b
map newParentMsg config =
    { parentMsg = newParentMsg
    , debug = config.debug
    , ports = Nothing
    }
