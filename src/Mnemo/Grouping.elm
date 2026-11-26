module Mnemo.Grouping exposing (WorkflowGroup, groupRuns)

{-| The run list groups by the run's `workflow`: runs newest first and the
groups by their newest run. The grouping is presentation, so it is pure and
tested without the API.
-}

import Mnemo.Decode exposing (Run)


type alias WorkflowGroup =
    { workflow : String
    , runs : List Run
    }


groupRuns : List Run -> List WorkflowGroup
groupRuns runs =
    List.foldl insert [] (List.sortWith newestFirst runs)


newestFirst : Run -> Run -> Order
newestFirst a b =
    case compare b.started a.started of
        EQ ->
            compare a.key b.key

        order ->
            order


insert : Run -> List WorkflowGroup -> List WorkflowGroup
insert run groups =
    if List.any (\group -> group.workflow == run.workflow) groups then
        List.map
            (\group ->
                if group.workflow == run.workflow then
                    { group | runs = group.runs ++ [ run ] }

                else
                    group
            )
            groups

    else
        groups ++ [ { workflow = run.workflow, runs = [ run ] } ]
