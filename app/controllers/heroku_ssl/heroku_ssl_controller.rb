require_dependency "heroku_ssl/application_controller"

module HerokuSsl
  class HerokuSslController < ApplicationController

    def challenge
      response = HerokuSsl::redis_instance.get("ssl-challenge-#{params[:challenge]}")
      render plain: response
    end

  end
end
