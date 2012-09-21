require 'spec_helper'

describe "Sinatra models" do

	it "Should insert vote persistently to votes collection" do
		# insert a record to a databse, check count number 
		Vote.delete_all
		expect {
			# phone_num, phone_id, party_id, age_bracket, regiod_id
			Vote.create_vote( {:phone_id => "0961234567",
					:age_bracket => "22",
					:region_id => "100",
					:sub_region_id => "200",
					:party_id => "300"} )
		}.to change {Vote.count}.by(1)
	end

	it "should not be valid since not all required parameters provided" do		
		Vote.create_vote(:phone_id => "12123", :phone_num => "123123").valid?.should be_false
	end

end

