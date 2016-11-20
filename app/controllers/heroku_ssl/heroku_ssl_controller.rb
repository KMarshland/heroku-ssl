require_dependency "heroku_ssl/application_controller"

module HerokuSsl
  class HerokuSslController < ApplicationController

    def challenge
      response = HerokuSSL::redis_instance.get("ssl-challenge-#{params[:challenge]}")
      render text: response
    end

  end
end
