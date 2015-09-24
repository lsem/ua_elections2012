
def configure_mongoid(force_environment_mode = nil)
    # we sat manually RACK_ENV in non-sinatra/rails/etc.. application 
    # for mongoid can not be used without this one
    if force_environment_mode
      ENV['RACK_ENV'] ||= force_environment_mode.to_s
    end

    Mongoid.configure do |config|
      if force_environment_mode
        production_env = ENV['RACK_ENV'] == :production.to_s
      else
        production_env = production?
      end
      if production_env
        mongo_uri = URI.parse(ENV["MONGOLAB_URI"])      
        ENV['MONGOID_HOST'] = mongo_uri.host
        ENV['MONGOID_PORT'] = mongo_uri.port.to_s
        ENV['MONGOID_USERNAME'] = mongo_uri.user
        ENV['MONGOID_PASSWORD'] = mongo_uri.password
        ENV['MONGOID_DATABASE'] = mongo_uri.path.gsub("/", "")
      end
      Mongoid.logger.level = Logger::WARN
      Mongoid.load!('./config/mongoid.yml')
    end
  end


