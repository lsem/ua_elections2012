
def configure_mongoid(force_environment_mode = nil)
	# we sat manually RACK_ENV in non-sinatra/rails/etc.. application 
	# for mongoid can not be used without this one
	if force_environment_mode
		ENV['RACK_ENV'] ||= force_environment_mode.to_s
	end
	Mongoid.configure do |config|
		p ENV
		puts "your env is: #{ENV['RACK_ENV']}"
		production_env = ENV['RACK_ENV'] == :production
		puts "(dbg) production_env: #{production_env}"
		if production_env
			mongo_uri = URI.parse(ENV["MONGOLAB_URI"])		
			ENV['MONGOID_HOST'] = mongo_uri.host
			ENV['MONGOID_PORT'] = mongo_uri.port.to_s
			ENV['MONGOID_USERNAME'] = mongo_uri.user
			ENV['MONGOID_PASSWORD'] = mongo_uri.password
			ENV['MONGOID_DATABASE'] = mongo_uri.path.gsub("/", "")
		end
		Mongoid.load!('mongoid.yml')
	end
end


