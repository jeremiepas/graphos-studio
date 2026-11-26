module Mnemo.LayoutTest exposing (suite)

import Expect
import Json.Decode as D
import Mnemo.Decode as Decode exposing (Graph, GraphEdge, GraphNode)
import Mnemo.Fixtures as Fixtures
import Mnemo.Layout as Layout
import Mnemo.Status as Status
import Test exposing (Test, describe, test)


decodeGraph : String -> Graph
decodeGraph raw =
    case D.decodeString Decode.graphDecoder raw of
        Ok graph ->
            graph

        Err _ ->
            Graph "" "" [] []


xOf : String -> Layout.Layout -> Int
xOf id result =
    result.nodes
        |> List.filter (\position -> position.node.id == id)
        |> List.head
        |> Maybe.map .x
        |> Maybe.withDefault -1


yOf : String -> Layout.Layout -> Int
yOf id result =
    result.nodes
        |> List.filter (\position -> position.node.id == id)
        |> List.head
        |> Maybe.map .y
        |> Maybe.withDefault -1


suite : Test
suite =
    describe "Mnemo.Layout"
        [ test "the fixture graph places four nodes in three layers" <|
            \_ ->
                let
                    result =
                        Layout.layout (decodeGraph Fixtures.graphJson)
                in
                Expect.all
                    [ \_ -> Expect.equal 4 (List.length result.nodes)
                    , \_ -> Expect.equal [ 0, 1, 1, 2 ] (List.map (\position -> position.node.layer) result.nodes)
                    , \_ -> Expect.equal True (xOf "plan" result < xOf "code" result)
                    , \_ -> Expect.equal (xOf "code" result) (xOf "docs" result)
                    , \_ -> Expect.equal True (xOf "code" result < xOf "gate" result)
                    ]
                    ()
        , test "a chain is one node per layer" <|
            \_ ->
                let
                    graph =
                        Graph "r" "w"
                            [ GraphNode "a" "llm" 0 False
                            , GraphNode "b" "llm" 1 False
                            , GraphNode "c" "llm" 2 False
                            ]
                            [ GraphEdge "a" "b" False, GraphEdge "b" "c" False ]

                    result =
                        Layout.layout graph
                in
                Expect.equal [ 0, 1, 2 ] (List.map (\position -> position.node.layer) result.nodes)
        , test "a branch and a join share a column and split a row" <|
            \_ ->
                let
                    graph =
                        Graph "r" "w"
                            [ GraphNode "a" "llm" 0 False
                            , GraphNode "b" "llm" 1 False
                            , GraphNode "c" "llm" 1 False
                            , GraphNode "d" "llm" 2 False
                            ]
                            [ GraphEdge "a" "b" False
                            , GraphEdge "a" "c" False
                            , GraphEdge "b" "d" False
                            , GraphEdge "c" "d" False
                            ]

                    result =
                        Layout.layout graph
                in
                Expect.all
                    [ \_ -> Expect.equal (xOf "b" result) (xOf "c" result)
                    , \_ -> Expect.notEqual (yOf "b" result) (yOf "c" result)
                    , \_ -> Expect.equal True (xOf "a" result < xOf "b" result && xOf "b" result < xOf "d" result)
                    ]
                    ()
        , test "a single node is at the margin" <|
            \_ ->
                Layout.layout (Graph "r" "w" [ GraphNode "only" "human" 0 False ] [])
                    |> .nodes
                    |> List.head
                    |> Maybe.map (\position -> ( position.x, position.y ))
                    |> Expect.equal (Just ( 32, 32 ))
        , test "an implied edge stays in the graph" <|
            \_ ->
                decodeGraph Fixtures.graphJson
                    |> .edges
                    |> List.filter .implied
                    |> List.length
                    |> Expect.equal 1
        , test "every status maps to a token role and a text label" <|
            \_ ->
                Expect.equal
                    [ ( "passed", Status.Success, "passed" )
                    , ( "failed", Status.Danger, "failed" )
                    , ( "running", Status.Accent, "running" )
                    , ( "waiting", Status.Warning, "waiting" )
                    , ( "pending", Status.Muted, "pending" )
                    , ( "skipped", Status.Muted, "skipped" )
                    ]
                    (List.map (\status -> ( status, Status.tone status, Status.label status ))
                        [ "passed", "failed", "running", "waiting", "pending", "skipped" ]
                    )
        ]
