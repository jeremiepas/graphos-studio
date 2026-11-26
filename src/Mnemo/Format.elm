module Mnemo.Format exposing (describeAge, formatTokens, isoFromMillis, millisFromIso)

{-| Compact totals and the times of the orchestrator view: the age of a
heartbeat is shown as an age and never changes a state.
-}


formatTokens : Int -> String
formatTokens value =
    if value < 1000 then
        String.fromInt value

    else if value < 1000000 then
        compact (toFloat value / 1000) "k"

    else
        compact (toFloat value / 1000000) "M"


compact : Float -> String -> String
compact value suffix =
    let
        tenths =
            round (value * 10)

        whole =
            tenths // 10

        fraction =
            modBy 10 tenths
    in
    if fraction == 0 then
        String.fromInt whole ++ suffix

    else
        String.fromInt whole ++ "." ++ String.fromInt fraction ++ suffix


{-| The milliseconds of an ISO-8601 UTC time as `mnemo orchestrate status
--json` writes it, `2026-11-26T22:25:08Z`. A time with another shape gives
`Nothing`, so the page shows it as given without an age.
-}
millisFromIso : String -> Maybe Int
millisFromIso iso =
    let
        part offset width =
            String.slice offset (offset + width) iso |> String.toInt

        separators =
            String.slice 4 5 iso
                == "-"
                && String.slice 7 8 iso
                == "-"
                && String.slice 10 11 iso
                == "T"
                && String.slice 13 14 iso
                == ":"
                && String.slice 16 17 iso
                == ":"
                && String.slice 19 20 iso
                == "Z"
    in
    if String.length iso < 20 || not separators then
        Nothing

    else
        case
            [ part 0 4
            , part 5 2
            , part 8 2
            , part 11 2
            , part 14 2
            , part 17 2
            ]
        of
            [ Just year, Just month, Just day, Just hour, Just minute, Just second ] ->
                Just
                    ((daysFromCivil year month day * 86400
                        + hour * 3600
                        + minute * 60
                        + second
                     )
                        * 1000
                    )

            _ ->
                Nothing


{-| The UTC time of a number of milliseconds since the epoch, in the shape the
console gives (`2026-11-26T22:25:08Z`).
-}
isoFromMillis : Int -> String
isoFromMillis millis =
    let
        totalSeconds =
            floorDiv millis 1000

        days =
            floorDiv totalSeconds 86400

        secondOfDay =
            totalSeconds - days * 86400

        ( year, month, day ) =
            civilFromDays days

        hour =
            secondOfDay // 3600

        minute =
            modBy 60 (secondOfDay // 60)

        second =
            modBy 60 secondOfDay

        pad width value =
            String.padLeft width '0' (String.fromInt value)
    in
    pad 4 year
        ++ "-"
        ++ pad 2 month
        ++ "-"
        ++ pad 2 day
        ++ "T"
        ++ pad 2 hour
        ++ ":"
        ++ pad 2 minute
        ++ ":"
        ++ pad 2 second
        ++ "Z"


{-| A duration in seconds as plain words: `10 minutes old`. The view shows it
beside the heartbeat and draws no conclusion from it.
-}
describeAge : Int -> String
describeAge seconds =
    let
        unit amount singular plural =
            String.fromInt amount ++ " " ++ (if amount == 1 then singular else plural) ++ " old"

        elapsed =
            abs seconds
    in
    if elapsed < 5 then
        "just now"

    else if elapsed < 60 then
        unit elapsed "second" "seconds"

    else if elapsed < 3600 then
        unit (elapsed // 60) "minute" "minutes"

    else if elapsed < 86400 then
        unit (elapsed // 3600) "hour" "hours"

    else
        unit (elapsed // 86400) "day" "days"


floorDiv : Int -> Int -> Int
floorDiv a b =
    let
        quotient =
            a // b

        remainder =
            modBy b a
    in
    if remainder /= 0 && (remainder < 0) /= (b < 0) then
        quotient - 1

    else
        quotient


{-| Days since 1970-01-01, from Howard Hinnant's `days_from_civil`.
-}
daysFromCivil : Int -> Int -> Int -> Int
daysFromCivil year month day =
    let
        adjustedYear =
            if month <= 2 then
                year - 1

            else
                year

        era =
            floorDiv adjustedYear 400

        yearOfEra =
            adjustedYear - era * 400

        dayOfYear =
            (153 * (if month > 2 then month - 3 else month + 9) + 2) // 5 + day - 1

        dayOfEra =
            yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
    in
    era * 146097 + dayOfEra - 719468


{-| The inverse of `daysFromCivil`.
-}
civilFromDays : Int -> ( Int, Int, Int )
civilFromDays days =
    let
        shifted =
            days + 719468

        era =
            floorDiv shifted 146097

        dayOfEra =
            shifted - era * 146097

        yearOfEra =
            (dayOfEra - dayOfEra // 1460 + dayOfEra // 36524 - dayOfEra // 146096) // 365

        year =
            yearOfEra + era * 400

        dayOfYear =
            dayOfEra - (365 * yearOfEra + yearOfEra // 4 - yearOfEra // 100)

        monthPart =
            (5 * dayOfYear + 2) // 153

        day =
            dayOfYear - (153 * monthPart + 2) // 5 + 1

        month =
            if monthPart < 10 then
                monthPart + 3

            else
                monthPart - 9
    in
    ( if month <= 2 then
        year + 1

      else
        year
    , month
    , day
    )
