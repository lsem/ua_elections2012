require 'spec_helper'
require 'factory_girl'
require 'digest'

describe "Sinatra service" do 
	
	it "should insert votes properly" do
		expect { FactoryGirl.create(:vote) }.to change {Vote.count}.by(1)
	end

	it "should export result properly" do
		pending "temporarly disables"
		# save current count
		total_results_count = ResultHist.total.count
		age_results_count = ResultHist.age.count
		region_results_count = ResultHist.region.count

		puts "total_results_count: #{total_results_count}"
		puts "age_results_count: #{age_results_count}"

		FactoryGirl.create(:vote)
		export_total_results()
		export_regions_results()
		export_age_results()

		ResultHist.total.count.should be_equal(total_results_count + 1)
		ResultHist.age.count.should be_equal(age_results_count + 1) # should not be changed
		ResultHist.region.count.should be_equal(region_results_count + 1) # should not be changed	
	end

	it "vote should return fail without mandatory params provided" do
		pending "temporarly disabled"	
		post '/vote'
		last_response.should be_ok
		last_response.body.should include "#{Errors::MANDATORY_PARAM_MISSING}"

		post '/vote', "phone_id" => "ABCDEFG"
		last_response.should be_ok
		last_response.body.should include "#{Errors::MANDATORY_PARAM_MISSING}"

		params = {:phone_id => "ABCDEFG", :party_id => "1", 
				:age_bracket => "2", :region_id => "4", :sub_region_id => "4"}

	end

	it "vote should return success in case all mandatory parameters provided" do
		pending "temporarly disabled"	
		post "/vote", "phone_id" => "ABCDEFG", "party_id" => "2", "region_id" => "1", "sub_region_id" => "3", "age_id" => "100"

		last_response.body.should include  "#{Errors::SUCCESS}"
	end

	
	# http://stackoverflow.com/questions/3723547/how-to-use-mongodb-ruby-driver-to-do-a-group-group-by
	it "should insert votes right" do	
		Vote.delete_all
		Vote.count.should be_equal 0
		
		# next matrix describes votes session: six votes (six columns in matrix) have to be done
		parties_to_be_voted = [1, 3, 20, 1, 1, 3] # three times for 1, two times for 3 and 1 time for 20
		voters_ages         = [1, 2,  3, 4, 4, 3]
		regions_ages        = [1, 2,  3, 3, 2, 2]
		subregions_ages     = [1, 1,  1, 7, 7, 2]
		parties_to_be_voted.count.times do |i|
			get "/vote?phone_id=#{Digest::SHA1.hexdigest(i.to_s)}&party_id=#{parties_to_be_voted[i]}&age_bracket=#{voters_ages[i]}&region_id=#{regions_ages[i]}&sub_region_id=#{subregions_ages[i]}"			 
			last_response.should be_ok
			last_response.body.should include "#{Errors::SUCCESS}"
		end

		#
		# Step 2. export results to history tables
		#

		export_age_results
		export_regions_results
		export_total_results
		export_subregion_results

		#
		# Step 3. get results, parse them and check for validness
		#

		get '/results/total'
		last_response.should be_ok
		last_response.body.should include "#{Errors::SUCCESS}"
		totalrjson = JSON.parse(last_response.body)["data"]

		get '/results/age'
		last_response.should be_ok
		last_response.body.should include "#{Errors::SUCCESS}"
		agerjson = JSON.parse(last_response.body)["data"]
		
		get '/results/region'
		last_response.should be_ok
		last_response.body.should include "#{Errors::SUCCESS}"
		regionrjson = JSON.parse(last_response.body)["data"]

		get '/results/subregion'
		last_response.should be_ok
		last_response.body.should include "#{Errors::SUCCESS}"
		subregionrjson = JSON.parse(last_response.body)["data"]

		# party 1 should have 3 votes total
		totalrjson["1"].should be_equal 3
		totalrjson["2"].should be_equal 0
		totalrjson["3"].should be_equal 2
		totalrjson["4"].should be_equal 0
		totalrjson["20"].should be_equal 1
		a_rest_parties = PARTIES.to_a - parties_to_be_voted
		a_rest_parties.each { |x| totalrjson[x.to_s].should be_equal 0 }

		#results = parties_votes(:age)
		agerjson["1"]["1"].should be_equal 1
		agerjson["3"]["2"].should be_equal 1
		agerjson["20"]["3"].should be_equal 1
		agerjson["1"]["4"].should be_equal 2
		agerjson["3"]["3"].should be_equal 1
		# # all others should have zero

		a_rest_age_bracks = AGE_BRACKETS.to_a - voters_ages	
		PARTIES.each { |pid| 
			a_rest_age_bracks.each { |ab| agerjson[pid.to_s][ab.to_s].should be_equal 0 } 
		}

		# results = parties_votes(:region)
		regionrjson["1"]["1"].should be_equal 1
		regionrjson["3"]["2"].should be_equal 2
		regionrjson["20"]["3"].should be_equal 1
		regionrjson["1"]["3"].should be_equal 1
		regionrjson["1"]["2"].should be_equal 1
		a_rest_of_regions = REGIONS.to_a - regions_ages
		PARTIES.each { |pid| 
			a_rest_of_regions.each { |rid| regionrjson[pid.to_s][rid.to_s].should be_equal 0 }
		}


		subregionrjson["1"]["1"].should be_equal 1
		subregionrjson["3"]["1"].should be_equal 1
		subregionrjson["20"]["1"].should be_equal 1
		subregionrjson["1"]["7"].should be_equal 2
		subregionrjson["3"]["2"].should be_equal 1
		a_rest_of_subregions = SUB_REGIONS.to_a - subregions_ages
		PARTIES.each { |pid| 
			a_rest_of_subregions.each { |srid| subregionrjson[pid.to_s][srid.to_s].should be_equal 0 }
		}
	end
end
