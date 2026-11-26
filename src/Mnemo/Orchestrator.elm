module Mnemo.Orchestrator exposing
    ( State(..)
    , heartbeatAge
    , labelWord
    , localName
    , report
    , stateText
    , toneKey
    , wordExplanation
    , wordFor
    )

{-| The orchestrator view's state and the one word of each run that is not
final. The page repeats what the console says: it never guesses liveness from
the age of a heartbeat, and a word it does not know is shown as given.
-}

import Mnemo.Decode exposing (Orchestrator, OrchestratorRun)
import Mnemo.Format as Format
import Time


{-| The three states of decision 8, plus loading and stale.
-}
type State
    = Loading
    | NotServed
    | Loaded { report : Orchestrator, readAt : Time.Posix }
    | Stale { report : Maybe Orchestrator, readAt : Time.Posix, notice : String }


report : State -> Maybe Orchestrator
report state =
    case state of
        Loaded loaded ->
            Just loaded.report

        Stale stale ->
            stale.report

        Loading ->
            Nothing

        NotServed ->
            Nothing


{-| The one line of state, in the header and at the top of the view.
-}
stateText : State -> String
stateText state =
    case state of
        Loading ->
            "Loading the orchestrator's state…"

        NotServed ->
            "This console does not serve the orchestrator's state"

        Stale _ ->
            "The orchestrator's state is stale"

        Loaded loaded ->
            statusText loaded.report


statusText : Orchestrator -> String
statusText orchestrator =
    if orchestrator.live then
        "An orchestrator holds the space"

    else
        case orchestrator.lastHeartbeat of
            Nothing ->
                "No orchestrator has run on this space"

            Just _ ->
                "No orchestrator holds the space"


{-| The label of a word. A word the page does not know is returned unchanged.
-}
labelWord : String -> String
labelWord word =
    case word of
        "held" ->
            "Held"

        "moves" ->
            "Moves"

        "later" ->
            "Later"

        "waits" ->
            "Waits"

        "failed" ->
            "Failed"

        "remediation" ->
            "Remediation"

        "off" ->
            "Off"

        _ ->
            word


{-| One short sentence per known word, shortened from Mnemo's README.
-}
wordExplanation : String -> String
wordExplanation word =
    case word of
        "held" ->
            "A process works on this run."

        "moves" ->
            "The next heartbeat launches it, for the cause named."

        "later" ->
            "It is not due yet; the reason says why and when."

        "waits" ->
            "A step waits for a person's approval or answer."

        "failed" ->
            "A step failed and no grant lets it continue."

        "remediation" ->
            "Its launches did not take, or its endpoint stays unreachable; the reason says which."

        "off" ->
            "Nothing moves it; the reason says why."

        _ ->
            "Shown as the console gives it; the reason says why."


toneKey : String -> String
toneKey word =
    case word of
        "held" ->
            "accent"

        "moves" ->
            "success"

        "later" ->
            "warning"

        "waits" ->
            "warning"

        "failed" ->
            "danger"

        "remediation" ->
            "danger"

        _ ->
            "muted"


{-| A run of `/api/runs` is `run|space|name`; the status command names the
last segment only.
-}
localName : String -> String
localName key =
    key
        |> String.split "|"
        |> List.reverse
        |> List.head
        |> Maybe.withDefault key


wordFor : List OrchestratorRun -> String -> Maybe OrchestratorRun
wordFor runs key =
    let
        name =
            localName key
    in
    List.filter (\run -> run.run == key || run.run == name) runs
        |> List.head


{-| The age of the last heartbeat, as an age and only as an age.
-}
heartbeatAge : Time.Posix -> String -> Maybe String
heartbeatAge now time =
    time
        |> Format.millisFromIso
        |> Maybe.map
            (\thenMillis ->
                (Time.posixToMillis now - thenMillis) // 1000
                    |> Format.describeAge
            )
