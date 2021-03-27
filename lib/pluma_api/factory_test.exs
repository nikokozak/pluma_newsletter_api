defmodule PlumaApi.FactoryTest do
  use ExUnit.Case
  alias PlumaApi.Factory, as: Factory
  alias PlumaApi.Subscriber

  @moduletag :factory_tests

  describe "Factory.subscriber/1" do

    test "Generates valid Subscriber parameters" do

      sub_params = Factory.subscriber
      chgst = Subscriber.changeset(%Subscriber{}, sub_params)

      assert chgst.valid?
    end

    test "Accepts custom options for parameter generation" do

      options = [
        email: "nikokozak@gmail.com",
        list: "342111324",
        rid: "33acustomRID22",
        fname: "Nikolai",
        lname: "Kozak",
        status: "pending",
        tags: ["Cookoo", "ATest"]
      ]
      sub_params = Factory.subscriber(options)
      chgst = Subscriber.changeset(%Subscriber{}, sub_params)

      assert chgst.valid?
    end

  end
  
end
