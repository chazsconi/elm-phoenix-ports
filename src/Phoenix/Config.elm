module Phoenix.Config exposing (Config, map, new)

import Phoenix.Types exposing (Msg)


type alias Config msg =
    { parentMsg : Msg msg -> msg
    , debug : Bool
    }


new : (Msg msg -> msg) -> Config msg
new parentMsg =
    { parentMsg = parentMsg, debug = False }


withDebug : Config msg -> Config msg
withDebug config =
    { config | debug = True }


map : (Msg b -> b) -> Config a -> Config b
map newParentMsg config =
    { parentMsg = newParentMsg
    , debug = config.debug
    }
