module Phoenix.Config exposing
    ( Config, PushConfig, PushableConfig
    , new, withStaticChannels, withDynamicChannels, withChannelsModelComparator, withDebug, toPushConfig, mapPushConfig
    )

{-| Defines the Config for Phoenix


# Definition

@docs Config, PushConfig, PushableConfig


# Helpers

@docs new, withStaticChannels, withDynamicChannels, withChannelsModelComparator, withDebug, toPushConfig, mapPushConfig

-}

import Phoenix.Channel exposing (Channel)
import Phoenix.Internal.Types exposing (Model, Msg)
import Phoenix.PortsAPI exposing (Ports)
import Phoenix.Socket exposing (Socket)


type alias ChannelsModelComparator channelsModel =
    channelsModel -> channelsModel -> Bool


type alias ChannelsBuilder msg channelsModel =
    channelsModel -> List (Channel msg)


{-| Minimal config needed for `Phoenix.push`
-}
type alias PushConfig msg =
    { parentMsg : Msg msg -> msg
    , debug : Bool
    }


{-| Extensible config type used by `Phoenix.push`
-}
type alias PushableConfig msg a =
    { a
        | parentMsg : Msg msg -> msg
    }


{-| The config for Phoenix
-}
type alias Config msg parentModel channelsModel =
    { parentMsg : Msg msg -> msg
    , ports : Maybe (Ports msg)
    , socket : parentModel -> Socket msg
    , modelGetter : parentModel -> Model msg channelsModel
    , modelSetter : Model msg channelsModel -> parentModel -> parentModel
    , channelsBuilder : ChannelsBuilder msg channelsModel
    , channelsModelComparator : ChannelsModelComparator channelsModel
    , channelsModelBuilder : parentModel -> channelsModel
    , debug : Bool
    }


{-| Maps the push config
-}
mapPushConfig : (Msg m2 -> m2) -> PushConfig m1 -> PushConfig m2
mapPushConfig newParentMsg config =
    { parentMsg = newParentMsg
    , debug = config.debug
    }


{-| Create a config that can be used for `Phoenix.push` from the config. This has a simple type and
is useful if used in a multi-page app with delegating `update` functions.
-}
toPushConfig : Config msg parentModel channelsModel -> PushConfig msg
toPushConfig { parentMsg, debug } =
    PushConfig parentMsg debug


{-| Creates a new config. The output of this must be piped into `withStaticChannels` or `withDynamicChannels`
-}
new :
    (Msg msg -> msg)
    -> Ports msg
    -> (parentModel -> Socket msg)
    -> (parentModel -> Model msg channelsModel)
    -> (Model msg channelsModel -> parentModel -> parentModel)
    -> { parentMsg : Msg msg -> msg, ports : Maybe (Ports msg), socket : parentModel -> Socket msg, modelGetter : parentModel -> Model msg channelsModel, modelSetter : Model msg channelsModel -> parentModel -> parentModel }
new parentMsg ports socket modelGetter modelSetter =
    { parentMsg = parentMsg
    , ports = Just ports
    , socket = socket
    , modelGetter = modelGetter
    , modelSetter = modelSetter
    }


{-| Sets the config to connect to a list of static channels.
-}
withStaticChannels :
    List (Channel msg)
    -> { parentMsg : Msg msg -> msg, ports : Maybe (Ports msg), socket : parentModel -> Socket msg, modelGetter : parentModel -> Model msg (), modelSetter : Model msg () -> parentModel -> parentModel }
    -> Config msg parentModel ()
withStaticChannels channels baseConfig =
    withDynamicChannels (\_ -> channels) (\_ -> ()) baseConfig


{-| Sets the config to allow the use of dynamic channels
-}
withDynamicChannels :
    ChannelsBuilder msg channelsModel
    -> (parentModel -> channelsModel)
    -> { parentMsg : Msg msg -> msg, ports : Maybe (Ports msg), socket : parentModel -> Socket msg, modelGetter : parentModel -> Model msg channelsModel, modelSetter : Model msg channelsModel -> parentModel -> parentModel }
    -> Config msg parentModel channelsModel
withDynamicChannels channelsBuilder channelsModelBuilder baseConfig =
    { parentMsg = baseConfig.parentMsg
    , ports = baseConfig.ports
    , socket = baseConfig.socket
    , modelGetter = baseConfig.modelGetter
    , modelSetter = baseConfig.modelSetter
    , channelsBuilder = channelsBuilder
    , channelsModelComparator = (==)
    , channelsModelBuilder = channelsModelBuilder
    , debug = False
    }


{-| As an optimisation, the library compares the passed channels model with the version from the previous functional call and then only calls the provided `channels` function if the model has changed.
This comparison is done by default with `==` and due to an issue in Elm, comparing a model with a contained `Json.Encode.Value` can cause a runtime exception. (See <https://github.com/elm/core/issues/1058>).
To solve this, you can provide a custom function that will compare channels models safely.
-}
withChannelsModelComparator : ChannelsModelComparator channelsModel -> Config msg parentModel channelsModel -> Config msg parentModel channelsModel
withChannelsModelComparator comparator config =
    { config | channelsModelComparator = comparator }


{-| Enable debug logs. Every incoming and outgoing message will be printed.
-}
withDebug : Config msg parentModel channelsModel -> Config msg parentModel channelsModel
withDebug config =
    { config | debug = True }
