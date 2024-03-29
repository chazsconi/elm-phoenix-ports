# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2023-05-15
* OTHER - Filter out internal Phoenix events so we don't pass them to elm as they will not be listened to using an `on` handler.  This makes using the Elm debugger easier as it is not polluted with unnecessary messages.  This COULD be a breaking change if for some reason the client explicitly listens for internal Phoenix events, e.g. `phx_close`.

* OTHER - Cleaned code to remove unused references or expose local functions - N.B. There are now some functions that are exposed (e.g. `Socket.withoutHeartbeat`) for which the features are not yet implemented on the JS side. They are marked as "NOT YET IMPLEMENTED" and will have no effect if used.

* BUG - fixed so that push timeouts are only listened for if `onTimeout` has been set.  Without this, confusing log messages were sent with debug on when the channel didn't reply to a push.

## [2.0.0] - 2023-04-25
### Refactored no longer use a timer to check for changes

Previously a timer was used to check for changes to the model every 100ms and then join or leave channels dynamically. Instead now
the the main `update` function is wrapped in `Phoenix.updateDynamicChannels` function.

This also adds extra fields to the `Phoenix.Config.Config` type and allows simplifying the main `update` function in the caller.

This is a breaking change.  See `README.md` on how to configure the app now.


## [1.1.3] - 2021-09-11
Relaxed Elm version to >= 0.19.0

## [1.1.2] - 2020-10-29
Additions to README

## [1.1.1] - 2020-06-07
Initial version

