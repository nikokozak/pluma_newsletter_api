defmodule PlumaApi.Factory do
  alias PlumaApi.MailchimpRepo
  @main_list Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list)

  def subscriber do
    %{
      email: MailchimpRepo.generate_testing_email(),
      list: @main_list,
      mchimp_id: Nanoid.generate(),
      rid: Nanoid.generate(),
      parent_rid: "" 
    }
  end

end
