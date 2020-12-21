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

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: PlumaApiWeb.Telemetry
    end
  end
end
