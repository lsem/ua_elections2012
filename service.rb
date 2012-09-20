require 'rubygems'
require 'sinatra'
require 'mongoid'
require 'digest'
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
end

configure do
	Mongoid.configure do |config|
		Mongoid.load!('mongoid.yml')
	end
end

def export_age_results
	# for each party get available results at the moment
	results = {}
	PARTIES.each do |pid|
		# for each age bracket get votes count for given party id (pid)
		results[pid] = {}
		AGE_BRACKETS.each do |ab|
			vcount = Vote.where(:party_id => pid).and(:age_bracket => ab).count			
			results[pid][ab] = vcount
		end
	end
	PredefinedResult.create(:result_type => ResultType::AGE, :document_string => results.to_json)
end

def export_regions_results
	# for each party get availabe results at the moment 
	results = {}
	PARTIES.each do |pid|
		results[pid] = {}
		REGIONS.each do |rid|
			vcount = Vote.where(:party_id => pid).and(:region => rid).count
			results[pid][rid] = vcount
		end
	end	
	PredefinedResult.create(:result_type => ResultType::REGION, :document_string => results.to_json)
end

def export_total_results
	results = {}
	PARTIES.each do |pid|
		vcount = Vote.where(:party_id => pid).count
		results[pid] = vcount		
	end
	PredefinedResult.create(:result_type => ResultType::TOTAL, :document_string => results.to_json)
end

def export_subregion_results
	results = {}
	PARTIES.each do |pid|
		results[pid] = {}
		SUB_REGIONS.each do |srid|
			vcount = Vote.where(:party_id => pid).and(:sub_region_id => srid).count
			results[pid][srid] = vcount
		end 
	end
	PredefinedResult.create(:result_type => ResultType::SUBREGION, :document_string => results.to_json)
end

# ==========================================================
#     handlers 
# ==========================================================

get '/vote' do
	content_type :json

	phone_id = params[:phone_id]
	party_id = params[:party_id]
	age_bracket = params[:age_bracket]
	region_id = params[:region_id]
	sub_region_id = params[:sub_region_id]

	unless phone_id and party_id and age_bracket and region_id and sub_region_id
		"{ \"status\" : #{Errors::MANDATORY_PARAM_MISSING} }"
	else
		Vote.create_vote(phone_id, party_id, age_bracket, region_id, sub_region_id)
		"{ \"status\" : #{Errors::SUCCESS} }"
	end
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
	when :cleardb then Vote.delete_all
	else
		status = Errors::UNKNOWN_COMMAND
	end
	"{ \"status\" : #{status} }"
end 
