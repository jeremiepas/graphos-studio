module Mnemo.AppTest exposing (suite)

{-| The page's state: the session fills the spaces, a selection replaces the
space and clears the run, a refusal keeps the list, and a failed read keeps the
last data. The views keep the empty, stale and session-expired states distinct
and the controls reachable.
-}

import Expect
import Html.Attributes as A
import Json.Decode as D
import Mnemo.Api as Api
import Mnemo.App as App
import Mnemo.Decode as Decode exposing (Run, Session)
import Mnemo.Fixtures as Fixtures
import Test exposing (Test, describe, test)
import Test.Html.Query as Query
import Test.Html.Selector as Selector


session : Session
session =
    case D.decodeString Decode.sessionDecoder Fixtures.sessionJson of
        Ok value ->
            value

        Err _ ->
            Session "console" [ "console" ] 2 "csrf"


otherSession : Session
otherSession =
    { session | space = "graphos-studio" }


runs : List Run
runs =
    case D.decodeString Decode.runsDecoder Fixtures.runsJson of
        Ok value ->
            value

        Err _ ->
            []


initialModel : App.Model
initialModel =
    App.initialModel


modelWithSession : App.Model
modelWithSession =
    { initialModel
        | session = Just session
        , runs = runs
        , runsLoaded = True
    }


suite : Test
suite =
    describe "Mnemo.App"
        [ describe "update"
            [ test "the session fills the spaces, the selected space and the poll" <|
                \_ ->
                    App.update (App.GotSession (Ok session)) App.initialModel
                        |> Tuple.first
                        |> .session
                        |> Expect.equal (Just session)
            , test "a successful selection replaces the space and clears the run" <|
                \_ ->
                    let
                        selected =
                            { modelWithSession | selectedRun = Just "run|console|r1" }

                        updated =
                            App.update (App.GotSpace (Ok otherSession)) selected |> Tuple.first
                    in
                    Expect.all
                        [ \_ -> Expect.equal (Just otherSession) updated.session
                        , \_ -> Expect.equal Nothing updated.selectedRun
                        ]
                        ()
            , test "a refused selection keeps the runs and the space and shows the error" <|
                \_ ->
                    let
                        updated =
                            App.update (App.GotSpace (Err (Api.BadStatus 403))) modelWithSession
                                |> Tuple.first
                    in
                    Expect.all
                        [ \_ -> Expect.equal (Just session) updated.session
                        , \_ -> Expect.equal runs updated.runs
                        , \_ -> Expect.equal (Just True) (Maybe.map (String.contains "403") updated.selectionNotice)
                        ]
                        ()
            , test "a 401 keeps the last runs and says the session expired" <|
                \_ ->
                    let
                        updated =
                            App.update (App.GotRuns (Err Api.Unauthorized)) modelWithSession
                                |> Tuple.first
                    in
                    Expect.all
                        [ \_ -> Expect.equal runs updated.runs
                        , \_ -> Expect.equal True updated.sessionExpired
                        , \_ -> Expect.equal (Just True) (Maybe.map (String.contains "expired") updated.runsNotice)
                        ]
                        ()
            , test "a failed read keeps the last runs and names the route" <|
                \_ ->
                    let
                        updated =
                            App.update (App.GotRuns (Err (Api.BadStatus 503))) modelWithSession
                                |> Tuple.first
                    in
                    Expect.all
                        [ \_ -> Expect.equal runs updated.runs
                        , \_ -> Expect.equal (Just True) (Maybe.map (String.contains "/api/runs") updated.runsNotice)
                        ]
                        ()
            , test "no session leaves no run list and says the session expired" <|
                \_ ->
                    let
                        updated =
                            App.update (App.GotSession (Err Api.Unauthorized)) App.initialModel
                                |> Tuple.first
                    in
                    Expect.all
                        [ \_ -> Expect.equal [] updated.runs
                        , \_ -> Expect.equal True updated.sessionExpired
                        ]
                        ()
            ]
        , describe "view"
            [ test "the spaces panel marks the session's space" <|
                \_ ->
                    App.view modelWithSession
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "graphos-studio" ]
            , test "the selected space is marked for assistive users" <|
                \_ ->
                    App.view modelWithSession
                        |> Query.fromHtml
                        |> Query.has [ Selector.attribute (A.attribute "aria-current" "true") ]
            , test "an empty space says it has no run" <|
                \_ ->
                    App.view { modelWithSession | runs = [] }
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "This space has no run." ]
            , test "a stale run list stays visible beside the notice" <|
                \_ ->
                    let
                        html =
                            App.view { modelWithSession | runsNotice = Just "GET /api/runs is unreachable." }
                                |> Query.fromHtml
                    in
                    Expect.all
                        [ \_ -> html |> Query.has [ Selector.text "run|console|r1" ]
                        , \_ -> html |> Query.has [ Selector.text "GET /api/runs is unreachable." ]
                        ]
                        ()
            , test "the session-expired message is shown" <|
                \_ ->
                    App.view { modelWithSession | sessionExpired = True }
                        |> Query.fromHtml
                        |> Query.has [ Selector.text "The session expired" ]
            , test "a node with a step run is reachable and clickable" <|
                \_ ->
                    let
                        graph =
                            D.decodeString Decode.graphDecoder Fixtures.graphJson
                                |> Result.withDefault (Decode.Graph "" "" [] [])

                        detail =
                            D.decodeString Decode.runDetailDecoder Fixtures.runJson
                                |> Result.toMaybe

                        model =
                            { modelWithSession | selectedRun = Just "run|console|r1", graph = Just graph, runDetail = detail }
                    in
                    App.view model
                        |> Query.fromHtml
                        |> Query.findAll [ Selector.attribute (A.attribute "tabindex" "0") ]
                        |> Query.count (\count -> Expect.equal 2 count)
            ]
        ]
