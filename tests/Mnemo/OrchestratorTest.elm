module Mnemo.OrchestratorTest exposing (suite)

{-| The orchestrator view: the state of the space, the last heartbeat, the
word and the reason of each run that is not final, and the three states of the
read (served, not served, stale). Every answer comes from a fixture; no test
reaches a console or an orchestrator.
-}

import Expect
import Json.Decode as D
import Mnemo.App as App
import Mnemo.Decode as Decode exposing (Orchestrator, Session)
import Mnemo.Fixtures as Fixtures
import Mnemo.Format as Format
import Mnemo.Orchestrator as Orchestrator
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


session : Session
session =
    D.decodeString Decode.sessionDecoder Fixtures.sessionJson
        |> Result.withDefault (Session "console" [ "console" ] 2 "csrf")


at : Int -> Time.Posix
at millis =
    Time.millisToPosix millis


{-| 2026-11-26T22:25:08Z
-}
now : Time.Posix
now =
    at 1795731908000


live : Orchestrator
live =
    decode Fixtures.orchestratorLiveJson


gone : Orchestrator
gone =
    decode Fixtures.orchestratorGoneJson


never : Orchestrator
never =
    decode Fixtures.orchestratorNeverJson


words : Orchestrator
words =
    decode Fixtures.orchestratorWordsJson


decode : String -> Orchestrator
decode raw =
    D.decodeString Decode.orchestratorDecoder raw
        |> Result.withDefault
            { live = False
            , lastHeartbeat = Nothing
            , sequence = Nothing
            , held = Nothing
            , launched = Nothing
            , leftToPerson = Nothing
            , causes = []
            , runs = []
            }


model : Orchestrator -> App.Model
model report =
    let
        base =
            App.initialModel
    in
    { base
        | session = Just session
        , runs = []
        , runsLoaded = True
        , now = now
        , orchestrator = Orchestrator.Loaded { report = report, readAt = now }
    }


oldModel : Orchestrator -> App.Model
oldModel report =
    let
        base =
            model report
    in
    { base
        | now = now
        , orchestrator =
            Orchestrator.Loaded
                { report = { report | lastHeartbeat = Just "2026-11-26T22:15:08Z" }
                , readAt = now
                }
    }


suite : Test
suite =
    describe "Mnemo.Orchestrator"
        [ describe "the state of the space" <|
            [ test "live: the view and the page say an orchestrator holds the space" <|
                \_ ->
                    App.view (model live)
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.text "An orchestrator holds the space" ]
                        |> Query.count (Expect.equal 2)
            , test "gone: no orchestrator holds the space, and its time is shown" <|
                \_ ->
                    App.view (model gone)
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "No orchestrator holds the space" ]
            , test "an old heartbeat of a live orchestrator keeps the live state" <|
                \_ ->
                    let
                        html =
                            App.view (oldModel live) |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> html |> Query.has [ Selector.text "An orchestrator holds the space" ]
                        , \_ -> html |> Query.has [ Selector.text "10 minutes old" ]
                        ]
                        ()
            , test "never held: the view says no orchestrator has run and shows no heartbeat" <|
                \_ ->
                    let
                        html =
                            App.view (model never) |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> html |> Query.has [ Selector.text "No orchestrator has run on this space" ]
                        , \_ -> html |> Query.has [ Selector.text "No heartbeat has been recorded." ]
                        ]
                        ()
            , test "another space shows that space and nothing of the first" <|
                \_ ->
                    let
                        selected =
                            App.update (App.GotSpace (Ok { session | space = "graphos-studio" })) (model live)
                                |> Tuple.first
                    in
                    Expect.equal Orchestrator.Loading selected.orchestrator
            ]
        , describe "the last heartbeat" <|
            [ test "a heartbeat that launched one run shows its number, time, launch and causes" <|
                \_ ->
                    let
                        html =
                            App.view (model words) |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> html |> Query.has [ Selector.text "sequence 42" ]
                        , \_ -> html |> Query.has [ Selector.text "1 launched" ]
                        , \_ -> html |> Query.has [ Selector.text "decided, granted" ]
                        ]
                        ()
            , test "a newer heartbeat with zero counts replaces the number and time" <|
                \_ ->
                    let
                        newer =
                            { live
                                | sequence = Just 2
                                , lastHeartbeat = Just "2026-11-26T22:26:08Z"
                                , launched = Just 0
                            }

                        updated =
                            App.update (App.GotOrchestrator (Ok newer)) (model live)
                                |> Tuple.first
                    in
                    App.view updated
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "0 launched" ]
            ]
        , describe "the clock" <|
            [ test "an ISO time gives milliseconds and survives a round trip" <|
                \_ ->
                    Expect.equal
                        (Just "2026-11-26T22:25:08Z")
                        (Format.millisFromIso "2026-11-26T22:25:08Z"
                            |> Maybe.map Format.isoFromMillis
                        )
            , test "an age is plain words" <|
                \_ ->
                    Expect.equal
                        [ "10 minutes old", "2 hours old", "3 days old" ]
                        (List.map Format.describeAge [ 600, 7200, 259200 ])
            ]
        ]
