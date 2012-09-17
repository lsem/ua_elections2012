

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
		voter_hash = Digest::SHA1.hexdigest(args[:phone_id].to_s + args[:phone_num].to_s)
		vote = Vote.new :voter_hash => voter_hash		
		vote.age_bracket = args[:age_bracket]
		vote.region_id = args[:region_id]
		vote.sub_region_id = args[:sub_region_id]
		vote.party_id = args[:party_id]
		vote.save
		vote
	end
	
end

class AgeResult
	include Mongoid::Document
	has_one :result, :as => :resultable, :autosave => true
	field :age_bracket, :type => Integer
	
	validates_presence_of :age_bracket
end

class TotalResult
	include Mongoid::Document
	has_one :result, :as => :resultable, :autosave => true
end

class RegionResult
	include Mongoid::Document
	field :region_id, :type => Integer
	has_one :result, :as => :resultable, :autosave => true
	
	validates_presence_of :region_id
end

class Result
	include Mongoid::Document
	include Mongoid::Timestamps
	
	belongs_to :resultable, :polymorphic => true

	field :party_id, :type => Integer
	field :votes, :type => Integer

	validates_presence_of :party_id
	validates_presence_of :votes
end

