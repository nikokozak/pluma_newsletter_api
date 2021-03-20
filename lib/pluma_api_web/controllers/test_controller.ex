defmodule PlumaApiWeb.TestController do
  use PlumaApiWeb, :controller

  @moduledoc """
  Provides convenient functions for testing our application is up and running.
  """

  def test_get(conn, _) do
    conn
    |> put_status(200)
    |> json("OK!")
  end

  def test_post(conn, params) do
    conn
    |> put_status(200)
    |> json(params)
  end
  
end
