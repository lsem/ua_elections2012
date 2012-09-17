require 'rubygems'
require 'sinatra'
require 'mongoid'
require 'digest'
require 'json'
require "sinatra/reloader" if development?
require './models'

PARTIES = (1..22)

AGE_BRACKETS = [1, 2, 3, 4, 5, 6, 7]

REGIONS = (1..24)

SUB_REGIONS = (1..1500)

module Errors
	SUCCESS = 0
	MANDATORY_PARAM_MISSING = -1
	MISSING_ID_PARAM = -2
	UNKNOWN_COMMAND = -3
	EXPORT_ERROR = -5
end

configure do
	Mongoid.configure do |config|
		Mongoid.load!('mongoid.yml')
	end
end

module ResultType
	TOTAL_VOTES = 1
	AGE_VOTES = 2
	REGION_VOTES = 3
	SUBREGION_VOTES = 4
end

def export_age_results
	# for each party get available results at the moment
	PARTIES.each do |pid|
		# for each age bracket get votes count for given party id (pid)
		AGE_BRACKETS.each do |ab|
			vcount = Vote.where(:party_id => pid).and(:age_bracket => ab).count
			AgeResult.create(:age_bracket => ab, :result => Result.new(:party_id => pid, :votes => vcount))
		end
	end
end

def export_regions_results
	# for each party get availabe results at the moment 
	PARTIES.each do |pid|
		REGIONS.each do |rid|
			vcount = Vote.where(:party_id => pid).and(:region => rid).count
			RegionResult.create(:region_id => rid, :result => Result.new(:party_id => pid, :votes => vcount))
		end
	end
end

def export_total_results
	PARTIES.each do |pid|
		vcount = Vote.where(:party_id => pid).count
		TotalResult.create(:result => Result.new(:party_id => pid, :votes => vcount))
	end
end


# ==========================================================
#     handlers 
# ==========================================================

get '/hi' do
	content_type :json
	if development?
		"env.: DEVELOPMENT"
	else
		"env.: #{ENV['RACK_ENV']}"
	end
end

get '/vote' do
	content_type :json

	phone_id = params[:phone_id]
	phone_num = params[:phone_num]
	party_id = params[:party_id]
	age_bracket = params[:age_bracket]
	region_id = params[:region_id]

	unless phone_id and phone_num and party_id and age_bracket and region_id
		'{ "status" : #{Errors::MANDATORY_PARAM_MISSING} }'
	else
		Vote.create_vote(phone_num, phone_id, party_id, age_bracket, region_id)
		'{ "status" : "success" }'
	end
end

get '/admin/:command' do |command|
	content_type :json
	status = Errors::SUCCESS

	case command
	when "cleardb"
		Vote.delete_all
	else
		status = Errors::UNKNOWN_COMMAND
	end
	"{ \"status\" : #{status} }"
end 

# statistic for parties by age
# returns -2 in case of missing party id
get '/stat/party_by_age/:pid' do |pid|
	content_type :json

	if pid
		party_votes = Vote.where(:party_id => pid.to_i)
		age_brackets = {}
		AGE_BRACKETS.each do |bracket|
			age_brackets[bracket] = party_votes.where(:age_bracket => bracket).count
		end	
		age_brackets.to_json
	else
		"{ 'status' : #{Errors::MISSING_ID_PARAM} }"
	end
end

get '/stat/party_by_region/:pid' do |pid|
	content_type :json
	if pid
		party_votes = Vote.where(:party_id == pid)
		region_votes = {}
		REGIONS.each do |rid|
			region_votes[rid] = party_votes.where(:region_id => rid).count
		end
		region_votes.to_json
	else
		"{ 'status' : #{Errors::UNKNOWN_COMMAND} }"
	end
end

get '/stat/general' do
	logger.info "reqested general statistic"
	content_type :json
	# status 200 - set html status code

	party_votes = {}
	PARTIES.each do |pid|
		party_votes[pid] = Vote.where(:party_id => pid).count
	end
	"{ \"votes_count\": #{Vote.all.count}, \"details\" : #{party_votes.to_json}}"
end

get '/errormsg/:id' do |eid|
	content_type :json	
	message = case eid.to_i
		when Errors::SUCCESS = 0 then "success"
		when Errors::MANDATORY_PARAM_MISSING = -1 then "not all mandatory params provided"
		when Errors::MISSING_ID_PARAM = -2 then "missing party_id parameter"
		when Errors::UNKNOWN_COMMAND = -3 then "unknown command"
		else 
			"unknown error"
		end
	return "{ \"#{message}\" }"
end

get '/export_results/:kind' do |kind|
	content_type :json

	statcode = "0"
	begin
		case kind.to_sym
		when :age 
			export_age_results
		when :region 
			export_regions_results
		when :total 
			export_total_results
		else
			statcode = Errors::UNKNOWN_COMMAND
		end
	rescue
		raise if development? 
		statcode = Errors::EXPORT_ERROR
	end
	"{ \"status\" : #{statcode} }"
end
