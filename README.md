# Heroku SSL
With the advent of free SSL from [Let's Encrypt](https://letsencrypt.org/), SSL should be as easy as clicking a button. 

## Usage on Heroku
Add this gem to your gemfile, then deploy it to heroku. 
Then, you can simply run `rake ssl:update_heroku_certs`

## Usage outside of Heroku
Although designed for Heroku, it can generate certificates on other providers. 
To do so, on your server, run `rake ssl:generate_certs`.
This will print a public and a private key to the console, which you can do with what you will.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'heroku-ssl'
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
