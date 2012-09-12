

require 'sinatra'
require 'mongoid'
#require "sinatra/reloader" if development?


configure do
	Mongoid.configure do |config|
		Mongoid.load!('mongoid.yml')
	end
end

class TestRecord
    include Mongoid::Document
    
    field :code, type: String
    field :sector,    type: String
    field :share_id, type: Integer
    field :jse_code, type: Integer
end


get '/hi' do
	content_type :json
	rec = TestRecord.new
	rec.sector = 'test_sector'
	rec.to_json	

	ENV['RACK_ENV']

#	"greetings!"
end

