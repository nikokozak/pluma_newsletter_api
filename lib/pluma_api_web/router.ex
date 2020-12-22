defmodule PlumaApiWeb.Router do
  use PlumaApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", PlumaApiWeb do
    pipe_through :api

    # Mailchimp webhook endpoints
    get "/mchimp_webhook", MailchimpController, :test_get
    post "/mchimp_webhook", MailchimpController, :handle_event

    # test routes to check whether application is responding
    get "/test_me", TestController, :test_get
    post "/test_me", TestController, :test_post

    # params are passed via the url -> ?email=nikokozak@gmail.com
    # normally, this endpoint is hit by our website dashboard
    get "/subscriber", SubscriberController, :subscriber_details

  end

end
