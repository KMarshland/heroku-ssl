Rails.application.routes.draw do

  get '.well-known/acme-challenge/:challenge' => 'HerokuSSL#challenge'

end