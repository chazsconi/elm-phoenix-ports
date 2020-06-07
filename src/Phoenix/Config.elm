module Phoenix.Config exposing
    ( Config
    , new, withDebug, map
    )

{-| Defines the Config for Phoenix


# Definition

@docs Config


# Helpers

@docs new, withDebug, map

-}

import Phoenix.Internal.Types exposing (Msg)
import Phoenix.PortsAPI exposing (Ports)


{-| The config for Phoenix
-}
type alias Config msg =
    { parentMsg : Msg msg -> msg
    , debug : Bool
    , ports : Maybe (Ports msg)
    }


{-| Creates a new config
-}
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
