defmodule PlumaApi.Factory do
  @main_list Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list)

  def subscriber do
    %{
      email: Faker.Internet.email,
      list: @main_list,
      mchimp_id: Nanoid.generate(),
      rid: Nanoid.generate(),
      parent_rid: "" 
    }
  end

end
