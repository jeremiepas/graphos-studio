module Mnemo.Decode exposing
    ( CardItem
    , Graph
    , GraphEdge
    , GraphNode
    , Run
    , RunDetail
    , Session
    , Step
    , StepRun
    , StepRunDetail
    , Tokens
    , cardItemDecoder
    , graphDecoder
    , runDecoder
    , runDetailDecoder
    , runsDecoder
    , sessionDecoder
    , stepRunDetailDecoder
    )

{-| The shapes of the console's `/api` routes (`mnemo-console-in-studio` and
`console-spaces`). Every decoder is total: a missing or renamed field is an
error, so the tests fail when the fixtures move.
-}

import Json.Decode as D exposing (Decoder)


type alias Tokens =
    { card : Int
    , prompt : Int
    }


type alias Session =
    { space : String
    , spaces : List String
    , poll : Int
    , csrf : String
    }


type alias Run =
    { key : String
    , workflow : String
    , status : String
    , started : String
    , ended : Maybe String
    , stepRuns : Int
    , waiting : Int
    , tokens : Tokens
    }


type alias StepRun =
    { key : String
    , item : Maybe Int
    , attempt : Int
    , status : String
    , reason : Maybe String
    , started : String
    , ended : Maybe String
    }


type alias Step =
    { id : String
    , status : String
    , reason : Maybe String
    , stepRuns : List StepRun
    }


type alias RunDetail =
    { run : Run
    , steps : List Step
    }


type alias GraphNode =
    { id : String
    , executor : String
    , layer : Int
    , foreach : Bool
    }


type alias GraphEdge =
    { from : String
    , to : String
    , implied : Bool
    }


type alias Graph =
    { run : String
    , workflow : String
    , nodes : List GraphNode
    , edges : List GraphEdge
    }


type alias StepRunDetail =
    { key : String
    , status : String
    , attempt : Int
    , reason : Maybe String
    , cardTokens : Int
    , promptTokens : Int
    }


type alias CardItem =
    { key : String
    , tier : Maybe Int
    , score : Maybe Float
    , reason : Maybe String
    }


tokensDecoder : Decoder Tokens
tokensDecoder =
    D.map2 Tokens
        (D.field "card" D.int)
        (D.field "prompt" D.int)


sessionDecoder : Decoder Session
sessionDecoder =
    D.map4 Session
        (D.field "space" D.string)
        (D.field "spaces" (D.list D.string))
        (D.oneOf [ D.field "poll" D.int, D.field "poll_seconds" D.int ])
        (D.oneOf [ D.field "csrf" D.string, D.field "csrf_token" D.string ])


runDecoder : Decoder Run
runDecoder =
    D.map8 Run
        (D.field "key" D.string)
        (D.field "workflow" D.string)
        (D.field "status" D.string)
        (D.field "started" D.string)
        (D.maybe (D.field "ended" D.string))
        (D.field "step_runs" D.int)
        (D.field "waiting" D.int)
        (D.field "tokens" tokensDecoder)


runsDecoder : Decoder (List Run)
runsDecoder =
    D.field "runs" (D.list runDecoder)


stepRunDecoder : Decoder StepRun
stepRunDecoder =
    D.map7 StepRun
        (D.field "key" D.string)
        (D.maybe (D.field "item" D.int))
        (D.field "attempt" D.int)
        (D.field "status" D.string)
        (D.maybe (D.field "reason" D.string))
        (D.field "started" D.string)
        (D.maybe (D.field "ended" D.string))


stepDecoder : Decoder Step
stepDecoder =
    D.map4 Step
        (D.field "id" D.string)
        (D.field "status" D.string)
        (D.maybe (D.field "reason" D.string))
        (D.field "step_runs" (D.list stepRunDecoder))


runDetailDecoder : Decoder RunDetail
runDetailDecoder =
    D.map2 RunDetail
        (D.field "run" runDecoder)
        (D.field "steps" (D.list stepDecoder))


graphNodeDecoder : Decoder GraphNode
graphNodeDecoder =
    D.map4 GraphNode
        (D.field "id" D.string)
        (D.field "executor" D.string)
        (D.field "layer" D.int)
        (D.field "foreach" D.bool)


graphEdgeDecoder : Decoder GraphEdge
graphEdgeDecoder =
    D.map3 GraphEdge
        (D.field "from" D.string)
        (D.field "to" D.string)
        (D.field "implied" D.bool)


graphDecoder : Decoder Graph
graphDecoder =
    D.map4 Graph
        (D.field "run" D.string)
        (D.field "workflow" D.string)
        (D.field "nodes" (D.list graphNodeDecoder))
        (D.field "edges" (D.list graphEdgeDecoder))


stepRunDetailDecoder : Decoder StepRunDetail
stepRunDetailDecoder =
    D.map6 StepRunDetail
        (D.field "key" D.string)
        (D.field "status" D.string)
        (D.field "attempt" D.int)
        (D.maybe (D.field "reason" D.string))
        (D.oneOf [ D.field "card_tokens" D.int, D.succeed 0 ])
        (D.oneOf [ D.field "prompt_tokens" D.int, D.succeed 0 ])


cardItemDecoder : Decoder CardItem
cardItemDecoder =
    D.map4 CardItem
        (D.field "key" D.string)
        (D.maybe (D.field "tier" D.int))
        (D.maybe (D.field "score" D.float))
        (D.maybe (D.field "reason" D.string))
