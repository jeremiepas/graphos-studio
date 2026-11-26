module Mnemo.Layout exposing (Layout, NodePosition, layout, nodeHeight, nodeWidth)

{-| The pure layout of a run's graph: a node's column is its layer, its row is
its order among the nodes of that layer. The page only draws what this returns,
so the layout is tested without a renderer.
-}

import Dict exposing (Dict)
import Mnemo.Decode exposing (Graph, GraphNode)


type alias NodePosition =
    { node : GraphNode
    , x : Int
    , y : Int
    }


type alias Layout =
    { nodes : List NodePosition
    , width : Int
    , height : Int
    }


nodeWidth : Int
nodeWidth =
    168


nodeHeight : Int
nodeHeight =
    52


columnGap : Int
columnGap =
    88


rowGap : Int
rowGap =
    36


margin : Int
margin =
    32


layout : Graph -> Layout
layout graph =
    let
        indexed =
            Tuple.second (List.foldl indexNode ( Dict.empty, [] ) graph.nodes)

        maxLayer =
            List.foldl (\node current -> max current node.layer) 0 graph.nodes

        rowCounts =
            List.foldl
                (\node counts ->
                    Dict.update node.layer (\held -> Just (Maybe.withDefault 0 held + 1)) counts
                )
                Dict.empty
                graph.nodes

        maxRows =
            Dict.foldl (\_ count current -> max current count) 0 rowCounts

        positions =
            List.map
                (\( node, row ) ->
                    { node = node
                    , x = margin + node.layer * (nodeWidth + columnGap)
                    , y = margin + row * (nodeHeight + rowGap)
                    }
                )
                indexed
    in
    { nodes = positions
    , width =
        if List.isEmpty graph.nodes then
            0

        else
            margin * 2 + nodeWidth + maxLayer * (nodeWidth + columnGap)

    , height =
        if List.isEmpty graph.nodes then
            0

        else
            margin * 2 + maxRows * nodeHeight + (maxRows - 1) * rowGap
    }


indexNode : GraphNode -> ( Dict Int Int, List ( GraphNode, Int ) ) -> ( Dict Int Int, List ( GraphNode, Int ) )
indexNode node ( seen, acc ) =
    let
        row =
            Dict.get node.layer seen |> Maybe.withDefault 0
    in
    ( Dict.insert node.layer (row + 1) seen
    , acc ++ [ ( node, row ) ]
    )
