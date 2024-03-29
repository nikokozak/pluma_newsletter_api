defmodule PlumaApi.SubscriberTest do
  use PlumaApi.DataCase
  alias PlumaApi.Factory
  alias PlumaApi.Subscriber

  @moduletag :subscriber_tests

  setup do
    
    {:ok, sub_1} = %Subscriber{}
                   |> Subscriber.changeset(Factory.subscriber)
                   |> Repo.insert

    {:ok, sub_2} = %Subscriber{}
                   |> Subscriber.changeset(Factory.subscriber(parent_rid: sub_1.rid))
                   |> Repo.insert

    {:ok, sub_3} = %Subscriber{}
                   |> Subscriber.changeset(Factory.subscriber(parent_rid: sub_1.rid))
                   |> Repo.insert

    {:ok, sub_1: sub_1, sub_2: sub_2, sub_3: sub_3}
  end

  test "changeset/2" do
    changeset = 
      %Subscriber{}
      |> Subscriber.changeset(Factory.subscriber)

    assert changeset.valid?
  end

  test "persist" do
    subscriber = %Subscriber{}
                 |> Subscriber.changeset(Factory.subscriber())
    
    {:ok, _inserted} = Repo.insert(subscriber)
  end

  test "delete", %{sub_3: sub_3} do
    {:ok, _deleted} = Repo.delete(sub_3)
  end

  test "with_id/2", %{sub_1: sub_1} do
    sub = Subscriber.with_id(sub_1.id) |> Repo.one
    assert sub.id == sub_1.id
  end

  test "with_email/2", %{sub_1: sub_1} do
    sub = Subscriber.with_email(sub_1.email) |> Repo.one
    assert sub.email == sub_1.email
  end

  test "referees", %{sub_1: sub_1} do
    sub_1 = Repo.preload(sub_1, :referees)

    assert length(sub_1.referees) == 2
  end

  test "generates new rid on blank string" do
    {:ok, sub} = Subscriber.changeset(%Subscriber{}, Factory.subscriber(rid: ""))
                   |> Ecto.Changeset.apply_action(:insert)

    assert not String.equivalent?("", sub.rid)
  end

end
