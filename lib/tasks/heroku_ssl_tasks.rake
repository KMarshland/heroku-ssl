
namespace :heroku_ssl do

  task :update_certs do
    STDOUT.puts 'Once your app has been deployed to Heroku, hit enter.'

    STDIN.gets

    output = `heroku run rake ssl:generate_certs #{get_email} #{get_domains.join(' ')}`
    # TODO: parse output
  end

  task :generate_certs do
    email = ARGV[1].strip
    email = get_email if email.blank?

    HerokuSSL::register email

    domain = ARGV[2..-1]
    domain = get_domains if domain.blank?

    puts "Registering #{email} for #{domain}"

    certs = HerokuSSL::request_certificate domain

    STDOUT.puts JSON(certs)
  end

  def get_email
    email = nil
    while email.blank? do
      STDOUT.puts 'Enter your email address: '
      email = STDIN.gets
      email.strip! if email.present?
    end
  end

  def get_domains
    STDOUT.puts 'Enter the domain to register: '
    STDIN.gets.strip.split ' '
  end

end

