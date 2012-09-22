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
require './results_exporting'

EXPORT_RESULTS_PERIOD_SEC = 10

module Errors
	SUCCESS = 0
	MANDATORY_PARAM_MISSING = -1	
	UNKNOWN_COMMAND = -2
	INVALID_RESULT_TYPE = -3
	ACTUAL = -4
	INVALID_PARAM_VALUES = -5
end

configure do
	configure_mongoid # see mongoid_conf.rb
end

# ==========================================================
#     handlers 
# ==========================================================

get '/vote' do
	content_type :json
	votes_mandatory_params = [:phone_id, :party_id, :age_bracket, :region_id, :sub_region_id ]

	# check whether all mandatory parameters are set	
	votes_mandatory_params.each do |p| 
		unless params[p]
			return "{ \"status\" : #{Errors::MANDATORY_PARAM_MISSING} }"
		end
	end
	
	status_code = Errors::SUCCESS	
	vote = Vote.create_vote(params, false) # false flag passed to prevent of saving
	if vote.valid?
		vote.save
	else
		status_code = Errors::INVALID_PARAM_VALUES
	end		
	"{ \"status\" : #{status_code} }"
end

get '/export_results' do
	content_type :json
	logger.info "export results command has been triggered"
	status_code = Errors::SUCCESS

	can_update = true
	if PredefinedResult.count > 0
		last_update = PredefinedResult.last.created_at
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
	 "{\"status\" : #{status_code}}"
end

get '/results/:kind' do |kind|
	content_type :json
		
	last_result = case kind.to_sym
	when :total then PredefinedResult.total.last
	when :age then PredefinedResult.age.last
	when :region then PredefinedResult.region.last
	when :subregion then PredefinedResult.subregion.last
	else
		return "{ \"status\" : #{Errors::INVALID_RESULT_TYPE}}"
	end
	result_data = last_result ? last_result.document_string : "{}"
	"{\"status\" : #{Errors::SUCCESS}, \"data\" : #{result_data}}"
end

get '/admin/:command' do |command|
	content_type :json
	status = Errors::SUCCESS
	case command.to_sym
	when :clear_votes then Vote.delete_all
	when :clear_results then PredefinedResult.delete_all
	when :clear_all 
		PredefinedResult.delete_all
		Vote.delete_all
	else
		status = Errors::UNKNOWN_COMMAND
	end
	"{ \"status\" : #{status} }"
end 
