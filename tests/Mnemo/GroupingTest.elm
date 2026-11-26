module Mnemo.GroupingTest exposing (suite)

import Expect
import Mnemo.Decode as Decode
import Mnemo.Fixtures as Fixtures
import Mnemo.Grouping as Grouping
import Json.Decode as D
import Test exposing (Test, describe, test)


runs : List Decode.Run
runs =
    case D.decodeString Decode.runsDecoder Fixtures.runsJson of
        Ok value ->
            value

        Err _ ->
            []


suite : Test
suite =
    describe "Mnemo.Grouping.groupRuns"
        [ test "groups by workflow, newest run first, groups by their newest run" <|
            \_ ->
                Grouping.groupRuns runs
                    |> List.map (\group -> ( group.workflow, List.map .key group.runs ))
                    |> Expect.equal
                        [ ( "dev-plan", [ "run|console|r1", "run|console|r2" ] )
                        , ( "release", [ "run|console|r3" ] )
                        ]
        , test "an empty list gives no group" <|
            \_ ->
                Grouping.groupRuns []
                    |> Expect.equal []
        , test "a workflow keeps its runs even when another workflow is newer in between" <|
            \_ ->
                let
                    interleaved =
                        [ Decode.Run "a|1" "one" "passed" "2026-11-26T09:00:00Z" Nothing 1 0 (Decode.Tokens 0 0)
                        , Decode.Run "b|1" "two" "passed" "2026-11-26T08:00:00Z" Nothing 1 0 (Decode.Tokens 0 0)
                        , Decode.Run "a|2" "one" "passed" "2026-11-26T07:00:00Z" Nothing 1 0 (Decode.Tokens 0 0)
                        ]
                in
                Grouping.groupRuns interleaved
                    |> List.map (\group -> ( group.workflow, List.map .key group.runs ))
                    |> Expect.equal
                        [ ( "one", [ "a|1", "a|2" ] )
                        , ( "two", [ "b|1" ] )
                        ]
        ]
