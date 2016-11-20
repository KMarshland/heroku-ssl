module HerokuSSL
  class HerokuSSLController < ApplicationController

    def challenge
      response = HerokuSSL::redis_instance.get("ssl-challenge-#{params[:challenge]}")
      render text: response
    end

  end
end