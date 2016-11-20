require_relative '../lib/heroku_ssl/engine'

HerokuSSL::Engine.routes.draw do

  get '.well-known/acme-challenge/:challenge' => 'heroku_ssl#challenge'

end