# Migration Guide from saschatimme/elm-phoenix library

Unfortunately due to the lack of an Elm 0.19 native Websocket library and the removal
of Effects Managers in Elm 0.19, the implementation is not as clean for the user of
the library, and probably not as performant either.  Therefore a lot of additional
wiring as described in the README is now required.  The changes described below are
also necessary.

Additionally be aware of functionality not yet implemented as described in the README.

## Endpoint url
Remove `/websocket` from end of endpoint as `phoenix.js` adds this itself

## Change to `Phoenix.connect`
This no longer takes the socket and a list of channels to generate the subscription.
Instead it takes the following:
```elm
Phoenix.connect PhoenixPorts.ports socket PhoenixMsg
```

## Change to `Phoenix.push`
The signature has changed from:
```elm
push : String -> Push msg -> Cmd msg
```
to
```elm
push : String -> (Msg msg -> msg) -> Push msg -> Cmd msg
```

As it takes the `PhoenixMsg` as a parameter as the command needs to be mapped.

Before:
```elm
  Phoenix.push endpoint myPush
```
to:
```elm
  Phoenix.push endpoint PhoenixMsg myPush
```
