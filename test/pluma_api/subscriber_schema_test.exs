defmodule PlumaApi.SubscriberTest do
  use PlumaApi.DataCase
  alias PlumaApi.Factory
  alias PlumaApi.Subscriber

  setup do
    
    {:ok, sub_1} = %Subscriber{}
                   |> Subscriber.insert_changeset(Factory.subscriber)
                   |> Repo.insert

    {:ok, sub_2} = %Subscriber{}
                   |> Subscriber.insert_changeset(%{ Factory.subscriber | parent_rid: sub_1.rid})
                   |> Repo.insert

    {:ok, sub_3} = %Subscriber{}
                   |> Subscriber.insert_changeset(%{ Factory.subscriber | parent_rid: sub_1.rid })
                   |> Repo.insert

    {:ok, sub_1: sub_1, sub_2: sub_2, sub_3: sub_3}
  end

  test "insert_changeset/2" do
    changeset = 
      %Subscriber{}
      |> Subscriber.insert_changeset(Factory.subscriber)

    assert changeset.valid?
  end

  test "persist" do
    subscriber = %Subscriber{}
                 |> Subscriber.insert_changeset(Factory.subscriber())
    
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



end
