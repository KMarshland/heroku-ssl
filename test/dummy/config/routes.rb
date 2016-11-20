Rails.application.routes.draw do
  mount HerokuSsl::Engine => "/heroku_ssl"
end
