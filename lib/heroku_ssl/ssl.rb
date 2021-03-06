require 'openssl'
require 'acme-client'
require 'redis'

module HerokuSsl

  class << self
    def endpoint
      # Use 'https://acme-staging.api.letsencrypt.org/' for development

      'https://acme-v01.api.letsencrypt.org/'
    end

    def redis_instance

      return $redis if $redis.present?
      return $heroku_ssl_redis if $heroku_ssl_redis.present?

      redis_url = ENV['REDIS_URL'] || ENV['HEROKU_REDIS_URL'] || 'redis://127.0.0.1:6379/0'
      $heroku_ssl_redis = Redis.new(:url => redis_url)

    end

    # Where the certificates are stored
    def cert_directory
      Rails.root.join('certs')
    end

    def write(filename, content)
      FileUtils.mkdir_p cert_directory

      File.write(cert_directory.join(filename), content)
    end

    def read(filename)
      FileUtils.mkdir_p cert_directory

      return nil unless File.exists? cert_directory.join(filename)

      File.read cert_directory.join(filename)
    end

    def gen_unless_exists(filename)
      existing = read filename
      return existing if existing.present?

      created = yield filename
      write filename, created

      created
    end

    #forcibly regenerates the account private key
    def regenerate_private_key
      @private_key = OpenSSL::PKey::RSA.new(4096)
      write('account.pem', @private_key.export)

      @private_key
    end

    #returns any existing account private key; only generates a new one if none exist
    def private_key
      return @private_key if @private_key.present?

      pem = read "#{Rails.env}/account.pem"
      if pem.present?
        @private_key = OpenSSL::PKey::RSA.new(pem)
      else
        regenerate_private_key
      end
    end


    def client
      @client ||= Acme::Client.new(
          private_key: private_key,
          endpoint: endpoint,
          connection_options: {
              request: {
                  open_timeout: 5,
                  timeout: 5
              }
          }
      )
    end

    #adds a contact for a domain
    def register(email)
      # If the private key is not known to the server, we need to register it for the first time.
      registration = client.register(contact: "mailto:#{email}")

      # You may need to agree to the terms of service (that's up the to the server to require it or not but boulder does by default)
      registration.agree_terms
    rescue Acme::Client::Error::Malformed => e
      if e.message == 'Registration key is already in use'
        puts 'Already registered'
      else
        raise e
      end
    end

    def authorize(domain)
      if domain.is_a? Array
        domain.each do |dom|
          authorize dom
        end

        return
      end

      authorization = client.authorize(domain: domain)

      return if authorization.status == 'valid'

      # This example is using the http-01 challenge type. Other challenges are dns-01 or tls-sni-01.
      challenge = authorization.http01

      redis_instance.set("ssl-challenge-#{challenge.filename.split('/').last}", challenge.file_content)
      redis_instance.expire("ssl-challenge-#{challenge.filename.split('/').last}", 5.minutes)

      challenge.request_verification

      # Wait a bit for the server to make the request, or just blink. It should be fast.
      sleep(1)

      status = nil
      begin
        # May sometimes give an error, for mysterious reasons
        status = challenge.authorization.verify_status
      rescue
      end

      #alternate method to read authorization status
      status = client.authorize(domain: domain).status if status == 'pending' || status.blank?

      unless status == 'valid'
        puts challenge.error
        raise "Did not verify client. Status is still #{status}"
      end
    end

    def try_authorize(domain, retries=1)
      begin
        authorize domain
        return true
      rescue RuntimeError => e
        puts e.message

        if retries > 0
          puts 'Retrying domain authorization...'
          return try_authorize domain, retries-1
        else
          return false
        end
      end
    end

    def request_certificate(domain)
      unless try_authorize domain
        puts 'Domain authorization failed. Aborting operation'
        return
      end

      csr = Acme::Client::CertificateRequest.new(names: [*domain])

      # We can now request a certificate. You can pass anything that returns
      # a valid DER encoded CSR when calling to_der on it. For example an
      # OpenSSL::X509::Request should work too.
      certificate = client.new_certificate(csr)

      {
          privkey: certificate.request.private_key.to_pem,
          cert: certificate.to_pem,
          chain: certificate.chain_to_pem,
          fullchain: certificate.fullchain_to_pem
      }

    end

    def create_dh_params
      gen_unless_exists 'dhparam.pem' do |filename|
        `openssl dhparam -out #{filename} 4096`
      end
    end

  end

end
