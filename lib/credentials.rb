# Keeps track of passwords, api keys, etc.  All the sensitive scraper stuff.

require 'json'                # json gem
require 'hashie'              # hashie gem
require 'octokit'             # octokit gem

module Credentials
  def self.github_client
    creds = Hashie::Mash.new(JSON.parse(File.read('creds.json')))
    Octokit::Client.new(:login => creds.login, :token => creds.token)
  end
end

