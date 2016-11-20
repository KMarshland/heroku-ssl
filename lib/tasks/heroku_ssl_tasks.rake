
namespace :ssl do

  task :update_heroku_certs do
    STDOUT.puts 'Once your app has been deployed to Heroku, hit enter.'

    output = `heroku run rake ssl:generate_certs #{get_email} #{get_domains.join(' ')}`
    # TODO: parse output
  end

  task :generate_certs do |t, args|
    email = ARGV[1].strip
    email = get_email if email.blank?

    HerokuSSL::register email

    domain = ARGV[2..-1]
    domain = get_domains if domain.blank?

    certs = HerokuSSL::request_certificate domain

    STDOUT.puts JSON(certs)
  end

  def get_email
    STDOUT.puts 'Enter your email address: '
    STDIN.gets.strip
  end

  def get_domains
    STDOUT.puts 'Enter the domain to register: '
    STDIN.gets.strip.split ' '
  end

end

