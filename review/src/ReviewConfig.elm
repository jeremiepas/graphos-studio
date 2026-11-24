module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

The rules below are the ones the split of the repo made worth enforcing: dead
code and needlessly complex expressions. `elm-review` runs over `src/` only, so
`NoUnused.Exports` is deliberately absent — helpers that exist for the test
suite would be reported as unused.

-}

import NoUnused.Variables
import Review.Rule exposing (Rule)
import Simplify


config : List Rule
config =
    [ NoUnused.Variables.rule
    , Simplify.rule Simplify.defaults
    ]
