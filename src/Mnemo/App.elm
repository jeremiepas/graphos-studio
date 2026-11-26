module Mnemo.App exposing
    ( Model
    , Msg(..)
    , init
    , initialModel
    , subscriptions
    , update
    , view
    )

{-| The Mnemo page: the console's spaces on the left, the workflows and their
runs with status and token use, and the read-only graph of the selected run.
The session holds the selected space; the only write is its selection.
-}

import Dict
import Html exposing (Html, button, code, div, span, text)
import Html.Attributes as A
import Html.Events as Ev
import Json.Decode as D
import Mnemo.Api as Api
import Mnemo.Decode as Decode exposing (Graph, Orchestrator, Run, RunDetail, Session, StepRunDetail)
import Mnemo.Format as Format
import Mnemo.Grouping as Grouping
import Mnemo.Layout as Layout
import Mnemo.Orchestrator as Orchestrator
import Mnemo.Status as Status
import Studio.DesignSystem.Components as UI
import Studio.DesignSystem.Tokens as Tokens exposing (Theme(..))
import Svg
import Svg.Attributes as SA
import Svg.Events as SE
import Time



-- MODEL


type alias Model =
    { theme : Theme
    , session : Maybe Session
    , sessionNotice : Maybe String
    , sessionExpired : Bool
    , runs : List Run
    , runsNotice : Maybe String
    , runsLoading : Bool
    , runsLoaded : Bool
    , selectionNotice : Maybe String
    , selectedRun : Maybe String
    , runDetail : Maybe RunDetail
    , runDetailNotice : Maybe String
    , graph : Maybe Graph
    , graphNotice : Maybe String
    , stepRun : Maybe StepRunDetail
    , stepRunKey : Maybe String
    , stepRunNotice : Maybe String
    , now : Time.Posix
    , orchestrator : Orchestrator.State
    }


initialModel : Model
initialModel =
    { theme = Light
    , session = Nothing
    , sessionNotice = Nothing
    , sessionExpired = False
    , runs = []
    , runsNotice = Nothing
    , runsLoading = False
    , runsLoaded = False
    , selectionNotice = Nothing
    , selectedRun = Nothing
    , runDetail = Nothing
    , runDetailNotice = Nothing
    , graph = Nothing
    , graphNotice = Nothing
    , stepRun = Nothing
    , stepRunKey = Nothing
    , stepRunNotice = Nothing
    , now = Time.millisToPosix 0
    , orchestrator = Orchestrator.Loading
    }



-- MESSAGES


type Msg
    = GotSession (Result Api.Error Session)
    | GotSpace (Result Api.Error Session)
    | SelectSpace String
    | GotRuns (Result Api.Error (List Run))
    | GotOrchestrator (Result Api.Error Orchestrator)
    | Poll Time.Posix
    | SelectRun String
    | GotRun (Result Api.Error RunDetail)
    | GotGraph (Result Api.Error Graph)
    | OpenStepRun String
    | GotStepRun (Result Api.Error StepRunDetail)
    | Retry



-- INIT / UPDATE


init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, Api.getSession GotSession )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSession (Ok session) ->
            ( { model
                | session = Just session
                , sessionNotice = Nothing
                , sessionExpired = False
                , runsLoading = True
                , orchestrator = Orchestrator.Loading
              }
            , Cmd.batch [ Api.getRuns GotRuns, Api.getOrchestrator GotOrchestrator ]
            )

        GotSession (Err Api.Unauthorized) ->
            ( { model | sessionExpired = True, sessionNotice = Nothing }
            , Cmd.none
            )

        GotSession (Err err) ->
            ( { model | sessionNotice = Just (describeError "/api/session" err) }
            , Cmd.none
            )

        SelectSpace name ->
            case model.session of
                Nothing ->
                    ( model, Cmd.none )

                Just session ->
                    if session.space == name then
                        ( model, Cmd.none )

                    else
                        ( { model | selectionNotice = Nothing }
                        , Api.selectSpace { csrf = session.csrf, space = name } GotSpace
                        )

        GotSpace (Ok session) ->
            ( { model
                | session = Just session
                , selectionNotice = Nothing
                , runsLoading = True
                , runsNotice = Nothing
                , selectedRun = Nothing
                , runDetail = Nothing
                , runDetailNotice = Nothing
                , graph = Nothing
                , graphNotice = Nothing
                , stepRun = Nothing
                , stepRunKey = Nothing
                , stepRunNotice = Nothing
                , orchestrator = Orchestrator.Loading
              }
            , Cmd.batch [ Api.getRuns GotRuns, Api.getOrchestrator GotOrchestrator ]
            )

        GotSpace (Err Api.Unauthorized) ->
            ( { model
                | sessionExpired = True
                , selectionNotice = Just "The session expired; the space did not change."
              }
            , Cmd.none
            )

        GotSpace (Err err) ->
            ( { model | selectionNotice = Just (describeError "/api/session/space" err) }
            , Cmd.none
            )

        GotRuns (Ok runs) ->
            ( { model
                | runs = runs
                , runsNotice = Nothing
                , runsLoading = False
                , runsLoaded = True
              }
            , Cmd.none
            )

        GotRuns (Err Api.Unauthorized) ->
            ( { model
                | sessionExpired = True
                , runsNotice = Just "401 from /api/runs: the session expired; the last runs stay below."
                , runsLoading = False
              }
            , Cmd.none
            )

        GotRuns (Err err) ->
            ( { model
                | runsNotice = Just (describeError "/api/runs" err ++ " The last runs stay below.")
                , runsLoading = False
              }
            , Cmd.none
            )

        GotOrchestrator (Ok report) ->
            ( { model | orchestrator = Orchestrator.Loaded { report = report, readAt = model.now } }
            , Cmd.none
            )

        GotOrchestrator (Err Api.Unauthorized) ->
            ( { model | sessionExpired = True }
            , Cmd.none
            )

        GotOrchestrator (Err Api.NotFound) ->
            ( { model | orchestrator = Orchestrator.NotServed }
            , Cmd.none
            )

        GotOrchestrator (Err err) ->
            let
                message =
                    describeError "/api/orchestrator" err
            in
            ( { model
                | orchestrator =
                    case model.orchestrator of
                        Orchestrator.Loaded loaded ->
                            Orchestrator.Stale
                                { report = Just loaded.report
                                , readAt = loaded.readAt
                                , notice = message ++ " The last state stays."
                                }

                        Orchestrator.Stale stale ->
                            Orchestrator.Stale { stale | notice = message ++ " The last state stays." }

                        _ ->
                            Orchestrator.Stale { report = Nothing, readAt = model.now, notice = message }
              }
            , Cmd.none
            )

        Poll posix ->
            case model.session of
                Nothing ->
                    ( { model | now = posix }, Cmd.none )

                Just _ ->
                    ( { model | now = posix }
                    , Cmd.batch
                        (Api.getRuns GotRuns
                            :: Api.getOrchestrator GotOrchestrator
                            :: (case model.selectedRun of
                                    Just key ->
                                        [ Api.getRun key GotRun ]

                                    Nothing ->
                                        []
                               )
                        )
                    )

        SelectRun key ->
            if model.selectedRun == Just key then
                ( model, Cmd.none )

            else
                let
                    cached =
                        Maybe.map .run model.graph == Just key
                in
                ( { model
                    | selectedRun = Just key
                    , runDetail = Nothing
                    , runDetailNotice = Nothing
                    , graph = if cached then model.graph else Nothing
                    , graphNotice = Nothing
                    , stepRun = Nothing
                    , stepRunKey = Nothing
                    , stepRunNotice = Nothing
                  }
                , Cmd.batch
                    (Api.getRun key GotRun
                        :: (if cached then
                                []

                            else
                                [ Api.getGraph key GotGraph ]
                           )
                    )
                )

        GotRun (Ok detail) ->
            ( { model | runDetail = Just detail, runDetailNotice = Nothing }
            , Cmd.none
            )

        GotRun (Err Api.Unauthorized) ->
            ( { model
                | sessionExpired = True
                , runDetailNotice = Just "401 from /api/runs/<run>: the session expired."
              }
            , Cmd.none
            )

        GotRun (Err err) ->
            ( { model | runDetailNotice = Just (describeError "/api/runs/<run>" err) }
            , Cmd.none
            )

        GotGraph (Ok graph) ->
            ( { model | graph = Just graph, graphNotice = Nothing }
            , Cmd.none
            )

        GotGraph (Err Api.Unauthorized) ->
            ( { model
                | sessionExpired = True
                , graph = Nothing
                , graphNotice = Just "401 from /api/runs/<run>/graph: the session expired."
              }
            , Cmd.none
            )

        GotGraph (Err err) ->
            ( { model
                | graph = Nothing
                , graphNotice = Just (describeError "/api/runs/<run>/graph" err)
              }
            , Cmd.none
            )

        OpenStepRun key ->
            ( { model | stepRunKey = Just key, stepRunNotice = Nothing }
            , Api.getStepRun key GotStepRun
            )

        GotStepRun (Ok detail) ->
            ( { model | stepRun = Just detail, stepRunNotice = Nothing }
            , Cmd.none
            )

        GotStepRun (Err Api.Unauthorized) ->
            ( { model
                | sessionExpired = True
                , stepRunNotice = Just "401 from /api/step-runs/<step-run>: the session expired."
              }
            , Cmd.none
            )

        GotStepRun (Err err) ->
            ( { model | stepRunNotice = Just (describeError "/api/step-runs/<step-run>" err) }
            , Cmd.none
            )

        Retry ->
            let
                runsCommand =
                    if model.session == Nothing || model.sessionExpired then
                        [ Api.getSession GotSession ]

                    else
                        [ Api.getRuns GotRuns, Api.getOrchestrator GotOrchestrator ]

                detailCommand =
                    case model.selectedRun of
                        Just key ->
                            if model.session == Nothing || model.sessionExpired then
                                []

                            else
                                [ Api.getRun key GotRun ]

                        Nothing ->
                            []

                graphCommand =
                    case ( model.selectedRun, model.graph ) of
                        ( Just key, Just graph ) ->
                            if graph.run == key || model.session == Nothing || model.sessionExpired then
                                []

                            else
                                [ Api.getGraph key GotGraph ]

                        ( Just key, Nothing ) ->
                            if model.session == Nothing || model.sessionExpired then
                                []

                            else
                                [ Api.getGraph key GotGraph ]

                        ( Nothing, _ ) ->
                            []

                stepRunCommand =
                    case model.stepRunKey of
                        Just key ->
                            if model.session == Nothing || model.sessionExpired then
                                []

                            else
                                [ Api.getStepRun key GotStepRun ]

                        Nothing ->
                            []
            in
            ( clearNotices model
            , Cmd.batch (runsCommand ++ detailCommand ++ graphCommand ++ stepRunCommand)
            )


clearNotices : Model -> Model
clearNotices model =
    { model
        | sessionNotice = Nothing
        , runsNotice = Nothing
        , selectionNotice = Nothing
        , runDetailNotice = Nothing
        , graphNotice = Nothing
        , stepRunNotice = Nothing
    }


describeError : String -> Api.Error -> String
describeError route err =
    case err of
        Api.Unauthorized ->
            "401 from " ++ route ++ ": the session expired."

        Api.NotFound ->
            "404 from " ++ route ++ "."

        Api.BadStatus code ->
            "HTTP " ++ String.fromInt code ++ " from " ++ route ++ "."

        Api.BadBody message ->
            "The answer of " ++ route ++ " did not decode: " ++ message

        Api.Network ->
            route ++ " is unreachable."


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.sessionExpired then
        Sub.none

    else
        case model.session of
            Just session ->
                Time.every (toFloat (max 1 session.poll) * 1000) Poll

            Nothing ->
                Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div [ A.class "mnemo-shell" ]
        [ Html.node "style" [] [ text (Tokens.stylesheet model.theme) ]
        , viewHeader model
        , div [ A.class "mnemo-main" ]
            [ viewSpaces model
            , viewRuns model
            , viewDetail model
            ]
        ]


viewHeader : Model -> Html Msg
viewHeader model =
    div [ A.class "mnemo-header" ]
        ([ span [ A.class "mnemo-title" ] [ text "Mnemo" ]
         , span [ A.class "muted" ]
            [ text
                (case model.session of
                    Just session ->
                        "space " ++ session.space

                    Nothing ->
                        "no session"
                )
            ]
         ]
            ++ (case model.session of
                    Just _ ->
                        [ span [ A.class "muted", A.id "orchestrator-state" ]
                            [ text (" · " ++ Orchestrator.stateText model.orchestrator) ]
                        ]

                    Nothing ->
                        []
               )
            ++ (if model.sessionExpired then
                    [ notice "mnemo-notice-error" "The session expired. Reopen the one-time URL the console printed to start a new one." ]

                else
                    []
               )
            ++ List.filterMap identity
                [ Maybe.map (notice "mnemo-notice-error") model.sessionNotice
                , Maybe.map (notice "mnemo-notice") model.selectionNotice
                ]
        )


viewSpaces : Model -> Html Msg
viewSpaces model =
    div [ A.class "mnemo-spaces" ]
        [ UI.panel "Spaces"
            [ case model.session of
                Nothing ->
                    UI.emptyState "No space: the page has no session."

                Just session ->
                    div [ A.class "mnemo-space-list" ]
                        (List.map
                            (\name ->
                                UI.navItem
                                    { label = name
                                    , selected = name == session.space
                                    , onPress = SelectSpace name
                                    }
                            )
                            session.spaces
                        )
            ]
        ]


viewRuns : Model -> Html Msg
viewRuns model =
    div [ A.class "mnemo-runs" ] <|
        viewOrchestrator model
            :: (Maybe.map (notice "mnemo-notice") model.runsNotice
                    |> Maybe.withDefault (text "")
               )
            :: (if List.isEmpty model.runs then
                    [ if model.session == Nothing then
                        UI.emptyState "No session."

                      else if model.sessionExpired then
                        text ""

                      else if model.runsLoading then
                        UI.emptyState "Loading runs…"

                      else if model.runsNotice == Nothing then
                        UI.emptyState "This space has no run."

                      else
                        text ""
                    ]

                else
                    List.map (viewGroup model.selectedRun) (Grouping.groupRuns model.runs)
               )



viewOrchestrator : Model -> Html Msg
viewOrchestrator model =
    div [ A.class "mnemo-orchestrator" ]
        [ UI.panel "Orchestrator" (viewOrchestratorBody model) ]


viewOrchestratorBody : Model -> List (Html Msg)
viewOrchestratorBody model =
    case model.session of
        Nothing ->
            [ text "" ]

        Just _ ->
            if model.sessionExpired then
                [ text "" ]

            else
                case model.orchestrator of
                    Orchestrator.Loading ->
                        [ UI.emptyState "Loading the orchestrator's state…" ]

                    Orchestrator.NotServed ->
                        [ div [ A.class "mnemo-orchestrator-state" ]
                            [ text "This console does not serve the orchestrator's state (GET /api/orchestrator)." ]
                        ]

                    Orchestrator.Stale stale ->
                        (notice "mnemo-notice" stale.notice)
                            :: (case stale.report of
                                    Nothing ->
                                        []

                                    Just report ->
                                        viewOrchestratorReport model (Just stale.readAt) report
                               )

                    Orchestrator.Loaded loaded ->
                        viewOrchestratorReport model Nothing loaded.report


viewOrchestratorReport : Model -> Maybe Time.Posix -> Orchestrator -> List (Html Msg)
viewOrchestratorReport model staleReadAt orchestrator =
    div [ A.class "mnemo-orchestrator-state" ]
        [ text (Orchestrator.stateText model.orchestrator) ]
        :: (staleLine staleReadAt
                ++ viewHeartbeat model orchestrator
                ++ [ div [ A.class "mnemo-run-meta" ]
                        [ text
                            ("Causes: "
                                ++ (if List.isEmpty orchestrator.causes then
                                        "none"

                                    else
                                        String.join ", " orchestrator.causes
                                   )
                            )
                        ]
                   ]
                ++ viewOrchestratorRuns model orchestrator
           )


viewOrchestratorRuns : Model -> Orchestrator -> List (Html Msg)
viewOrchestratorRuns model orchestrator =
    if List.isEmpty orchestrator.runs then
        [ UI.emptyState "No run is left to move." ]

    else
        List.map (viewOrchestratorRun model) orchestrator.runs


viewOrchestratorRun : Model -> Decode.OrchestratorRun -> Html Msg
viewOrchestratorRun model run =
    let
        key =
            fullKeyFor model.runs run.run

        workflow =
            workflowFor model.runs run.run
    in
    div [ A.class "mnemo-orchestrator-run" ]
        ([ div [ A.class "mnemo-run-head" ]
            [ span [ A.class "mnemo-run-title", A.title run.run ] [ text run.run ]
            , span [ A.class "mnemo-orchestrator-badges" ]
                [ statusBadge run.status
                , span [ A.title run.reason ]
                    [ UI.badge (Orchestrator.toneKey run.word) (Orchestrator.labelWord run.word) ]
                ]
            ]
         , div [ A.class "mnemo-run-meta" ]
            [ text
                ((Maybe.withDefault "workflow unknown" workflow)
                    ++ " · "
                    ++ run.status
                    ++ " · "
                    ++ Orchestrator.labelWord run.word
                )
            ]
         , div [ A.class "mnemo-orchestrator-reason" ] [ text run.reason ]
         , div [ A.class "mnemo-run-meta" ] [ text (Orchestrator.wordExplanation run.word) ]
         ]
            ++ (case run.logFile of
                    Nothing ->
                        []

                    Just path ->
                        [ div [ A.class "mnemo-orchestrator-log" ]
                            [ text "Output file: "
                            , code [ A.class "mnemo-copy" ] [ text path ]
                            ]
                        ]
               )
            ++ [ div [ A.class "mnemo-orchestrator-open" ]
                    [ UI.btn { label = "Open run", enabled = True, onPress = SelectRun key } ]
               ]
        )


workflowFor : List Run -> String -> Maybe String
workflowFor runs name =
    runs
        |> List.filter (runMatches name)
        |> List.head
        |> Maybe.map .workflow


fullKeyFor : List Run -> String -> String
fullKeyFor runs name =
    runs
        |> List.filter (runMatches name)
        |> List.head
        |> Maybe.map .key
        |> Maybe.withDefault name


runMatches : String -> Run -> Bool
runMatches name run =
    run.key == name || Orchestrator.localName run.key == name


staleLine : Maybe Time.Posix -> List (Html Msg)
staleLine staleReadAt =
    case staleReadAt of
        Nothing ->
            []

        Just readAt ->
            [ div [ A.class "mnemo-run-meta" ]
                [ text ("Stale: last read " ++ Format.isoFromMillis (Time.posixToMillis readAt) ++ ".") ]
            ]


viewHeartbeat : Model -> Orchestrator -> List (Html Msg)
viewHeartbeat model orchestrator =
    case orchestrator.lastHeartbeat of
        Nothing ->
            [ div [ A.class "mnemo-run-meta" ] [ text "No heartbeat has been recorded." ] ]

        Just time ->
            [ div [ A.class "mnemo-orchestrator-heartbeat" ]
                [ text
                    ("Last heartbeat "
                        ++ time
                        ++ (case Orchestrator.heartbeatAge model.now time of
                                Just age ->
                                    " (" ++ age ++ ")"

                                Nothing ->
                                    ""
                           )
                        ++ (case orchestrator.sequence of
                                Just sequence ->
                                    ", sequence " ++ String.fromInt sequence

                                Nothing ->
                                    ""
                           )
                    )
                ]
            , div [ A.class "mnemo-run-meta" ] [ text (countsText orchestrator) ]
            ]


countsText : Orchestrator -> String
countsText orchestrator =
    let
        count label value =
            Maybe.map (\number -> String.fromInt number ++ " " ++ label) value

        parts =
            List.filterMap identity
                [ count "held" orchestrator.held
                , count "launched" orchestrator.launched
                , count "left to a person" orchestrator.leftToPerson
                ]
    in
    if List.isEmpty parts then
        "The heartbeat records no count."

    else
        "The heartbeat: " ++ String.join ", " parts ++ "."


viewGroup : Maybe String -> Grouping.WorkflowGroup -> Html Msg
viewGroup selectedRun group =
    div [ A.class "mnemo-group" ]
        [ div [ A.class "mnemo-group-title" ] [ text group.workflow ]
        , div [] (List.map (viewRun selectedRun) group.runs)
        ]


viewRun : Maybe String -> Run -> Html Msg
viewRun selectedRun run =
    button
        [ A.class
            ("mnemo-run"
                ++ (if selectedRun == Just run.key then
                        " mnemo-run-selected"

                    else
                        ""
                   )
            )
        , A.type_ "button"
        , A.attribute "aria-pressed" (if selectedRun == Just run.key then "true" else "false")
        , Ev.onClick (SelectRun run.key)
        ]
        [ div [ A.class "mnemo-run-head" ]
            [ span [ A.class "mnemo-run-title", A.title run.key ] [ text run.key ]
            , statusBadge run.status
            ]
        , div [ A.class "mnemo-run-meta" ]
            [ text ("started " ++ run.started)
            , text " · "
            , text ("ended " ++ Maybe.withDefault "—" run.ended)
            ]
        , div [ A.class "mnemo-run-meta" ]
            [ text (String.fromInt run.stepRuns ++ " step runs · " ++ String.fromInt run.waiting ++ " waiting") ]
        , div [ A.class "mnemo-run-tokens" ]
            [ span [ A.title (String.fromInt run.tokens.card ++ " card tokens") ]
                [ text ("card " ++ Format.formatTokens run.tokens.card) ]
            , span [ A.title (String.fromInt run.tokens.prompt ++ " prompt tokens") ]
                [ text ("prompt " ++ Format.formatTokens run.tokens.prompt) ]
            ]
        ]


viewDetail : Model -> Html Msg
viewDetail model =
    div [ A.class "mnemo-detail" ] <|
        [ Maybe.map (notice "mnemo-notice") model.runDetailNotice
            |> Maybe.withDefault (text "")
        , case model.selectedRun of
            Nothing ->
                UI.emptyState "Select a run to see its graph."

            Just _ ->
                viewSelectedRun model
        ]


viewSelectedRun : Model -> Html Msg
viewSelectedRun model =
    case model.graphNotice of
        Just message ->
            notice "mnemo-notice-error" message

        Nothing ->
            case model.graph of
                Nothing ->
                    UI.emptyState "Loading the graph…"

                Just graph ->
                    viewGraph model graph


viewGraph : Model -> Graph -> Html Msg
viewGraph model graph =
    let
        result =
            Layout.layout graph

        positionById =
            Dict.fromList (List.map (\position -> ( position.node.id, position )) result.nodes)

        statusById =
            case model.runDetail of
                Just detail ->
                    Dict.fromList (List.map (\step -> ( step.id, step.status )) detail.steps)

                Nothing ->
                    Dict.empty

        stepRunByStep =
            case model.runDetail of
                Just detail ->
                    Dict.fromList
                        (List.map
                            (\step -> ( step.id, List.head (List.reverse step.stepRuns) ))
                            detail.steps
                        )

                Nothing ->
                    Dict.empty
    in
    div []
        [ div [ A.class "mnemo-detail-title" ] [ text (graph.workflow ++ " · " ++ graph.run) ]
        , div [ A.class "mnemo-graph-scroll" ]
            [ viewSvg model graph result positionById statusById stepRunByStep ]
        , viewLegend model.theme
        , viewStepRun model
        ]


viewSvg : Model -> Graph -> Layout.Layout -> Dict.Dict String Layout.NodePosition -> Dict.Dict String String -> Dict.Dict String (Maybe Decode.StepRun) -> Html Msg
viewSvg model graph result positionById statusById stepRunByStep =
    let
        tokens =
            Tokens.tokens model.theme
    in
    Svg.svg
        [ SA.width (String.fromInt result.width)
        , SA.height (String.fromInt result.height)
        , SA.viewBox ("0 0 " ++ String.fromInt result.width ++ " " ++ String.fromInt result.height)
        , SA.class "mnemo-graph"
        , A.attribute "role" "img"
        , A.attribute "aria-label" ("Graph of " ++ graph.workflow)
        ]
        (List.map (viewEdge tokens positionById) graph.edges
            ++ List.map (viewNode tokens statusById stepRunByStep) result.nodes
        )


viewEdge : Tokens.Tokens -> Dict.Dict String Layout.NodePosition -> Decode.GraphEdge -> Svg.Svg Msg
viewEdge tokens positions edge =
    case ( Dict.get edge.from positions, Dict.get edge.to positions ) of
        ( Just source, Just target ) ->
            Svg.line
                ([ SA.x1 (String.fromInt (source.x + Layout.nodeWidth // 2))
                 , SA.y1 (String.fromInt (source.y + Layout.nodeHeight // 2))
                 , SA.x2 (String.fromInt (target.x + Layout.nodeWidth // 2))
                 , SA.y2 (String.fromInt (target.y + Layout.nodeHeight // 2))
                 , SA.stroke
                    (if edge.implied then
                        tokens.canvasEdge

                     else
                        tokens.textMuted
                    )
                 , SA.strokeWidth "1.5"
                 ]
                    ++ (if edge.implied then
                            [ SA.strokeDasharray "5 4" ]

                        else
                            []
                       )
                )
                []

        _ ->
            Svg.g [] []


viewNode : Tokens.Tokens -> Dict.Dict String String -> Dict.Dict String (Maybe Decode.StepRun) -> Layout.NodePosition -> Svg.Svg Msg
viewNode tokens statusById stepRunByStep position =
    let
        status =
            Dict.get position.node.id statusById |> Maybe.withDefault "pending"

        fill =
            toneColor tokens (Status.tone status)

        stepRun =
            Dict.get position.node.id stepRunByStep |> Maybe.withDefault Nothing

        statusText =
            Status.label status
                ++ (if position.node.foreach then
                        " · fans out"

                    else
                        ""
                   )

        baseAttributes =
            [ SA.class
                ("mnemo-node"
                    ++ (if stepRun == Nothing then
                            ""

                        else
                            " mnemo-node-clickable"
                       )
                )
            ]

        interactiveAttributes =
            case stepRun of
                Nothing ->
                    []

                Just record ->
                    [ A.attribute "tabindex" "0"
                    , A.attribute "role" "button"
                    , A.attribute "aria-label"
                        (position.node.id ++ ", " ++ statusText ++ ", open the step run")
                    , SE.onClick (OpenStepRun record.key)
                    , SE.on "keydown" (activationDecoder (OpenStepRun record.key))
                    ]
    in
    Svg.g (baseAttributes ++ interactiveAttributes)
        [ Svg.rect
            [ SA.x (String.fromInt position.x)
            , SA.y (String.fromInt position.y)
            , SA.width (String.fromInt Layout.nodeWidth)
            , SA.height (String.fromInt Layout.nodeHeight)
            , SA.rx "6"
            , SA.ry "6"
            , SA.fill fill
            , SA.stroke tokens.border
            , SA.strokeWidth "1"
            ]
            []
        , Svg.text_
            [ SA.x (String.fromInt (position.x + 10))
            , SA.y (String.fromInt (position.y + 21))
            , SA.fill tokens.accentText
            , SA.fontSize (String.fromInt tokens.fontSm)
            , SA.fontWeight "600"
            ]
            [ Svg.text position.node.id ]
        , Svg.text_
            [ SA.x (String.fromInt (position.x + 10))
            , SA.y (String.fromInt (position.y + 38))
            , SA.fill tokens.accentText
            , SA.fontSize (String.fromInt tokens.fontXs)
            ]
            [ Svg.text statusText ]
        ]


activationDecoder : msg -> D.Decoder msg
activationDecoder msg =
    D.field "key" D.string
        |> D.andThen
            (\key ->
                if key == "Enter" || key == " " then
                    D.succeed msg

                else
                    D.fail "ignored key"
            )


toneColor : Tokens.Tokens -> Status.Tone -> String
toneColor tokens tone =
    case tone of
        Status.Success ->
            tokens.success

        Status.Danger ->
            tokens.danger

        Status.Warning ->
            tokens.warning

        Status.Accent ->
            tokens.accent

        Status.Muted ->
            tokens.textMuted


viewLegend : Theme -> Html Msg
viewLegend theme =
    let
        tokens =
            Tokens.tokens theme
    in
    div [ A.class "mnemo-legend" ]
        (List.map
            (\status ->
                div [ A.class "mnemo-legend-item" ]
                    [ span
                        [ A.class "mnemo-swatch"
                        , A.style "background" (toneColor tokens (Status.tone status))
                        ]
                        []
                    , span [] [ text (Status.label status) ]
                    ]
            )
            [ "passed", "failed", "running", "waiting", "pending", "skipped" ]
            ++ [ div [ A.class "mnemo-legend-item" ]
                    [ span [ A.class "mnemo-swatch mnemo-swatch-implied" ] []
                    , span [] [ text "implied dependency" ]
                    ]
               ]
        )


viewStepRun : Model -> Html Msg
viewStepRun model =
    case model.stepRunNotice of
        Just message ->
            notice "mnemo-notice-error" message

        Nothing ->
            case model.stepRun of
                Nothing ->
                    div [ A.class "muted" ]
                        [ text "Select a step node with a step run to see its status, attempt and token use." ]

                Just detail ->
                    UI.panel "Step run"
                        [ div [ A.class "mnemo-run-head" ]
                            [ span [ A.class "mnemo-run-title" ] [ text detail.key ]
                            , statusBadge detail.status
                            ]
                        , div [ A.class "mnemo-run-meta" ]
                            [ text ("attempt " ++ String.fromInt detail.attempt) ]
                        , div [ A.class "mnemo-run-tokens" ]
                            [ span [ A.title (String.fromInt detail.cardTokens ++ " card tokens") ]
                                [ text ("card " ++ Format.formatTokens detail.cardTokens) ]
                            , span [ A.title (String.fromInt detail.promptTokens ++ " prompt tokens") ]
                                [ text ("prompt " ++ Format.formatTokens detail.promptTokens) ]
                            ]
                        , case detail.reason of
                            Nothing ->
                                text ""

                            Just reason ->
                                div [ A.class "mnemo-run-meta" ] [ text ("reason " ++ reason) ]
                        ]


statusBadge : String -> Html Msg
statusBadge status =
    UI.badge (Status.toneKey (Status.tone status)) (Status.label status)


notice : String -> String -> Html Msg
notice level message =
    div [ A.class level ]
        [ span [] [ text message ]
        , UI.btn { label = "Retry", enabled = True, onPress = Retry }
        ]
