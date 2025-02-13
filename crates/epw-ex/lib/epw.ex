defmodule Epw do
  @moduledoc false

  @default_args %{
    max_lines: 10_000
  }

  defstruct [:ts, :wind_speed, :wind_dir]

  def parse(binary, args \\ []) when is_binary(binary) and is_list(args) do
    args = Map.merge(@default_args, Map.new(args))

    with {:ok, m} <- Epw.Native.parse(binary, Map.new(args)) do
      m = Map.update(m, :ts, [], &tss_to_naive_dts/1)

      {:ok, struct!(%__MODULE__{}, m)}
    end
  end

  defp tss_to_naive_dts(l), do: Enum.map(l, &NaiveDateTime.from_erl!/1)
end
