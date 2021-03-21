defmodule PlumaApiWeb.Router do
  use PlumaApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", PlumaApiWeb do
    pipe_through :api

    # Mailchimp webhook endpoints
    get "/mchimp_webhook", MailchimpWebhookController, :test_get
    # This endpoint handles subscribe/unsubscribe events
    post "/mchimp_webhook", MailchimpWebhookController, :handle_event

    post "/mchimp_webhook_v2", MailchimpWebhookController, :handle

    # params are passed via the url -> ?email= | ?rid= 
    # normally, this endpoint is hit by our website dashboard,
    # and is used to get info on a given subscriber (referees)
    get "/subscriber", SubscriberController, :get_subscriber

    # handle form submission from website
    post "/subscriber", SubscriberController, :new_subscriber

    # test routes to check whether application is responding
    get "/test_me", TestController, :test_get
    post "/test_me", TestController, :test_post
  end

  # Catch-all error replies
  scope "/", PlumaApiWeb do

    get "/", ErrorController, :not_found
    get "/:any", ErrorController, :not_found
  end

end
