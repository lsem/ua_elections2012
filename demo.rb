require 'sinatra'
require 'mongoid'
require "sinatra/reloader" if development?

configure do
	Mongoid.configure do |config|
		Mongoid.load!('mongoid.yml')
	end
end

get '/hi' do
	content_type :json
	"greetings!"
end

