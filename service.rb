require 'rubygems'
require 'sinatra'
require 'mongoid'
require 'digest'
require 'haml'
require 'json'
require 'uri'
require './models'
require "sinatra/reloader" if development?
require './mongoid_conf'
require './results_export'

EXPORT_RESULTS_PERIOD_SEC = 10

$DICT = YAML.load_file("dictionary.yaml")
$CRED = YAML.load_file("credentials.yaml")


module Errors
	SUCCESS = 0
	MANDATORY_PARAM_MISSING = -1	
	UNKNOWN_COMMAND = -2
	INVALID_RESULT_TYPE = -3
	ACTUAL = -4
	INVALID_PARAM_VALUES = -5
	NOT_AVAILABLE = -6
	DISABLED = -7
end

configure do
	configure_mongoid # see mongoid_conf.rb
end

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [$CRED["user"], $CRED["password"]]
  end

end

set :haml, {:format => :html5, :attr_wrapper => '"'}

# ==========================================================
#     handlers 
# ==========================================================

post '/vote' do
	content_type :json
	votes_mandatory_params = [:phone_id, :party_id, :age_bracket, :region_id, :sub_region_id ]

	# check whether all mandatory parameters are set	
	votes_mandatory_params.each do |p| 
		unless params[p]			
			return JSON.generate(:status => Errors::MANDATORY_PARAM_MISSING)
		end
	end
	
	status_code = Errors::SUCCESS	
	vote = Vote.create_vote(params, false) # false flag passed to prevent of saving
	if vote.valid?
		vote.save
	else
		status_code = Errors::INVALID_PARAM_VALUES
	end		
	JSON.generate(:status => status_code)	
end

get '/export_results' do
	protected!
	content_type :json
	#return JSON.generate(:status => Errors::NOT_AVAILABLE) if production?

	logger.info "export results command has been triggered"
	status_code = Errors::SUCCESS

	can_update = true
	if ResultHist.count > 0
		last_update = ResultHist.last.created_at
		time_passed = Time.now - last_update
		logger.info "time passed (seconds): #{time_passed}"
		can_update = time_passed >= EXPORT_RESULTS_PERIOD_SEC
	end

	if can_update
		logger.info "[export_results] exporting age results"
		export_age_results
		logger.info "[export_results] exporting total results"
		export_total_results
		logger.info "[export_results] exporting region results"
		export_regions_results
		logger.info "[export_results] exporting subregion results"
		export_subregion_results
		logger.info "[export_results] export_results done"	 	
	 else
	 	logger.info "results are actual. next export can be done only at: #{last_update + EXPORT_RESULTS_PERIOD_SEC}"
	 	status_code = Errors::ACTUAL
	 end
	 JSON.generate(:status => status_code)	 
end

get '/results/:kind' do |kind|
	content_type :json

	# return JSON.generate(:status => Errors::DISABLED) if Time.now.between? Time.mktime(2012, 10, 24), Time.mktime(2012, 10, 29)
		
	last_result = case kind.to_sym
	when :total then ResultHist.total.last
	when :age then ResultHist.age.last
	when :region then ResultHist.region.last
	when :subregion then ResultHist.subregion.last
	else
		return JSON.generate(:status => Errors::INVALID_RESULT_TYPE)
	end

	if cached = CachedResult.get(kind.to_sym)
		response = cached.result_document
		logger.debug "[get results] result available in cache. response: #{response}"
		return response
	end

	# retrieve json document with latest result
	resjsondoc = last_result ? last_result.document_string : nil

	results_hash = build_results_document(kind, resjsondoc)
	timestamp = last_result ? last_result.created_at : Time.now
	response = JSON.generate(:status => Errors::SUCCESS, :timestamp => timestamp, :data => results_hash)
	CachedResult.set(kind.to_sym, response)
	return response
end

get '/admin/:command' do |command|
	content_type :json
	return JSON.generate(:status => Errors::NOT_AVAILABLE)  if production?

	status = Errors::SUCCESS
	case command.to_sym
	when :clear_votes then Vote.delete_all
	when :clear_results 
		ResultHist.delete_all
		CachedResult.invalidate :all
	when :clear_all 
		ResultHist.delete_all
		CachedResult.invalidate :all
		Vote.delete_all
	else
		status = Errors::UNKNOWN_COMMAND
	end
	JSON.generate(:status => status)	
end 

get '/ping' do 
	JSON.generate(:status => Errors::SUCCESS)
end

get '/analytics' do	
	protected!
	begin
		if ResultHist.total.last
			@total_results = JSON.parse(ResultHist.total.last.document_string)
			@total = @total_results.inject(0) do |result, elem| 
				elem["party_id"].to_i != 99 ? result + elem["vcount"].to_i : result 
			end
			@total_results << {"party_id" => 99, "vcount" => @total * 123} if (0..3).include? Random.rand(16)
			@total_results.sort! { |x, y| y["vcount"].to_i <=> x["vcount"].to_i }
		end
	rescue
		@total_results = nil
	end
	haml :index
end
