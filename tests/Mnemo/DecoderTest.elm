module Mnemo.DecoderTest exposing (suite)

{-| The console API decoders against the copied fixtures. A renamed field must
fail the decoder, not silently become a default.
-}

import Expect
import Json.Decode as D
import Mnemo.Decode as Decode
import Mnemo.Fixtures as Fixtures
import Test exposing (Test, describe, test)


decode : D.Decoder a -> String -> Result String a
decode decoder raw =
    D.decodeString decoder raw |> Result.mapError D.errorToString


suite : Test
suite =
    describe "Mnemo.Decode"
        [ test "session: spaces, selected space, poll and CSRF token" <|
            \_ ->
                case decode Decode.sessionDecoder Fixtures.sessionJson of
                    Err err ->
                        Expect.fail err

                    Ok session ->
                        Expect.equal
                            { space = "console"
                            , spaces = [ "console", "graphos-studio" ]
                            , poll = 2
                            , csrf = "csrf-token-of-the-session"
                            }
                            session
        , test "runs: workflow, status, times, counts and token totals" <|
            \_ ->
                case decode Decode.runsDecoder Fixtures.runsJson of
                    Err err ->
                        Expect.fail err

                    Ok runs ->
                        Expect.equal 3 (List.length runs)
        , test "runs: the first run carries its token totals" <|
            \_ ->
                case decode Decode.runsDecoder Fixtures.runsJson of
                    Err err ->
                        Expect.fail err

                    Ok runs ->
                        case List.head runs of
                            Nothing ->
                                Expect.fail "the fixture holds no run"

                            Just run ->
                                Expect.equal ( 1200, 3400 ) ( run.tokens.card, run.tokens.prompt )
        , test "run detail: the board and its step runs" <|
            \_ ->
                case decode Decode.runDetailDecoder Fixtures.runJson of
                    Err err ->
                        Expect.fail err

                    Ok detail ->
                        Expect.equal
                            [ ( "plan", "passed" ), ( "code", "running" ), ( "gate", "waiting" ) ]
                            (List.map (\step -> ( step.id, step.status )) detail.steps)
        , test "graph: nodes, layers, edges and implied" <|
            \_ ->
                case decode Decode.graphDecoder Fixtures.graphJson of
                    Err err ->
                        Expect.fail err

                    Ok graph ->
                        Expect.all
                            [ \_ -> Expect.equal [ 0, 1, 1, 2 ] (List.map .layer graph.nodes)
                            , \_ -> Expect.equal 5 (List.length graph.edges)
                            , \_ ->
                                Expect.equal
                                    [ "plan" ]
                                    (List.map .from (List.filter .implied graph.edges))
                            ]
                            ()
        , test "step run: status, attempt and token use" <|
            \_ ->
                case decode Decode.stepRunDetailDecoder Fixtures.stepRunJson of
                    Err err ->
                        Expect.fail err

                    Ok stepRun ->
                        Expect.equal
                            ( ( "running", 2 ), ( 1200, 3400 ) )
                            ( ( stepRun.status, stepRun.attempt ), ( stepRun.cardTokens, stepRun.promptTokens ) )
        , test "a renamed field fails the decoder" <|
            \_ ->
                let
                    renamed =
                        String.replace "\"workflow\"" "\"workflw\"" Fixtures.runsJson
                in
                case decode Decode.runsDecoder renamed of
                    Err _ ->
                        Expect.pass

                    Ok _ ->
                        Expect.fail "a renamed workflow field still decoded"
        , describe "orchestrator"
            [ test "a live orchestrator: state, heartbeat, counts and causes" <|
                \_ ->
                    case decode Decode.orchestratorDecoder Fixtures.orchestratorLiveJson of
                        Err err ->
                            Expect.fail err

                        Ok report ->
                            Expect.all
                                [ \_ -> Expect.equal True report.live
                                , \_ -> Expect.equal (Just "2026-11-26T22:25:08Z") report.lastHeartbeat
                                , \_ -> Expect.equal (Just 1) report.sequence
                                , \_ -> Expect.equal [ "decided", "granted" ] report.causes
                                ]
                                ()
            , test "none after one ran: the heartbeat stays, the state is not live" <|
                \_ ->
                    case decode Decode.orchestratorDecoder Fixtures.orchestratorGoneJson of
                        Err err ->
                            Expect.fail err

                        Ok report ->
                            Expect.equal
                                ( False, Just "2026-11-26T22:25:08Z", Just 1 )
                                ( report.live, report.lastHeartbeat, report.sequence )
            , test "a space never held: no heartbeat and no counts" <|
                \_ ->
                    case decode Decode.orchestratorDecoder Fixtures.orchestratorNeverJson of
                        Err err ->
                            Expect.fail err

                        Ok report ->
                            Expect.all
                                [ \_ -> Expect.equal False report.live
                                , \_ -> Expect.equal Nothing report.lastHeartbeat
                                , \_ -> Expect.equal Nothing report.held
                                , \_ -> Expect.equal [] report.runs
                                ]
                                ()
            , test "a list of the seven words and one the page does not know" <|
                \_ ->
                    case decode Decode.orchestratorDecoder Fixtures.orchestratorWordsJson of
                        Err err ->
                            Expect.fail err

                        Ok report ->
                            Expect.equal
                                [ "held", "moves", "later", "waits", "failed", "remediation", "off", "queued" ]
                                (List.map .word report.runs)
            , test "a renamed field of the orchestrator fails the decoder" <|
                \_ ->
                    let
                        renamed =
                            String.replace "\"live\"" "\"alive\"" Fixtures.orchestratorLiveJson
                    in
                    case decode Decode.orchestratorDecoder renamed of
                        Err _ ->
                            Expect.pass

                        Ok _ ->
                            Expect.fail "a renamed live field still decoded"
            ]
        ]
