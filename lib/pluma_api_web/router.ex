defmodule PlumaApiWeb.Router do
  use PlumaApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :form do
    plug :accepts, ["json"]
  end

  scope "/api", PlumaApiWeb do
    pipe_through :api

    # Mailchimp webhook endpoints
    get "/mchimp_webhook", MailchimpController, :test_get
    # This endpoint handles subscribe/unsubscribe events
    post "/mchimp_webhook", MailchimpController, :handle_event

    # params are passed via the url -> ?email= | ?rid= 
    # normally, this endpoint is hit by our website dashboard,
    # and is used to get info on a given subscriber (referees)
    get "/subscriber", SubscriberController, :subscriber_details

    # test routes to check whether application is responding
    get "/test_me", TestController, :test_get
    post "/test_me", TestController, :test_post
  end

  scope "/form", PlumaApiWeb do
    pipe_through :form

    get "/test_me", TestController, :test_get
  end

  scope "/", PlumaApiWeb do
    pipe_through :api
    get "/", ErrorController, :not_found
    get "/:any", ErrorController, :not_found
  end

end
