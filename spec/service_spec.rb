require 'spec_helper'
require 'factory_girl'

describe "Sinatra service" do 
	
	it "should respond to 'GET hi'" do
		get '/hi'
		last_response.should be_ok
		last_response.body.should match(/env.:*/)
	end

	it "should insert votes properly" do
		expect { FactoryGirl.create(:vote) }.to change {Vote.count}.by(1)
	end

	it "should export result properly" do
		# save current count
		total_results_count = PredefinedResult.total.count
		age_results_count = PredefinedResult.age.count
		region_results_count = PredefinedResult.region.count

		puts "total_results_count: #{total_results_count}"
		puts "age_results_count: #{age_results_count}"

		FactoryGirl.create(:vote)
		export_total_results()
		export_regions_results()

		PredefinedResult.total.count.should be_equal(total_results_count + 1)
		PredefinedResult.age.count.should be_equal(age_results_count) # should not be changed
		PredefinedResult.region.count.should be_equal(region_results_count + 1) # should not be changed	
	end

end
