module Mnemo.App exposing (Model, Msg(..), init, update, subscriptions, view)

{-| The Mnemo page. The skeleton is replaced group by group by the spaces
panel, the run list and the run graph.
-}

import Html exposing (Html, div, text)
import Html.Attributes as A
import Studio.DesignSystem.Tokens as Tokens exposing (Theme(..))



-- MODEL


type alias Model =
    { theme : Theme
    }



-- MESSAGES


type Msg
    = NoOp



-- INIT / UPDATE


init : () -> ( Model, Cmd Msg )
init _ =
    ( { theme = Light }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ Html.node "style" [] [ text (Tokens.stylesheet model.theme) ]
        , div [ A.class "empty-state" ] [ text "Mnemo" ]
        ]
