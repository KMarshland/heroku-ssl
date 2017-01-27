
namespace :heroku_ssl do

  task :update_certs do
    update_certs
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

  def update_certs
    STDOUT.puts 'Once your app has been deployed to Heroku, hit enter.'

    STDIN.gets

    email = get_email
    domains = get_domains
    app = get_app

    puts "Attempting to generate ssl certificates for #{app} (registering #{domains} to #{email})"

    #generate the certs on the server
    output = heroku_run("run rake heroku_ssl:generate_certs #{email} #{domains} --app #{app}")

    #read out the certs to temporary files
    unless output.include? '~~ GENERATED CERTIFICATES START ~~'
      puts 'Full log: '
      puts output
      puts ''

      puts 'Could not generate certificates. Please try again later or try running `heroku run rake heroku_ssl:generate_certs` directly'
      return
    end

    output = output.split('~~ GENERATED CERTIFICATES START ~~').last
                 .split('~~ GENERATED CERTIFICATES END ~~').first
    output = JSON(output).with_indifferent_access

    unless output['fullchain'].present? && output['privkey'].present?
      puts 'Output: '
      puts output
      puts ''

      puts 'Failed to read certificates'
      return
    end

    puts 'Successfully generated certificates! Attempting to update Heroku DNS'

    File.open('fullchain.pem', 'wb') do |file|
      file.write output['fullchain']
    end

    File.open('privkey.pem', 'wb') do |file|
      file.write output['privkey']
    end

    # update heroku certs
    certs_response = heroku_run("certs:update fullchain.pem privkey.pem --app #{get_app} --confirm #{get_app}")

    if certs_response =~ /has\sno\sSSL\scertificates/i
      heroku_run("certs:add fullchain.pem privkey.pem --app #{get_app} --confirm #{get_app}")
    end

    # clean up
    File.delete('fullchain.pem', 'privkey.pem')

    puts 'Successfully updated Heroku SSL certificates! Now you just need to make sure your DNS is configured to point as follows: '
    puts heroku_run('domains').split("\n")[4..-1].join("\n")
  end

  def get_email
    return @email if @email.present?

    @email = `git config user.email`
    @email.strip! if @email.present?

    default_prompt = ''
    default_prompt = " [#{@email}]" if @email.present?

    new_email = nil
    while new_email.blank?
      STDOUT.puts "Enter your email#{default_prompt}: "
      new_email = STDIN.gets

      if new_email.blank?
        new_email = @email
      else
        new_email.strip!
      end
    end

    @email = new_email
  end

  def heroku_run(command)
    # RUBYOPT breaks the heroku command for some reason, so you have to unset it
    result = `unset RUBYOPT; heroku #{command}`

    if result =~ /rake\saborted/i
      puts "Don't know how to build task -- make sure you have deployed a version with this gem installed to heroku"
    end

    if result =~ /No\ssuch\sfile\sor\sdirectory/i || result =~ /command\snot\sfound/i
      puts 'Cannot run command heroku -- are you sure you have it installed?'
    end

    if result =~ /Bundler::GemNotFound/i
      puts 'Please log in to heroku by running `heroku login`'
    end

    result
  end

  def get_domains
    return @domain if @domain.present?

    domains = heroku_run('domains').split("\n").select(&:present?)[5..-1]
    if domains.blank?
      puts 'Warning: Could not load domains'
      domains = []
    end
    domains.map! do |domain|
      domain.split(/\s+/).first
    end
    @domain = domains.join ' '

    default_prompt = ''
    default_prompt = " [#{@domain}]" if @domain.present?

    new_domain = nil
    while new_domain.blank?
      STDOUT.puts "Enter the domain to register#{default_prompt}: "
      new_domain = STDIN.gets

      if new_domain.blank?
        new_domain = @domain
      else
        new_domain.strip!
      end
    end

    @domain = new_domain
  end

  def get_app
    return @app if @app.present?

    @apps = @apps || heroku_run('apps').split("\n")
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

