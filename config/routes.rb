Rails.application.routes.draw do

  get '.well-known/acme-challenge/:challenge' => 'heroku_ssl/heroku_ssl#challenge'

end