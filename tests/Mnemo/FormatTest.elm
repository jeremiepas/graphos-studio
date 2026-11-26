module Mnemo.FormatTest exposing (suite)

import Expect
import Mnemo.Format as Format
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Mnemo.Format.formatTokens"
        [ test "shows a small total exactly" <|
            \_ -> Format.formatTokens 999 |> Expect.equal "999"
        , test "shows thousands compactly" <|
            \_ -> Format.formatTokens 1200 |> Expect.equal "1.2k"
        , test "drops a zero fraction" <|
            \_ -> Format.formatTokens 1000 |> Expect.equal "1k"
        , test "shows millions" <|
            \_ -> Format.formatTokens 1200000 |> Expect.equal "1.2M"
        , test "a run with no token shows 0" <|
            \_ -> Format.formatTokens 0 |> Expect.equal "0"
        ]
