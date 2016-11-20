module HerokuSSL
  class HerokuSslController < Rails::Application::ActionController::Base

    def challenge
      response = HerokuSSL::redis_instance.get("ssl-challenge-#{params[:challenge]}")
      render text: response
    end

  end
end