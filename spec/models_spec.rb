require 'spec_helper'

describe "Sinatra models" do

	it "Should insert vote persistenly to votes collection" do
		# insert a record to a databse, check count number 
		expect {
			# phone_num, phone_id, party_id, age_bracket, regiod_id
			Vote.create_vote(:phone_id => "0961234567", 
					:phone_num => "android_device", 
					:voter_hash => 12, 
					:age_bracket => 22, 
					:phone_num => 2,
					:region_id => 100,
					:sub_region_id => 200,
					:party_id => 300 )
		}.to change {Vote.count}.by(1)
	end

	it "should not be valid since not all required parameters provided" do		
		Vote.create_vote(:phone_id => "12123", :phone_num => "123123").valid?.should be_false
	end

end

