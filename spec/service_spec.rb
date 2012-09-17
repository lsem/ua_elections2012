require 'spec_helper'
require 'factory_girl'

describe "Sinatra service" do 
	
	it "should respond to 'GET hi'" do
		get '/hi'
		last_response.should be_ok
		last_response.body.should match(/env.:*/)
	end

	it "should insert votes properly" do
		expect { FactoryGirl.create(:vote) }.to change {Vote.count}.by 1
	end

	it "should do results exporting right" do
		pending "temporary disabled"
		expect { 
			FactoryGirl.create(:vote, :age_bracket => 2)
			export_total_results()
		}.to change {Result.count}.by(1)
	end

end
