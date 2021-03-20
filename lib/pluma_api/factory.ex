defmodule PlumaApi.Factory do
  @main_list Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list)

  def subscriber(list_id \\ @main_list) do
    %{
      email: Faker.Internet.email,
      list: list_id, 
      mchimp_id: Nanoid.generate(),
      rid: Nanoid.generate(),
      parent_rid: "" 
    }
  end

end
