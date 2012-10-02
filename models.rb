require './results_export'

module ResultType
	TOTAL = 0
	AGE = 1
	REGION = 2
	SUBREGION = 3

	def self.parse(type)
		case type.to_sym
		when :total then TOTAL
		when :age then AGE
		when :region then REGION
		when :subregion then SUBREGION
		else raise ArgumentError, "#{type.inspect} is not valid ResultType value"
		end
	end
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

	validates_numericality_of :party_id
	validates_numericality_of :age_bracket
	validates_numericality_of :region_id
	validates_numericality_of :sub_region_id

	  validates_inclusion_of :party_id, :in => PARTIES
	  validates_inclusion_of :age_bracket, :in => AGE_BRACKETS
	  validates_inclusion_of :region_id, :in => REGIONS
	  validates_inclusion_of :sub_region_id, :in => SUB_REGIONS
		
	index({ :party_id => 1}, { :unique => true})
	index({ :party_id => 1, :age_bracket => 1}, {})
	index({ :party_id => 1, :region_id => 1}, {})
	index({ :party_id => 1, :sub_region_id => 1}, {})

	def self.create_vote(args, auto_save = true)		
		vote = Vote.where(:voter_hash => args[:phone_id]).first
		vote ||= Vote.new(:voter_hash => args[:phone_id])
		vote.age_bracket = args[:age_bracket]
		vote.region_id = args[:region_id]
		vote.sub_region_id = args[:sub_region_id]
		vote.party_id = args[:party_id]
		vote.save if auto_save
		vote
	end
	
end

class ResultHist
	include Mongoid::Document
	include Mongoid::Timestamps

	field :document_string, :type => String
	field :result_type, :type => Integer

	validates_presence_of :document_string
	validates_inclusion_of :result_type, 
				:in => [ResultType::TOTAL, ResultType::AGE, 
						ResultType::REGION, ResultType::SUBREGION]

	scope :total, where(:result_type => ResultType::TOTAL)
	scope :age, where(:result_type => ResultType::AGE)
	scope :region, where(:result_type => ResultType::REGION)
	scope :subregion, where(:result_type => ResultType::SUBREGION)
end

class CachedResult
	include Mongoid::Document
	include Mongoid::Timestamps

	field :result_document, :type => String
	field :result_type, :type => Integer

	validates_presence_of :result_document
	validates_presence_of :result_type

	validates_inclusion_of :result_type, 
				:in => [ResultType::TOTAL, ResultType::AGE, 
						ResultType::REGION, ResultType::SUBREGION]

	def self.get(kind)
		where(:result_type => ResultType.parse(kind)).last
	end

	# accepts: (:all, :total, :region, :subregion, :age)
	def self.invalidate(kind)
		if kind == :all 
			delete_all
			return
		end
		where(:result_type => ResultType.parse(kind)).delete_all		
	end

	def self.set(kind, response)
		res = CachedResult.find_or_create_by(:result_type => ResultType.parse(kind))
		res.result_document = response
		res.save
	end
end
