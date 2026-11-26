module Mnemo.Status exposing (Tone(..), label, tone, toneKey)

{-| The colours a status maps to, from the design system's existing tokens.
Every colour is accompanied by its text label, so status is never colour alone.
-}


type Tone
    = Success
    | Danger
    | Warning
    | Accent
    | Muted


tone : String -> Tone
tone status =
    case status of
        "passed" ->
            Success

        "failed" ->
            Danger

        "running" ->
            Accent

        "waiting" ->
            Warning

        "pending" ->
            Muted

        "skipped" ->
            Muted

        _ ->
            Muted


label : String -> String
label status =
    if String.isEmpty status then
        "unknown"

    else
        status


toneKey : Tone -> String
toneKey value =
    case value of
        Success ->
            "success"

        Danger ->
            "danger"

        Warning ->
            "warning"

        Accent ->
            "accent"

        Muted ->
            "muted"
