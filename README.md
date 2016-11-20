# Heroku SSL
With the advent of free SSL from [Let's Encrypt](https://letsencrypt.org/), SSL should be as easy as clicking a button. 

## Usage on Heroku
Add this gem to your gemfile, then deploy it to heroku. 
Then, you can simply run `rake ssl:update_heroku_certs`

This should prompt you for everything you need to update your shiny new SSL certificate! 
The only thing left to do will be to [configure your DNS correctly](https://devcenter.heroku.com/articles/ssl-endpoint#dns-and-domain-configuration). 
You'll also want to make sure that the domain had been added to heroku with `heroku domains:add [your domain]`

## Usage outside of Heroku
Although designed for Heroku, it can generate certificates on other providers. 
To do so, on your server, run `rake ssl:generate_certs`.
This will print a JSON encoded set of PEM keys to the console.
You can download these (you will likely want to use `privkey` and `fullchain` as your public and private keys respectively) 
and add them to your own servers and configure the DNS yourself.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'heroku-ssl'
```

Or, to test the bleeding edge version:
```ruby
gem 'heroku_ssl', git: 'https://github.com/KMarshland/heroku-ssl.git'
```

And then execute:
```bash
$ bundle install
```

It also requires one of the following:
- The global variable `$redis` is set
- The environment variable `REDIS_URL` is set
- The environment variable `HEROKU_REDIS_URL` is set

## Contributing
Submit a pull request!

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
