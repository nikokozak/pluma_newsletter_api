defmodule PlumaApi.MailosaurAPI do
  @api_key Keyword.get(Application.get_env(:pluma_api, :mailchimp), :mailosaur_api_key)
  @mailosaur_server Keyword.get(Application.get_env(:pluma_api, :mailchimp), :mailosaur_server)
  @base_url "https://mailosaur.com/api/"

  @hackney_auth [basic_auth: {@api_key, ""}]

  def check_health() do

  end

  @doc """
  As per the mailosaur api - %{sentFrom: xxx, sentTo: xxx, subject: xxx, body: xxx, match: ALL/ANY}
  """
  def find_message(params) do
    HTTPoison.post(
      @base_url <> "messages/search?server=" <> @mailosaur_server,
      Jason.encode(params) |> elem(1),
      [{"Content-Type", "application/json"}],
      [hackney: @hackney_auth]
    )
  end
  
end
