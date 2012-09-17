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

	it "should do results exporting right" do
		#pending "temporary disabled"
		expect { 
			FactoryGirl.create(:vote)
			export_total_results()
		}.to change {TotalResult.count}.by(PARTIES.count)

		expect { 
			FactoryGirl.create(:vote)
			export_age_results()
		}.to change {AgeResult.count}.by(PARTIES.count * AGE_BRACKETS.count)

		expect {
			FactoryGirl.create(:vote)
			export_regions_results()
		}.to change {RegionResult.count}.by(PARTIES.count * REGIONS.count)

	end

end
