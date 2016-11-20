module Poo
  class Engine < ::Rails::Engine
    isolate_namespace HerokuSSL
  end
end
