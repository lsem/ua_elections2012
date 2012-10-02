require 'mongoid'
require './models'


PARTIES = (1..24)
REGIONS = (1..27)
AGE_BRACKETS = (1..7)
SUB_REGIONS = (1..490)


def parties_votes(kind)
	addkey = case kind.to_sym
	when :age then 'age_bracket'
	when :region then 'region_id'
	when :subregion then 'sub_region_id'
	when :total then nil
	else raise ArgumentError, "Bad argument. expected one of (:age, :region, :subregion, :total)"
	end
	reduce_function = "function(doc, accum) { accum.vcount++; }"
	
	keys = ['party_id']
	# add aditional key if available (age_bracket, region_id, subregion_id)
	keys << addkey if addkey 
	result = Vote.collection.group(:key => keys, :conditions => nil, 
		:initial => {:vcount => 0}, :reduce => reduce_function)
	return result
end

# builds json document with results for specified category (total, age, region, subregion)
def build_results_document(kind, results_json)
	inner_loop, addkey  = case kind.to_sym
		when :total then [nil, nil]
		when :age then [AGE_BRACKETS, 'age_bracket']
		when :region then [REGIONS, 'region_id']
		when :subregion then [SUB_REGIONS, 'sub_region_id']
		else raise ArgumentError, "Unknown argument passed"
		end

	puts "> creating blank"
	# create blank results hash

	results_hash = Hash.new{ |h, k| 
		h[k] = inner_loop ? Hash.new { |h2, k2| h2[k2] = 0  }  : 0
	}

	return results_hash unless results_json # return blank if no results 

	puts "> parsing json"
	# fillin blank results hash with extracted last results
	# # next, go through existing results and fill them to results_hash			
	JSON.parse(results_json).each do |row|
		party_id = row["party_id"].to_i
		vcount = row["vcount"].to_i
		
		if addkey
			# if inner_loop.include?(party_id)
				results_hash[party_id][row[addkey].to_i] = vcount
			# end
		else
			# TODO: get rid of hardcoded value
			# if PARTIES.include?(party_id)
				results_hash[party_id] = vcount
			# end
		end
	end
	results_hash
end


def export_age_results
	results = parties_votes(:age)
	ResultHist.create(:result_type => ResultType::AGE, :document_string => results.to_json)
	CachedResult.invalidate(:age) # invalidate cache
end

def export_regions_results
	results = parties_votes(:region)	
	ResultHist.create(:result_type => ResultType::REGION, :document_string => results.to_json)
	CachedResult.invalidate(:region) # invalidate cache
end

def export_total_results
	results = parties_votes(:total)	
	ResultHist.create(:result_type => ResultType::TOTAL, :document_string => results.to_json)
	CachedResult.invalidate(:total) # invalidate cache
end

def export_subregion_results
	results = parties_votes(:subregion)	
	ResultHist.create(:result_type => ResultType::SUBREGION, :document_string => results.to_json)
	CachedResult.invalidate(:subregion) # invalidate cache
end
