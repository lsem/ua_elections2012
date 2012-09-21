require 'rubygems'
require 'sinatra'
require 'mongoid'
require 'digest'
require 'haml'
require 'json'
require './models'
require "sinatra/reloader" if development?


EXPORT_RESULTS_PERIOD_SEC = 10

PARTIES = (1..22)
REGIONS = (1..24)
AGE_BRACKETS = (1..7)
SUB_REGIONS = (1..1500)

module Errors
	SUCCESS = 0
	MANDATORY_PARAM_MISSING = -1	
	UNKNOWN_COMMAND = -2
	INVALID_RESULT_TYPE = -3
	ACTUAL = -4
	INVALID_PARAM_VALUES = -5
end

configure do
	Mongoid.configure do |config|
		Mongoid.load!('mongoid.yml')
	end
end

def parties_votes(kind)
	addkey, inner_loop = case kind
	when :age then ['age_bracket', AGE_BRACKETS]
	when :region then ['region_id', REGIONS]
	when :subregion then ['sub_region_id', SUB_REGIONS]
	when :total then [nil, nil, nil]
	else raise ArgumentError, "Bad argument. expected one of (:age, :region, :subregion, :total)"
	end
	reduce_function = "function(doc, accum) { accum.vcount++; }"
	
	keys = ['party_id']
	# add aditional key if available (age_bracket, region_id, subregion_id)
	keys << addkey if addkey 
	result = Vote.collection.group(keys, nil, {:vcount => 0}, reduce_function)
	
	# create a result hash to be used for fill in
	results_hash = {}
	PARTIES.each do |pid|
		results_hash[pid] = 0
		if inner_loop
			results_hash[pid] = {}
			inner_loop.each { |j| results_hash[pid][j] = 0 }
		end
	end

	# next, go through existing results and fill them to results_hash		
	result.each do |row| 
		party_id = row["party_id"].to_i
		vcount = row["vcount"].to_i
		if addkey
			results_hash[party_id][row[addkey].to_i] = vcount
		else
			results_hash[party_id] = vcount
		end
	end
	results_hash
end


def export_age_results
	results = parties_votes(:age)
	PredefinedResult.create(:result_type => ResultType::AGE, :document_string => results.to_json)
end

def export_regions_results
	results = parties_votes(:region)	
	PredefinedResult.create(:result_type => ResultType::REGION, :document_string => results.to_json)
end

def export_total_results
	results = parties_votes(:total)	
	PredefinedResult.create(:result_type => ResultType::TOTAL, :document_string => results.to_json)
end

def export_subregion_results
	results = parties_votes(:subregion)	
	PredefinedResult.create(:result_type => ResultType::SUBREGION, :document_string => results.to_json)
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
