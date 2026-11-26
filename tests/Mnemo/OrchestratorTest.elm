module Mnemo.OrchestratorTest exposing (suite)

{-| The orchestrator view: the state of the space, the last heartbeat, the
word and the reason of each run that is not final, and the three states of the
read (served, not served, stale). Every answer comes from a fixture; no test
reaches a console or an orchestrator.
-}

import Expect
import Json.Decode as D
import Mnemo.Api as Api
import Mnemo.App as App
import Mnemo.Decode as Decode exposing (Orchestrator, Run, Session)
import Mnemo.Fixtures as Fixtures
import Mnemo.Format as Format
import Mnemo.Orchestrator as Orchestrator
import Test exposing (Test, describe, test)
import Test.Html.Event as Event
import Test.Html.Query as Query
import Test.Html.Selector as Selector
import Time


session : Session
session =
    D.decodeString Decode.sessionDecoder Fixtures.sessionJson
        |> Result.withDefault (Session "console" [ "console" ] 2 "csrf")


runsFixture : List Run
runsFixture =
    D.decodeString Decode.runsDecoder Fixtures.runsJson
        |> Result.withDefault []


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


modelWithRuns : Orchestrator -> List Run -> App.Model
modelWithRuns report runs =
    let
        base =
            model report
    in
    { base | runs = runs }


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
        , describe "the word and the reason of each run" <|
            [ test "every known word has a label and an explanation" <|
                \_ ->
                    Expect.all
                        [ \_ ->
                            Expect.equal
                                [ "Held", "Moves", "Later", "Waits", "Failed", "Remediation", "Off" ]
                                (List.map Orchestrator.labelWord
                                    [ "held", "moves", "later", "waits", "failed", "remediation", "off" ]
                                )
                        , \_ ->
                            Expect.equal
                                [ True, True, True, True, True, True, True ]
                                (List.map (\word -> String.length (Orchestrator.wordExplanation word) > 20)
                                    [ "held", "moves", "later", "waits", "failed", "remediation", "off" ]
                                )
                        ]
                        ()
            , test "three runs carry waits, failed and remediation with their reasons" <|
                \_ ->
                    let
                        html =
                            App.view (model words) |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> html |> Query.has [ Selector.text "waits" ]
                        , \_ -> html |> Query.has [ Selector.text "step approve-s3 waits for an approval" ]
                        , \_ -> html |> Query.has [ Selector.text "failed" ]
                        , \_ -> html |> Query.has [ Selector.text "step code failed: exit_code: 127" ]
                        , \_ -> html |> Query.has [ Selector.text "remediation" ]
                        , \_ -> html |> Query.has [ Selector.text "the launches of this run did not take" ]
                        , \_ ->
                            html
                                |> Query.has
                                    [ Selector.text "/home/console/.local/state/mnemo/orchestrator/console/remediation-run.log" ]
                        ]
                        ()
            , test "a run that moves names its cause" <|
                \_ ->
                    App.view (model words)
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "the cause decided" ]
            , test "a run that is due later names its due time" <|
                \_ ->
                    App.view (model words)
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "due at 2026-11-26T22:35:08Z" ]
            , test "no orchestrator gives off with the reason the console gives" <|
                \_ ->
                    let
                        report =
                            { words
                                | live = False
                                , runs =
                                    [ { run = "decided-run"
                                      , status = "waiting"
                                      , word = "off"
                                      , reason = "no orchestrator holds the space"
                                      , logFile = Nothing
                                      }
                                    ]
                            }
                    in
                    App.view (model report)
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "no orchestrator holds the space" ]
            , test "a word the page does not know is shown as given with its reason" <|
                \_ ->
                    let
                        html =
                            App.view (model words) |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> html |> Query.has [ Selector.text "queued" ]
                        , \_ -> html |> Query.has [ Selector.text "a queue added in a later slice holds it" ]
                        ]
                        ()
            , test "nothing to move says so" <|
                \_ ->
                    App.view (model { live | runs = [] })
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "No run is left to move." ]
            , test "a line shows the workflow from the run list" <|
                \_ ->
                    let
                        report =
                            { live
                                | runs =
                                    [ { run = "r1"
                                      , status = "waiting"
                                      , word = "moves"
                                      , reason = "the cause decided"
                                      , logFile = Nothing
                                      }
                                    ]
                            }
                    in
                    App.view (modelWithRuns report runsFixture)
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "dev-plan" ]
            , test "the link of a line selects the run in the runs view" <|
                \_ ->
                    let
                        report =
                            { live
                                | runs =
                                    [ { run = "r1"
                                      , status = "waiting"
                                      , word = "moves"
                                      , reason = "the cause decided"
                                      , logFile = Nothing
                                      }
                                    ]
                            }
                    in
                    App.view (modelWithRuns report runsFixture)
                        |> Query.fromHtml
                        |> Query.find [ Selector.class "mnemo-orchestrator-open" ]
                        |> Query.find [ Selector.tag "button" ]
                        |> Event.simulate Event.click
                        |> Event.expect (App.SelectRun "run|console|r1")
            ]
        , describe "the word in the run list" <|
            [ test "a waiting run that will move shows waiting and moves" <|
                \_ ->
                    let
                        report =
                            { live
                                | runs =
                                    [ { run = "r3"
                                      , status = "waiting"
                                      , word = "moves"
                                      , reason = "the cause decided"
                                      , logFile = Nothing
                                      }
                                    ]
                            }
                    in
                    App.view (modelWithRuns report runsFixture)
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "mnemo-run" ]
                        |> Query.index 2
                        |> Query.has [ Selector.text "waiting", Selector.text "Moves" ]
            , test "a passed run shows no word" <|
                \_ ->
                    let
                        report =
                            { live
                                | runs =
                                    [ { run = "r2"
                                      , status = "passed"
                                      , word = "moves"
                                      , reason = "the cause decided"
                                      , logFile = Nothing
                                      }
                                    ]
                            }
                    in
                    App.view (modelWithRuns report runsFixture)
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "mnemo-run" ]
                        |> Query.index 1
                        |> Query.hasNot [ Selector.text "Moves" ]
            , test "the route is not served: every run keeps its status and has no word" <|
                \_ ->
                    let
                        base =
                            modelWithRuns live runsFixture
                    in
                    App.view { base | orchestrator = Orchestrator.NotServed }
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "mnemo-run" ]
                        |> Query.index 2
                        |> Query.hasNot [ Selector.text "Moves" ]
            , test "a run is matched by its full key as well" <|
                \_ ->
                    let
                        report =
                            { live
                                | runs =
                                    [ { run = "run|console|r3"
                                      , status = "waiting"
                                      , word = "moves"
                                      , reason = "the cause decided"
                                      , logFile = Nothing
                                      }
                                    ]
                            }
                    in
                    App.view (modelWithRuns report runsFixture)
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "mnemo-run" ]
                        |> Query.index 2
                        |> Query.has [ Selector.text "Moves" ]
            , test "a run the answer does not list has no word" <|
                \_ ->
                    let
                        report =
                            { live
                                | runs =
                                    [ { run = "another-run"
                                      , status = "waiting"
                                      , word = "moves"
                                      , reason = "the cause decided"
                                      , logFile = Nothing
                                      }
                                    ]
                            }
                    in
                    App.view (modelWithRuns report runsFixture)
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.class "mnemo-run" ]
                        |> Query.index 2
                        |> Query.hasNot [ Selector.text "Moves" ]
            ]
        , describe "the read: served, not served, stale, expired" <|
            [ test "the view's complete request list holds only GET" <|
                \_ ->
                    Expect.all
                        [ \_ -> Expect.equal 1 (List.length Orchestrator.requests)
                        , \_ ->
                            Expect.equal True
                                (List.all (String.startsWith "GET ") Orchestrator.requests)
                        ]
                        ()
            , test "a console without the route says so, and does not say that none holds the space" <|
                \_ ->
                    let
                        updated =
                            App.update (App.GotOrchestrator (Err Api.NotFound)) (model live)
                                |> Tuple.first

                        html =
                            App.view updated |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> Expect.equal Orchestrator.NotServed updated.orchestrator
                        , \_ -> html |> Query.has [ Selector.text "This console does not serve the orchestrator's state" ]
                        , \_ -> html |> Query.hasNot [ Selector.text "No orchestrator holds the space" ]
                        ]
                        ()
            , test "a failed poll keeps the last state, marks it stale, names the route and offers a retry" <|
                \_ ->
                    let
                        updated =
                            App.update (App.GotOrchestrator (Err (Api.BadStatus 503))) (model live)
                                |> Tuple.first

                        html =
                            App.view updated |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> html |> Query.has [ Selector.text "An orchestrator holds the space" ]
                        , \_ -> html |> Query.has [ Selector.text "Stale: last read 2026-11-26T22:25:08Z." ]
                        , \_ -> html |> Query.has [ Selector.text "HTTP 503 from /api/orchestrator." ]
                        , \_ -> html |> Query.has [ Selector.tag "button", Selector.text "Retry" ]
                        ]
                        ()
            , test "a 401 shows the page's session-expired message" <|
                \_ ->
                    let
                        updated =
                            App.update (App.GotOrchestrator (Err Api.Unauthorized)) (model live)
                                |> Tuple.first
                    in
                    Expect.all
                        [ \_ -> Expect.equal True updated.sessionExpired
                        , \_ -> App.view updated |> Query.fromHtml |> Query.has [ Selector.text "The session expired" ]
                        ]
                        ()
            , test "each state of the view has its own text" <|
                \_ ->
                    Expect.equal 6
                        (List.length
                            (List.foldl
                                (\text seen ->
                                    if List.member text seen then
                                        seen

                                    else
                                        text :: seen
                                )
                                []
                                [ Orchestrator.stateText Orchestrator.Loading
                                , Orchestrator.stateText Orchestrator.NotServed
                                , Orchestrator.stateText (Orchestrator.Stale { report = Nothing, readAt = now, notice = "x" })
                                , Orchestrator.stateText (Orchestrator.Loaded { report = live, readAt = now })
                                , Orchestrator.stateText (Orchestrator.Loaded { report = gone, readAt = now })
                                , Orchestrator.stateText (Orchestrator.Loaded { report = never, readAt = now })
                                ]
                            )
                        )
            , test "the view loads before the first answer" <|
                \_ ->
                    let
                        base =
                            model live
                    in
                    App.view { base | orchestrator = Orchestrator.Loading }
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "Loading the orchestrator's state…" ]
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
