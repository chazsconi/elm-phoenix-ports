module Phoenix.Internal.Pushes exposing (PushRef, Pushes, insert, insertQueuedByTopics, new, pop, queue)

import Dict exposing (Dict)
import Phoenix.Channel exposing (Topic)
import Phoenix.Push exposing (Push)


type alias PushRef =
    Int


type alias Pushes msg =
    { nextRef : Int, sent : Dict PushRef (Push msg), queued : List (Push msg) }


new : Pushes msg
new =
    { nextRef = 1, sent = Dict.empty, queued = [] }


{-| queue a message that cannot be sent because the channel has not yet been created
-}
queue : Push msg -> Pushes msg -> Pushes msg
queue push pushes =
    { pushes | queued = push :: pushes.queued }


{-| Move queued pushes to sent, returning a list of the refs and push list
-}
insertQueuedByTopics : List Topic -> Pushes msg -> ( List ( PushRef, Push msg ), Pushes msg )
insertQueuedByTopics topics pushes =
    let
        ( toInsert, remaining ) =
            List.partition (\p -> List.member p.topic topics) pushes.queued
    in
    insertMany toInsert { pushes | queued = remaining }


insertMany : List (Push msg) -> Pushes msg -> ( List ( PushRef, Push msg ), Pushes msg )
insertMany pushList pushes =
    let
        foldFn : Push msg -> ( List ( PushRef, Push msg ), Pushes msg ) -> ( List ( PushRef, Push msg ), Pushes msg )
        foldFn push ( refsAndPushAcc, pushesAcc ) =
            let
                ( ref, updatedPushesAcc ) =
                    insert push pushesAcc

                updatedRefsAndPushAcc =
                    ( ref, push ) :: refsAndPushAcc
            in
            ( updatedRefsAndPushAcc, updatedPushesAcc )
    in
    List.foldl foldFn ( [], pushes ) pushList


{-| insert a sent message
-}
insert : Push msg -> Pushes msg -> ( PushRef, Pushes msg )
insert push pushes =
    ( pushes.nextRef, { pushes | nextRef = pushes.nextRef + 1, sent = Dict.insert pushes.nextRef push pushes.sent } )


{-| Pop a sent message by ref
-}
pop : PushRef -> Pushes msg -> Maybe ( Push msg, Pushes msg )
pop ref pushes =
    case Dict.get ref pushes.sent of
        Nothing ->
            Nothing

        Just push ->
            Just ( push, { pushes | sent = Dict.remove ref pushes.sent } )
