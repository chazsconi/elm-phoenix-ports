#!/bin/bash
(cd assets && \
node_modules/elm/bin/elm make elm/Chat.elm --output=elm_build/elm.js && \
node esbuild.js)
