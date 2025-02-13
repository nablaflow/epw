defmodule EpwTest do
  use ExUnit.Case

  test "parse/2" do
    assert Epw.parse("") == {:ok, %Epw{ts: [], wind_speed: [], wind_dir: []}}

    assert Epw.parse(gen_lines(1)) ==
             {:ok, %Epw{ts: [~N[2014-01-02 02:04:00]], wind_speed: [21.0], wind_dir: [20.0]}}

    assert Epw.parse(gen_lines(0) <> "a") ==
             {:error, {:cannot_parse_col, "Cannot parse column `Year` at line no. 9"}}

    assert Epw.parse(gen_lines(0) <> "1,2,3,4,5,6") ==
             {:error, {:missing_col, "Missing column `Wind direction` at line no. 9"}}

    for n <- 2..10 do
      assert Epw.parse(gen_lines(n), max_lines: 1) ==
               {:error, {:max_lines_reached, "Max amount of lines (1) reached"}}
    end
  end

  defp gen_lines(n) do
    "\n\n\n\n\n\n\n\n" <>
      (Stream.repeatedly(fn ->
         "2014,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26"
       end)
       |> Stream.take(n)
       |> Enum.join("\n"))
  end
end
