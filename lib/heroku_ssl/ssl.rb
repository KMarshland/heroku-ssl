require 'openssl'
require 'acme-client'

module HerokuSSL

  class << self
    def endpoint
      # Use 'https://acme-staging.api.letsencrypt.org/' for development

      'https://acme-v01.api.letsencrypt.org/'
    end

    #forcibly regenerates the account private key
    def regenerate_private_key
      @private_key = OpenSSL::PKey::RSA.new(4096)
      write_to_s3("#{Rails.env}/account.pem", @private_key.export)

      @private_key
    end

    #returns any existing account private key; only generates a new one if none exist
    def private_key
      return @private_key if @private_key.present?

      pem = read_from_s3 "#{Rails.env}/account.pem"
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
    def register(email='kai@leolabs.space')
      # If the private key is not known to the server, we need to register it for the first time.
      registration = client.register(contact: "mailto:#{email}")

      # You may need to agree to the terms of service (that's up the to the server to require it or not but boulder does by default)
      registration.agree_terms
    rescue Acme::Client::Error::Malformed => e
      if e.message == "Registration key is already in use"
        puts 'Already registered'
      else
        raise e
      end
    end

    def authorize(domain)
      authorization = client.authorize(domain: domain)

      return if authorization.status == 'valid'

      # This example is using the http-01 challenge type. Other challenges are dns-01 or tls-sni-01.
      challenge = authorization.http01

      # Save the file. We'll create a public directory to serve it from, and inside it we'll create the challenge file.
      FileUtils.mkdir_p( Rails.root.join( 'public', File.dirname( challenge.filename ) ) )

      # We'll write the content of the file
      File.write( Rails.root.join( 'public', challenge.filename), challenge.file_content )

      challenge.request_verification

      # Wait a bit for the server to make the request, or just blink. It should be fast.
      sleep(1)

      status = client.authorize(domain: domain).status
      unless status == 'valid'
        puts challenge.error
        raise "Did not verify client. Status is still #{status}"
      end
    end

    def rename_old_certificates
      %w[privkey cert chain fullchain].each do |name|
        existing = read_from_s3 "#{Rails.env}/#{name}.pem"
        write_to_s3("#{Rails.env}/#{name}_old.pem", existing) if existing.present?
      end
    end

    def request_certificate(domain='api.leolabs.space')
      authorize domain

      csr = Acme::Client::CertificateRequest.new(names: [domain])

      # We can now request a certificate. You can pass anything that returns
      # a valid DER encoded CSR when calling to_der on it. For example an
      # OpenSSL::X509::Request should work too.
      certificate = client.new_certificate(csr)

      rename_old_certificates

      write_to_s3("#{Rails.env}/privkey.pem", certificate.request.private_key.to_pem)
      write_to_s3("#{Rails.env}/cert.pem", certificate.to_pem)
      write_to_s3("#{Rails.env}/chain.pem", certificate.chain_to_pem)
      write_to_s3("#{Rails.env}/fullchain.pem", certificate.fullchain_to_pem)
    end

    def get_certificates
      [:privkey, :fullchain].each do |cert|
        pem = read_from_s3 "#{Rails.env}/#{cert}.pem"
        if pem.present?
          File.write(Rails.root.join('certs', "#{cert}.pem"), pem)
        else
          request_certificate
        end
      end

      #Generate fresh DH params
      gen_if_not_exist 'dhparam.pem', lambda {|path|
        "openssl dhparam -out #{path} 4096"
      }

    end

    def create_dh_params

    end

  end

end
