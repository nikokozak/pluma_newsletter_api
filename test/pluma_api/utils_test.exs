defmodule PlumaApi.UtilsTest do
  use ExUnit.Case

  test "nanoid generates a 9 char length ID" do
    assert String.length(Nanoid.generate()) == 9
  end
  
end
