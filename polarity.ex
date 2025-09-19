defmodule Polarity do

  def polarity(board, specs) do
    # Convert the board tuple into a list of strings for easier handling
    boards = Tuple.to_list(board)
    rows = length(boards)
    cols = String.length(List.first(boards))

    region = convert_board_toList(boards, 0, 0, rows, cols, MapSet.new(), [])

    leftreqs = Map.fetch!(specs, "left")|> Tuple.to_list()
    rightreqs = Map.fetch!(specs, "right")|> Tuple.to_list()
    topreqs = Map.fetch!(specs, "top")|> Tuple.to_list()
    bottomreqs = Map.fetch!(specs, "bottom")|> Tuple.to_list()

    posrowcounts = List.duplicate(0, rows)
    negrowcounts = List.duplicate(0, rows)
    poscolcounts = List.duplicate(0, cols)
    negcolcounts = List.duplicate(0, cols)

    {rowtoregions, coltoregions} = maps_build(region, rows, cols)

    case solve_regions(region,
                      0, MapSet.new(),
                      MapSet.new(), posrowcounts,
                      negrowcounts, poscolcounts,
                      negcolcounts, leftreqs,
                      rightreqs, topreqs,
                      bottomreqs, rowtoregions,
                      coltoregions) do
      {:ok, solution_board} -> solution_board
      :no_solution -> raise "No solution found"
    end
  end

  # Board identification.
  defp convert_board_toList(_boards, currrow, _c, rows, _col_count, _visited, regions) when currrow >= rows do
    Enum.reverse(regions)
  end
  defp convert_board_toList(boards, currrow, currcol, rows, cols, visited, regions) when currcol >= cols do
    convert_board_toList(boards, currrow + 1, 0, rows, cols, visited, regions)
  end
  defp convert_board_toList(boards, currrow, currcol, rows, cols, visited, regions) do
    if MapSet.member?(visited, {currrow, currcol}) do
      convert_board_toList(boards, currrow, currcol + 1, rows, cols, visited, regions)
    else
      case String.at(Enum.at(boards, currrow), currcol) do

        "L" ->
          adjblock = {currrow, currcol + 1}
          visitedblock = MapSet.union(visited, MapSet.new([{currrow, currcol}, adjblock]))
          convert_board_toList(boards,
                      currrow, currcol + 2,
                      rows, cols,
                      visitedblock, [{{currrow, currcol}, adjblock} | regions])

        "T" ->
          adjblock = {currrow + 1, currcol}
          visited_block = MapSet.union(visited, MapSet.new([{currrow, currcol}, adjblock]))
          convert_board_toList(boards,
                      currrow, currcol + 1,
                      rows, cols,
                      visited_block, [{{currrow, currcol}, adjblock} | regions])

        "R" ->
          convert_board_toList(boards,
                      currrow, currcol + 1,
                      rows, cols,
                      MapSet.put(visited, {currrow, currcol}), regions)

        "B" ->
          convert_board_toList(boards,
                      currrow, currcol + 1,
                      rows, cols,
                      MapSet.put(visited, {currrow, currcol}), regions)

      end
    end
  end

  defp maps_build(region, rows, cols) do
    rowtoregions = List.duplicate([], rows)
    coltoregions = List.duplicate([], cols)
    Enum.with_index(region)
    |> Enum.reduce({rowtoregions, coltoregions}, fn {{{r1, c1}, {r2, c2}}, blockindex}, {rowsmap, colsmap} ->
      rowsmap =
        if r1 != r2 do
          rowsmap
          |> List.update_at(r1, &[blockindex | &1])
          |> List.update_at(r2, &[blockindex | &1])
        else
          List.update_at(rowsmap, r1, &[blockindex | &1])
        end
      colsmap =
        if c1 != c2 do
          colsmap
          |> List.update_at(c1, &[blockindex | &1])
          |> List.update_at(c2, &[blockindex | &1])
        else
          List.update_at(colsmap, c1, &[blockindex | &1])
        end
      {rowsmap, colsmap}
    end)
  end

defp solve_regions(region,
                  index, posset,
                  negset, posrowcount,
                  negrowcount, poscolcount,
                  negcolcount, leftreqs,
                  rightreqs, topreqs,
                  bottomreqs, rowtoregions,
                  coltoregions) do
  if index == length(region) do
    if valid_solution?(posrowcount,
                      negrowcount, poscolcount,
                      negcolcount, leftreqs,
                      rightreqs, topreqs,
                      bottomreqs) do
      solvedrows = for {_, currrow} <- Enum.with_index(posrowcount) do
        for currcol <- 0..(length(poscolcount) - 1) do
          cond do
            MapSet.member?(posset, {currrow, currcol}) -> "+"
            MapSet.member?(negset, {currrow, currcol}) -> "-"
            true -> "X"
          end
        end |> Enum.join("")
      end
      {:ok, List.to_tuple(solvedrows)}
    else
      :no_solution
    end
  else
    {{r1, c1}, {r2, c2}} = Enum.at(region, index)
    emptyres = solve_regions(region,
                              index + 1, posset,
                              negset, posrowcount,
                              negrowcount, poscolcount,
                              negcolcount, leftreqs,
                              rightreqs, topreqs,
                              bottomreqs, rowtoregions,
                              coltoregions)

    if emptyres != :no_solution do
      emptyres
    else
      cond1 = valid_pole_pos?(r1, c1, "+", posset, negset) and
              valid_pole_pos?(r2, c2, "-", posset, negset)
      resorient1 =
        if cond1 do
          newposset = MapSet.put(posset, {r1, c1})
          newnegset = MapSet.put(negset, {r2, c2})
          newposrow = List.update_at(posrowcount, r1, &(&1 + 1))
          newnegrow = List.update_at(negrowcount, r2, &(&1 + 1))
          newposcol = List.update_at(poscolcount, c1, &(&1 + 1))
          newnegcol = List.update_at(negcolcount, c2, &(&1 + 1))
          if requirements_met?([r1, r2],
                            [c1, c2], newposrow,
                            newnegrow, newposcol,
                            newnegcol, leftreqs,
                            rightreqs, topreqs,
                            bottomreqs, rowtoregions,
                            coltoregions, index) do
            solve_regions(region,
                          index + 1, newposset,
                          newnegset, newposrow,
                          newnegrow, newposcol,
                          newnegcol, leftreqs,
                          rightreqs, topreqs,
                          bottomreqs, rowtoregions,
                          coltoregions)
          else
            :no_solution
          end
        else
          :no_solution
        end

      if resorient1 != :no_solution do
        resorient1
      else
        cond2 = valid_pole_pos?(r1, c1, "-", posset, negset) and
                valid_pole_pos?(r2, c2, "+", posset, negset)
        if cond2 do
          newposset = MapSet.put(posset, {r2, c2})
          newnegset = MapSet.put(negset, {r1, c1})
          newposrow = List.update_at(posrowcount, r2, &(&1 + 1))
          newnegrow = List.update_at(negrowcount, r1, &(&1 + 1))
          newposcol = List.update_at(poscolcount, c2, &(&1 + 1))
          newnegcol = List.update_at(negcolcount, c1, &(&1 + 1))
          if requirements_met?([r1, r2],
                            [c1, c2], newposrow,
                            newnegrow, newposcol,
                            newnegcol, leftreqs,
                            rightreqs, topreqs,
                            bottomreqs, rowtoregions,
                            coltoregions, index) do
            solve_regions(region,
                          index + 1, newposset,
                          newnegset, newposrow,
                          newnegrow, newposcol,
                          newnegcol, leftreqs,
                          rightreqs, topreqs,
                          bottomreqs, rowtoregions,
                          coltoregions)
          else
            :no_solution
          end
        else
          :no_solution
        end
      end
    end
  end
end

  defp valid_pole_pos?(currrow, currcol, pole, posset, negset) do
  if MapSet.member?(posset, {currrow, currcol}) or MapSet.member?(negset, {currrow, currcol}) do
    false
  else
    case pole do
      "+" ->
        Enum.all?([{currrow - 1, currcol}, {currrow + 1, currcol}, {currrow, currcol - 1}, {currrow, currcol + 1}],
          &(!MapSet.member?(posset, &1))
        )

      "-" ->
        Enum.all?([{currrow - 1, currcol}, {currrow + 1, currcol}, {currrow, currcol - 1}, {currrow, currcol + 1}],
          &(!MapSet.member?(negset, &1))
        )
    end
  end
  end

defp requirements_met?(affectedrows,
                    affectedcols, posrowcount,
                    negrowcount, poscolcount,
                    negcolcount, leftreqs,
                    rightreqs, topreqs,
                    bottomreqs, rowtoregions,
                    coltoregions, current_index) do
  Enum.all?(affectedrows, fn currrow ->
    ((Enum.at(leftreqs, currrow) in [-1, Enum.at(posrowcount, currrow)]) or
      (Enum.at(posrowcount, currrow) <= Enum.at(leftreqs, currrow))) and
    ((Enum.at(rightreqs, currrow) in [-1, Enum.at(negrowcount, currrow)]) or
      (Enum.at(negrowcount, currrow) <= Enum.at(rightreqs, currrow)))
  end) and
  Enum.all?(affectedrows, fn currrow ->
    ((Enum.at(leftreqs, currrow) == -1) or
      ((Enum.at(leftreqs, currrow) - Enum.at(posrowcount, currrow)) <=
        Enum.count(Enum.at(rowtoregions, currrow), &(&1 > current_index)))) and
    ((Enum.at(rightreqs, currrow) == -1) or
      ((Enum.at(rightreqs, currrow) - Enum.at(negrowcount, currrow)) <=
        Enum.count(Enum.at(rowtoregions, currrow), &(&1 > current_index))))
  end) and
  Enum.all?(affectedcols, fn currcol ->
    ((Enum.at(topreqs, currcol) in [-1, Enum.at(poscolcount, currcol)]) or
      (Enum.at(poscolcount, currcol) <= Enum.at(topreqs, currcol))) and
    ((Enum.at(bottomreqs, currcol) in [-1, Enum.at(negcolcount, currcol)]) or
      (Enum.at(negcolcount, currcol) <= Enum.at(bottomreqs, currcol)))
  end) and
  Enum.all?(affectedcols, fn currcol ->
    ((Enum.at(topreqs, currcol) == -1) or
      ((Enum.at(topreqs, currcol) - Enum.at(poscolcount, currcol)) <=
        Enum.count(Enum.at(coltoregions, currcol), &(&1 > current_index)))) and
    ((Enum.at(bottomreqs, currcol) == -1) or
      ((Enum.at(bottomreqs, currcol) - Enum.at(negcolcount, currcol)) <=
        Enum.count(Enum.at(coltoregions, currcol), &(&1 > current_index))))
  end)
end

  defp valid_solution?(posrowcount,
                      negrowcount, poscolcount,
                      negcolcount, leftreqs,
                      rightreqs, topreqs,
                      bottomreqs) do
  Enum.with_index(posrowcount)
  |> Enum.all?(fn {pluscount, currrow} ->
    minuscount = Enum.at(negrowcount, currrow)
    (Enum.at(leftreqs, currrow) in [-1, pluscount]) and
      (Enum.at(rightreqs, currrow) in [-1, minuscount])
  end) and
  Enum.with_index(poscolcount)
  |> Enum.all?(fn {pluscount, currcol} ->
    minuscount = Enum.at(negcolcount, currcol)
    (Enum.at(topreqs, currcol) in [-1, pluscount]) and
      (Enum.at(bottomreqs, currcol) in [-1, minuscount])
  end)
  end
end
