require 'openssl'
require 'acme-client'

module HerokuSSL

  class << self
    def endpoint
      # Use 'https://acme-staging.api.letsencrypt.org/' for development

      'https://acme-v01.api.letsencrypt.org/'
    end

    def redis_instance

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

      challenge.request_verification

      # Wait a bit for the server to make the request, or just blink. It should be fast.
      sleep(1)

      status = client.authorize(domain: domain).status
      unless status == 'valid'
        puts challenge.error
        raise "Did not verify client. Status is still #{status}"
      end
    end

    def request_certificate(domain)
      authorize domain

      csr = Acme::Client::CertificateRequest.new(names: [domain])

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
