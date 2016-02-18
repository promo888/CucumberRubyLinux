require 'cucumber'
#require 'capybara'
require File.expand_path('../../../support/custom_config', __FILE__)
include CONFIG

# encoding: utf-8



When /^Visiting some Url$/  do
  p ENV["env"]
  # begin
  #     Capybara.register_driver :selenium do |app|
  #     Capybara::Selenium::Driver.new(app, :browser => :chrome)
  # end




 #  session = Capybara::Session.new(:selenium)
 #    p CONFIG.get['app_host']
 #  session.visit CONFIG.get['app_host'] #"http://www.youtube.com"
 #  #session.visit "http://www.amberbit.com"
 #
 #  if session.has_content?("Ruby on Rails web development")
 #    puts "All shiny, captain!"
 #  else
 #    puts ":( no tagline fonud, possibly something's broken"
 #    #exit(-1)
 #  end
 #
 # end
end

Then /^Url's page appears$/  do

end







