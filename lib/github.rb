# Helps the scraper interact with GitHub.

require 'json'
require 'hashie'
require 'octokit'
require 'retryable'


class GitHub
    include Retryable

    attr_accessor :client, :logger

    def initialize opts={}
        @client = opts[:client]
        unless @client
            creds = Hashie::Mash.new(JSON.parse(File.read('creds.json')))
            @client = Octokit::Client.new(:login => creds.login, :token => creds.token)
        end

        @logger = opts[:logger] || lambda { |msg| puts msg }

        @start = Time.now.to_i
        @api_calls = 0
    end

    def log str
        @logger.call str
    end


    # sleep to avoid bumping into github's 60-per-minute API limit
    # Github may change at any time so make sure your code still retries when rate limited.
    def github_holdoff
        if @api_calls > 60
            holdoff = 60 - (Time.now.to_i - @start)
            if holdoff > 0
                log "hit github limit, sleeping for #{holdoff} seconds"
                sleep holdoff
            end
            @start = Time.now.to_i
            @api_calls = 0
        end
    end


    def call_client method, *args
        github_holdoff
        result = @client.send method, *args
        @api_calls += 1
        result
    end


    #
    #     here are the utility functions...
    #

    def info name
        call_client :repository, "vim-scripts/#{name}"
    end

    # turns off the issues and wiki tabs for a new repo
    def turn_off_features name
        call_client :update_repository, "vim-scripts/#{name}",
            { :has_issues => false, :has_wiki => false }
    end

    def create name, *args
        call_client :create, name, *args
        turn_off_features name
    end

    def delete name
        result = call_client :delete_repository, name
        if result
            result = call_client :delete_repository, name, :delete_token => result
            if result.status == "deleted"
                log "removed #{name} from github"
            else
                raise "Unknown response from second stage for #{name}: #{result.inspect}"
            end
        else
            raise "got #{result.inspect} trying to delete #{name}"
        end
    end

    def list_all_repos
        result = []
        page = 1
        loop do
            log "fetching page #{page}"
            bunch = call_client :repositories, 'vim-scripts', :page => page
            break if bunch.empty?
            result.push *bunch
            page += 1
        end
        result
    end
end


# This Selenium code does not work anymore.
# it's kept around in case it is required again.
class GitHub::Selenium < GitHub
    def start_selenium
        sel = Selenium::Client::Driver.new :host => 'localhost',
            :port => 4444, :browser => 'firefox', :url => 'https://github.com'
        sel.start
        sel.set_context "deleee"
        sel.open "/login"
        sel.type "login_field", "vim-scripts"
        password = File.read('password').chomp rescue raise("Put vim-script's password in a file named 'password'.")
        sel.type "password", password
        sel.click "commit", :wait_for => :page
        sel
    end

    def stop_selenium sel
        sel.close_current_browser_session
        sel.stop
    end

    # github's api is claiming some repos exist when they clearly don't.  the
    # only way to fix this appears to be to create a repo of the same name and
    # delete it using the regular interface (trying to delete using the api
    # throws 500 server errors).  Hence all this Selenium.  Arg.
    def obliterate_repo sel, name
        sel.open "/repositories/new"
        sel.type "repository_name", name
        sel.click "//button[@type='submit']", :wait_for => :page
        sel.open "/vim-scripts/#{name}/admin"
        sel.click "//div[@id='addons_bucket']/div[3]/div[1]/a/span"
        sel.click "//div[@id='addons_bucket']/div[3]/div[3]/form/button"
    end

    def perform_obliterate
        # if selenium is true then we must be having problems with phantom repos
        if remote && $selenium
            puts "  apparently #{remote.url} exists, obliterating..."
            obliterate_repo $selenium, script['name']
            remote = nil
            puts "  obliterate succeeded."
            sleep 2  # github requires a bit of time to sync
        end
    end
end

