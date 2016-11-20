
namespace :heroku_ssl do

  task :update_certs do
    STDOUT.puts 'Once your app has been deployed to Heroku, hit enter.'

    STDIN.gets

    email = get_email
    domains = get_domains.join(' ')
    app = get_app

    puts "Attempting to generate ssl certificates for #{app} (registering #{domains} to #{email})"

    #generate the certs on the server
    output = `unset RUBYOPT; heroku run rake ssl:generate_certs #{email} #{domains} --app #{app}`

    #read out the certs to temporary files
    if output.include? '~~ GENERATED CERTIFICATES START ~~'
      puts 'Successfully generated certificates! Attempting to update Heroku DNS'

      output = output.split('~~ GENERATED CERTIFICATES START ~~').last
                   .split('~~ GENERATED CERTIFICATES END ~~').first
      output = JSON(output)

      File.open('fullchain.pem', 'wb') do |file|
        file.write output['fullchain']
      end

      File.open('privkey.pem', 'wb') do |file|
        file.write output['privkey']
      end

      # update heroku certs
      # RUBYOPT breaks the heroku command for some reason, so you have to unset it
      `unset RUBYOPT; heroku certs:update fullchain.pem privkey.pem --app #{get_app} --confirm #{get_app}`

      # clean up
      File.delete('fullchain.pem', 'privkey.pem')
    else
      puts 'Could not generate certificates. Please try again later or try running `heroku run rake ssk:generate_certs` directly'
    end

  end

  task :generate_certs do
    email = (ARGV[1] || '').strip
    email = get_email if email.blank?

    puts "Registering #{email}"
    HerokuSsl::register email

    domain = ARGV[2..-1]
    domain = get_domains if domain.blank?

    puts "Authorizing and generating certificates for #{domain}"

    certs = HerokuSsl::request_certificate domain

    if certs.present?
      STDOUT.puts '~~ GENERATED CERTIFICATES START ~~'
      STDOUT.puts JSON(certs)
      STDOUT.puts '~~ GENERATED CERTIFICATES END ~~'
    end
  end

  def get_email
    email = nil
    while email.blank? do
      STDOUT.puts 'Enter your email address: '
      email = STDIN.gets
      email.strip! if email.present?
    end
    email
  end

  def get_domains
    STDOUT.puts 'Enter the domain to register: '
    STDIN.gets.strip.split ' '
  end

  def get_app
    return @app if @app.present?

    @apps = @apps || `unset RUBYOPT; heroku apps`.split("\n")
    remotes = `git remote -v`.split("\n").map do |r|
      r.split("\t").last
    end

    @apps.each do |app|
      remotes.each do |remote|
        if remote.include? app
          @app = app
          break
        end
      end
      break if @app.present?
    end

    default_prompt = ''
    default_prompt = " [#{@app}]" if @app.present?

    new_app = nil
    while new_app.blank?
      STDOUT.puts "Enter the heroku app#{default_prompt}: "
      new_app = STDIN.gets

      if new_app.blank?
        new_app = @app
      else
        new_app.strip!
      end
    end

    @app = new_app
  end

end

