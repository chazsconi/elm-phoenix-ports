module Phoenix.Config exposing (Config, map, new)

import Phoenix.PortsAPI exposing (Ports)
import Phoenix.Types exposing (Msg)


type alias Config msg =
    { parentMsg : Msg msg -> msg
    , debug : Bool
    , ports : Maybe (Ports msg)
    }


new : (Msg msg -> msg) -> Ports msg -> Config msg
new parentMsg ports =
    { parentMsg = parentMsg, debug = False, ports = Just ports }


withDebug : Config msg -> Config msg
withDebug config =
    { config | debug = True }


map : (Msg b -> b) -> Config a -> Config b
map newParentMsg config =
    { parentMsg = newParentMsg
    , debug = config.debug
    , ports = Nothing
    }
