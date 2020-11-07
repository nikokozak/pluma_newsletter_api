defmodule PlumaApiWeb.ErrorController do
  use PlumaApiWeb, :controller

  def not_found(conn, _) do
    send(conn, "Not Found")
  end
  
end
