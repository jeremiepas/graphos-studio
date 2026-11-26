module Mnemo.Format exposing (formatTokens)

{-| A compact token total (`1.2k`); the exact number stays in the element's
title, so a person can read both.
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
