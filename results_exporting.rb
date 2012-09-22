require 'mongoid'
require './models'


PARTIES = (1..22)
REGIONS = (1..24)
AGE_BRACKETS = (1..7)
SUB_REGIONS = (1..1500)


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
