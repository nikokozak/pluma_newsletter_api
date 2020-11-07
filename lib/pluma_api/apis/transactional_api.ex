defmodule PlumaApi.TransactionalAPI do
  @api_key Keyword.get(Application.get_env(:pluma_api, :mailchimp), :transactional_api_key)
  @base_url "https://mandrillapp.com/api/1.0/"

  @hackney_auth [basic_auth: {"plumachile", @api_key}]

  def check_health() do
    HTTPoison.post(
      @base_url <> "users/ping",
      make_key(),
      [],
      [hackney: @hackney_auth]
    ) 
  end

  def send_welcome_email(to) do
    content = %{
      key: @api_key,
      template_name: "welcome",
      template_content: [],
      message: %{
        to: [
          %{email: to}
        ]
      }
    }

    send_template(content)
  end

  def send_unsubscribe_email(to) do
    content = %{
      key: @api_key,
      template_name: "unsubscribe",
      template_content: [],
      message: %{
        to: [
          %{email: to}
        ]
      }
    }

    send_template(content)
  end

  def make_message(from, to, subject, body) do
    %{
      from_email: from,
      subject: subject,
      text: body,
      to: [
        %{
          email: to,
          type: "to"
        }
      ]
    }
  end 

  def send_email(message) do
    email = %{
      key: @api_key,
      message: message
    }

    HTTPoison.post(
      @base_url <> "messages/send",
      Jason.encode(email) |> elem(1),
      [],
      []
    )
  end

  def send_template(content) do
    HTTPoison.post(
      @base_url <> "messages/send-template",
      Jason.encode(content) |> elem(1),
      [],
      []
    )
  end

  defp make_key, do: Jason.encode(%{key: @api_key}) |> elem(1)
end
