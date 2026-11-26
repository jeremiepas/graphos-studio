module Mnemo.Main exposing (main)

{-| The Mnemo page's entry point: a `Browser.element` with its own model and no
ports. It is built to `public/mnemo/mnemo.js`; the console serves
`public/mnemo/` at `/studio/`.
-}

import Browser
import Mnemo.App as App


main : Program () App.Model App.Msg
main =
    Browser.element
        { init = App.init
        , update = App.update
        , view = App.view
        , subscriptions = App.subscriptions
        }
