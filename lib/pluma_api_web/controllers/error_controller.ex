defmodule PlumaApiWeb.ErrorController do
  use PlumaApiWeb, :controller

  def not_found(conn, _) do
    conn
    |> put_status(404)
    |> json(%{ error: "Not Found"})
  end
  
end
