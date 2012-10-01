require 'logger'
require 'yaml'

# TODO: 
# 	exporting collections not implemented	
#

LOG_PREFIX = 'logs'
Dir.mkdir(LOG_PREFIX) unless File.exists?(LOG_PREFIX)
$logger = Logger.new("#{LOG_PREFIX}/maintanance.log", 'daily')
$logger.datetime_format = "%Y-%m-%d %H:%M:%S"
$logger.level = Logger::DEBUG

begin
	dburi = YAML.load_file("./config/.dburi.yaml")
	$logger.debug "loaded dburi yaml: #{dburi.inspect}"
	$mongo_uri = URI.parse(dburi["MONGOURI"])
	$logger.error "failed to connect to the db. mongo db uri not found."
rescue => exception
	begin
		$logger.debug ".dburi file not found, trying to find in env. bt: #{exception}"
		# coult not found in file, trying to load from env.
		$mongo_uri = URI.parse(ENV["MONGOLAB_URI"])
		$logger.debug "uri found. it is: '#{$mongo_uri}'"
	rescue => exception
		$logger.debug "bt: #{exception}"
		$logger.error "failed to connect to the db. mongolab uri not found."
	end
end

def outdir(type, format)
	tm = Time.now.strftime("%Y%m%d_%H:%M:%S")
	"backups/#{type.to_s}/#{tm}/#{format.to_s}/"
end

def make_dump_util_command_line(type, format, params = {})
	database = $mongo_uri.path.gsub("/", "")
	password = $mongo_uri.password
	username = $mongo_uri.user
	port = $mongo_uri.port.to_s
	host = $mongo_uri.host
	username &&= "-u #{username}"
	password &&= "-p #{password}"		
	"mongodump -d #{database} -h #{host}:#{port} "\
			"#{username} #{password} -o #{outdir(type, format)}"
end

def dump_database(type, format, params = {})	
	$logger.debug "a user requested database data export. format: #{format}, type: #{type}"
	cmdline = make_dump_util_command_line(type, format, params)
	$logger.info "command line: #{cmdline}"
	unless result = system(cmdline)
		$logger.error "failed to execute dumputil. exit status: "\
				"#{$?.exitstatus}, cmdline used: #{cmdline}"
	else
		$logger.info "finished data export procedure"
	end
end

namespace :backup do
	namespace :db do
		task :bson do			
			dump_database :db, :binary
		end
	end
end
