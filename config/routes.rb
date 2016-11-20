HerokuSsl::Engine.routes.draw do

  get '.well-known/acme-challenge/:challenge' => 'heroku_ssl#challenge'

end
