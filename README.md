# Heroku SSL
With the advent of free SSL from [Let's Encrypt](https://letsencrypt.org/), SSL should be as easy as clicking a button.
This gem allows you to generate and add an SSL certificate simply by running a rake task. 

## Usage on Heroku
Add this gem to your gemfile, then deploy it to heroku. 
Then, you can simply run `rake heroku_ssl:update_certs`

This should prompt you for everything you need to update your shiny new SSL certificate! 
The only thing left to do will be to [configure your DNS correctly](https://devcenter.heroku.com/articles/ssl-endpoint#dns-and-domain-configuration). 
You'll also want to make sure that the domain had been added to heroku with `heroku domains:add [your domain]`

## Usage outside of Heroku
Although designed for Heroku, it can generate certificates on other providers. 
To do so, on your server, run `rake heroku_ssl:generate_certs`.
This will print a JSON encoded set of PEM keys to the console.
You can download these (you will likely want to use `privkey` and `fullchain` as your public and private keys respectively) 
and add them to your own servers and configure the DNS yourself.

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'heroku_ssl'
```

And then execute:
```bash
$ bundle install
```

It also requires one of the following:
- The global variable `$redis` is set
- The environment variable `REDIS_URL` is set
- The environment variable `HEROKU_REDIS_URL` is set

Note that this means you need to have a live version of redis; on Heroku the free tier will work: https://elements.heroku.com/addons/heroku-redis.

## Contributing
Submit a pull request!

## FAQ

### Why do I need redis?
To issue an SSL Certificate, Let's Encrypt needs to verify that you actually own the domain you say you do. 
It performs this verification by issuing a secret key to put at a given url on the server 
(eg make it render `foo` when a GET request is made to `/.well-known/acme-challenge/fop`). 
However, since most hosts, including Heroku, allow multiple servers running the same app, we can't just write a file,
which would only affect one instance (in fact, if it were done through a rake task on heroku, 
it would be completely sandboxed from the running dyno); 
instead, we need to make sure all running servers know what the key is. 
We handle this synchronization through redis

You can get rid of redis (in fact, you could even get rid of this entire gem) once your SSL certificate has been issued.
Of course, you'll have to reinstall the gem when the certificate expires. 

### How do I configure my DNS?
You need to set a CNAME record in your DNS zone file that points to `[yourdomain].herokudns.com`. 
The DNS zone file specifies what urls get mapped to what servers on the domain name you own. 
If your site is already pointed to your Heroku app, there will already be a CNAME record; 
you just need to change where it points to. 
If not, you'll need to add a new line:
```
[subdomain] [TTL] IN CNAME [yourdomain].herokudns.com.
```

For example, I have
```
www 10800 IN CNAME www.kaimarshland.com.herokudns.com.
```
Which points the `www` subdomain (ie the www in [www.kaimarshland.com](https://www.kaimarshland.com)) to 
www.kaimarshland.com.herokudns.com. 
The TTL, or Time To Live, is set to 10800 seconds, which determines how long DNS information will be cached for.

### How can I add a certificate generated with this manually?
After running `rake heroku_ssl:generate_certs` on your server, which will print out a JSON object with your generated 
certificates in it, you'll need to take the fullchain and the privkey and add them to your HTTP server. 

On nginx, this looks like creating a new server block something like:

```
server {
    ...

    listen 443 ssl;

    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;

    ...
}
```

On apache, this looks something like like:
```
<VirtualHost 192.168.0.1:443>
...

SSLEngine on
SSLCertificateFile /path/to/fullchain.pem
SSLCertificateKeyFile /path/to/privkey.pem
SSLCertificateChainFile /path/to/chain.pem

...
</VirtualHost>
```

### What's the deal with certificate expiration?
Certificates expire after 90 days -- you can read about why on 
[Let's Encrypt](https://letsencrypt.org/2015/11/09/why-90-days.html).
You'll get an email as the expiration date approaches, at which point you'll have to rerun `rake heroku_ssl:generate_certs`.
We're looking into ways to renew the certificates automatically; however, at the moment the Heroku API doesn't let us.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
