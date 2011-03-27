# Utilities for the scraper to interact with GitHub

require 'json'                # json gem
require 'hashie'              # hashie gem
require 'octokit'             # octokit gem
require 'retryable'


class GitHub
    include Retryable

    def initialize opts
        @client = opts[:client] || raise("specify :client")
        @logger = opts[:logger] || lambda { |msg| puts msg }
        @start = Time.now
        @api_calls = 0
    end

    def log str
        @logger.call str
    end

    def repo_url name
        "http://github.com/vim-scripts/#{name}"
    end

    # We push to vim-scripts.github.com so we don't interfere with your regular ssh key.
    # create a ~/.ssh/vimscripts-id_rsa and ~/.ssh/vimscripts-id_rsa.pub keypair,
    # and create a ~/.ssh/config that has 2 Host sections:
    #   Host github.com\nHostName github.com\nUser git\nIdentityFile ~/.ssh/id_rsa
    #   Host vim-scripts.github.com\nHostName github.com\nUser git\nIdentityFile ~/.ssh/vimscripts-id_rsa
    # see this for more: http://help.github.com/multiple-keys
    def remote_url name
        "git@vim-scripts.github.com:vim-scripts/#{name}"
    end

    # TODO: this does not belong here!
    def repo_heads repo
        path = "#{repo.path}/refs/heads"
        Dir.entries(path).select { |f|
            test ?f, "#{path}/#{f}"
        }
    end

    # sleep to avoid bumping into github's 60-per-minute API limit
    # just make sure num requests + 60 < num seconds elapsed.
    def github_holdoff
        # if @stop - start < @api_calls
            # sleep_time = @api_calls-(stop-start)
            # if sleep_time > 0
                # puts "hit github limit, sleeping for #{}"
                # sleep sleep_time
            # end
        # end
    end

    def call_client method, *args
        github_holdoff
        @client.send method, *args
        @api_calls += 1
    end

    def turn_off_features name
        log "  disabling wiki+issues for #{name}"
        call_client :update_repository, "vim-scripts/#{name}",
            { :has_issues => false, :has_wiki => false }
    end

    def perform_push repo_name
        return unless repo_name
        repo = Gitrb::Repository.new(:path => repo_name.dup, :bare => true)
        script = JSON.parse(File.read(File.join(repo_name, $git_script_file)))
        puts "Uploading #{script['script_id']} - #{script['name']}"

        # rescue nil because an exception is raised when the repo doesn't exist
        remote = @client.repo("vim-scripts/#{script['name']}") rescue nil
        @api_calls += 1

        if remote
            # make sure this actually is the same repo
            puts "  remote already exists: #{remote.url}"
            remote.homepage =~ /script_id=(\d+)$/
            raise "bad url on github repo #{script['name']}" unless $1
            raise "remote #{script['name']} exists but id is for #{$1}" if script['script_id'] != $1
        else
            puts "  remote doesn't exist, creating..."
        end

        unless remote
            retryable(:tries => 4, :sleep => 10) do |retries|
                puts "  creating #{script['script_id']} - #{script['name']}#{retries > 0 ? "  RETRY #{retries}" : ""}"
                remote = @client.create(
                    :name => script['name'],
                    :description => "#{script['summary']}",
                    :homepage => script_id_to_url(script['script_id']),
                    :public => true)
            end
            @api_calls += 1

            turn_off_features script['name']
        end

        repo.git_remote('rm', 'origin') rescue nil
        repo.git_remote('add', 'origin', remote_url(script))
        retryable(:tries => 6, :sleep => 15) do |retries|
            # Gitrb::CommandError is as close to a network timeout error as we're going to get
            puts "  #{"force " if ENV['FORCE']}pushing #{script['script_id']} - #{script['name']}#{retries > 0 ? "  RETRY #{retries}" : ""}"
            args = ['--tags']
            args << '--force' if ENV['FORCE']
            args << 'origin'
            args.push *repo_heads(repo)
            repo.git_push(*args)
        end

        github_holdoff

        # we should have a script that will compare the full list of
        # repos on github and here and print any differences.  that is
        # not a part of this script's job.
        # Octokit.list_repos('vim-scripts')
        # Octokit.delete("vim-scripts/#{ghname}")

        # no need to reset the remote because presumably we created this
        # repo and the remote is already set correctly.
    end
end


# NOTE: this Selenium code does not work anymore.
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

