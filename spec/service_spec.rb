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
		total_results_count = PredefinedResult.total.count
		age_results_count = PredefinedResult.age.count
		region_results_count = PredefinedResult.region.count

		puts "total_results_count: #{total_results_count}"
		puts "age_results_count: #{age_results_count}"

		FactoryGirl.create(:vote)
		export_total_results()
		export_regions_results()
		export_age_results()

		PredefinedResult.total.count.should be_equal(total_results_count + 1)
		PredefinedResult.age.count.should be_equal(age_results_count + 1) # should not be changed
		PredefinedResult.region.count.should be_equal(region_results_count + 1) # should not be changed	
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

		results = parties_votes(:total)
		# party 1 should have 3 votes total
		results[1].should be_equal 3
		results[2].should be_equal 0
		results[3].should be_equal 2
		results[4].should be_equal 0
		results[20].should be_equal 1
		a_rest_parties = PARTIES.to_a - parties_to_be_voted
		a_rest_parties.each { |x| results[x].should be_equal 0 }

		results = parties_votes(:age)
		results[1][1].should be_equal 1
		results[3][2].should be_equal 1
		results[20][3].should be_equal 1
		results[1][4].should be_equal 2
		results[3][3].should be_equal 1
		# all others should have zero

		a_rest_age_bracks = AGE_BRACKETS.to_a - voters_ages	
		PARTIES.each { |pid| 
			a_rest_age_bracks.each { |ab| results[pid][ab].should be_equal 0 } 
		}

		results = parties_votes(:region)
		results[1][1].should be_equal 1
		results[3][2].should be_equal 2
		results[20][3].should be_equal 1
		results[1][3].should be_equal 1
		results[1][2].should be_equal 1
		a_rest_of_regions = REGIONS.to_a - regions_ages
		PARTIES.each { |pid| 
			a_rest_of_regions.each { |rid| results[pid][rid].should be_equal 0 }
		}

		results = parties_votes(:subregion)
		results[1][1].should be_equal 1
		results[3][1].should be_equal 1
		results[20][1].should be_equal 1
		results[1][7].should be_equal 2
		results[3][2].should be_equal 1
		a_rest_of_subregions = SUB_REGIONS.to_a - subregions_ages
		PARTIES.each { |pid| 
			a_rest_of_subregions.each { |srid| results[pid][srid].should be_equal 0 }
		}


	end
end
