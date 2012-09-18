

module ResultType
	TOTAL = 0
	AGE = 1
	REGION = 2
	SUBREGION = 3
end

class Vote
	include Mongoid::Document
	include Mongoid::Timestamps # adds created_at, updated_at fields

	field :party_id, type: Integer
	field :voter_hash, type: String # a hash that consist of phone id and phone number
	field :age_bracket, type: Integer 
	field :region_id, type: Integer # region id
	field :sub_region_id, type: Integer # subregion id

	validates_presence_of :party_id
	validates_presence_of :voter_hash
	validates_presence_of :age_bracket
	validates_presence_of :region_id
	validates_presence_of :sub_region_id

	index({ :party_id => 1}, { :unique => true})

	def self.create_vote(args)
		vote = Vote.new :voter_hash => args[:phone_id]
		vote.age_bracket = args[:age_bracket]
		vote.region_id = args[:region_id]
		vote.sub_region_id = args[:sub_region_id]
		vote.party_id = args[:party_id]
		vote.save
		vote
	end
	
end

class PredefinedResult
	include Mongoid::Document
	include Mongoid::Timestamps

	field :document_string, :type => String
	field :result_type, :type => Integer

	validates_presence_of :document_string
	validates_inclusion_of :result_type, :in => [ResultType::TOTAL, ResultType::AGE, 
												ResultType::REGION, ResultType::SUBREGION]

	scope :total, where(:result_type => ResultType::TOTAL)
	scope :age, where(:result_type => ResultType::AGE)
	scope :region, where(:result_type => ResultType::REGION)
	scope :subregion, where(:result_type => ResultType::SUBREGION)
end


