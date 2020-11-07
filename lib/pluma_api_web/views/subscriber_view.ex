defmodule PlumaApiWeb.SubscriberView do
  use PlumaApiWeb, :view

  def render("details.json", %{subscriber: sub}) do
    %{
      id: sub.id,
      email: sub.email,
      rid: sub.rid,
      parent_rid: sub.parent_rid,
      referees: sub.referees
    }
  end

  def render("subscribed.json", %{subscriber: sub}) do
    %{
      id: sub.id,
      email: sub.email,
      rid: sub.rid
    }
  end

  def render("deleted.json", %{subscriber: sub}) do
    %{
      id: sub.id,
      email: sub.email
    }
  end

  def render("confirmed.json", %{subscriber: sub}) do
    %{
      id: sub.id,
      email: sub.email,
      rid: sub.rid
    }
  end
  
end
