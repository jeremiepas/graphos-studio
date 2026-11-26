module Mnemo.Api exposing
    ( Error(..)
    , getGraph
    , getOrchestrator
    , getRun
    , getRuns
    , getSession
    , getStepRun
    , selectSpace
    )

{-| The console's `/api` client. Every read keeps the same-origin session
cookie; the only write is the session's space selection, which carries the
session's `X-CSRF-Token`.
-}

import Http
import Json.Decode as D
import Json.Encode as E
import Mnemo.Decode as Decode exposing (Graph, Orchestrator, Run, RunDetail, Session, StepRunDetail)
import Url


type Error
    = Unauthorized
    | NotFound
    | BadStatus Int
    | BadBody String
    | Network


expectJson : D.Decoder a -> (Result Error a -> msg) -> Http.Expect msg
expectJson decoder toMsg =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ _ ->
                    Err Network

                Http.Timeout_ ->
                    Err Network

                Http.NetworkError_ ->
                    Err Network

                Http.BadStatus_ metadata body ->
                    case metadata.statusCode of
                        401 ->
                            Err Unauthorized

                        404 ->
                            Err NotFound

                        code ->
                            Err (BadStatus code)

                Http.GoodStatus_ _ body ->
                    case D.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (BadBody (D.errorToString err))


getSession : (Result Error Session -> msg) -> Cmd msg
getSession toMsg =
    Http.get
        { url = "/api/session"
        , expect = expectJson Decode.sessionDecoder toMsg
        }


getRuns : (Result Error (List Run) -> msg) -> Cmd msg
getRuns toMsg =
    Http.get
        { url = "/api/runs"
        , expect = expectJson Decode.runsDecoder toMsg
        }


{-| The console's one read of the orchestrator's state: the content of
`mnemo orchestrate status --json` for the selected space. A console that does
not serve it answers `404`, which the page shows as "not served".
-}
getOrchestrator : (Result Error Orchestrator -> msg) -> Cmd msg
getOrchestrator toMsg =
    Http.get
        { url = "/api/orchestrator"
        , expect = expectJson Decode.orchestratorDecoder toMsg
        }


getRun : String -> (Result Error RunDetail -> msg) -> Cmd msg
getRun key toMsg =
    Http.get
        { url = "/api/runs/" ++ Url.percentEncode key
        , expect = expectJson Decode.runDetailDecoder toMsg
        }


getGraph : String -> (Result Error Graph -> msg) -> Cmd msg
getGraph key toMsg =
    Http.get
        { url = "/api/runs/" ++ Url.percentEncode key ++ "/graph"
        , expect = expectJson Decode.graphDecoder toMsg
        }


getStepRun : String -> (Result Error StepRunDetail -> msg) -> Cmd msg
getStepRun key toMsg =
    Http.get
        { url = "/api/step-runs/" ++ Url.percentEncode key
        , expect = expectJson Decode.stepRunDetailDecoder toMsg
        }


selectSpace : { csrf : String, space : String } -> (Result Error Session -> msg) -> Cmd msg
selectSpace config toMsg =
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "X-CSRF-Token" config.csrf
            , Http.header "Accept" "application/json"
            ]
        , url = "/api/session/space"
        , body = Http.jsonBody (E.object [ ( "space", E.string config.space ) ])
        , expect = expectJson Decode.sessionDecoder toMsg
        , timeout = Nothing
        , tracker = Nothing
        }
