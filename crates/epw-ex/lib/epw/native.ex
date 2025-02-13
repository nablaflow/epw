defmodule Epw.Native do
  @moduledoc false

  use Rustler, otp_app: :epw, crate: :epw_ex

  def parse(_binary, _args), do: :erlang.nif_error(:nif_not_loaded)
end
