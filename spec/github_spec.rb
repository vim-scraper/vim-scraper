require 'webmock/rspec'
require 'github'


describe "GitHub" do
  class FakeClient
    attr_accessor :count
    def update_repository *args
      @count ||= 0
      @count += 1
    end
  end

  # todo: should only create the clients once per run, not once per test.
  def github
    GitHub.new :client => Octokit::Client.new(:login => "loggyin", :token => "tokkyen"), :logger => lambda { |msg| }
  end

  def base
    'https://api.github.com'
  end

  def should_raise e
    lambda { yield }.should raise_error e
  end


  it "should get repo info" do
    stub = stub_request(:get, "#{base}/repos/vim-scripts/repo").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => "", :headers => {})
    github.info "repo"
    stub.should have_been_requested
  end

  it "should get repo info for a nonexistent repo" do
    stub = stub_request(:get, "#{base}/repos/vim-scripts/repo").
      to_return(:status => 404, :body => { :error => "vim-scripts/repo Repository not found" }.to_json)
    should_raise(Octokit::NotFound) {
      github.info "repo"
    }
    stub.should have_been_requested
  end

  it "should turn off issues and wikis" do
      # For some reason these don't work:
        # :body => { :data => { :values => {:has_issues => false, :has_wiki => false}}},
        # :body => { :data => { "values[has_issues]" => false, "values[has_wiki]" => false}},
    stub = stub_request(:patch, "https://api.github.com/repos/vim-scripts/repo").
      with(:body => "{\"has_issues\":false,\"has_wiki\":false}",
        :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => "", :headers => {})
    github.turn_off_features "repo"
    stub.should have_been_requested
  end

  it "should create a repository" do
    stub_a = stub_request(:post, "https://api.github.com/user/repos").
      with(:body => "{\"description\":\"description\",\"homepage\":\"http://homepage\",\"public\":true,\"name\":\"repo\"}",
        :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => "", :headers => {})
    stub_b = stub_request(:patch, "https://api.github.com/repos/vim-scripts/repo").
         with(:body => "{\"has_issues\":false,\"has_wiki\":false}",
              :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "", :headers => {})

    github.create "repo",
      :description => "description",
      :homepage => "http://homepage",
      :public => true

    stub_a.should have_been_requested
    stub_b.should have_been_requested
  end

  it "should delete a repository" do
    stub_a = stub_request(:delete, "https://api.github.com/repos/repo/").
      with(:headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => {:status => 'deleted' }.to_json, :headers => {})
    stub_a = stub_request(:delete, "https://api.github.com/repos/repo/?delete_token%5Bstatus%5D=deleted").
      with(:headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => {:status => 'deleted' }.to_json, :headers => {})

    github.delete "repo"

    stub_a.should have_been_requested
  end

  it "should list all repos" do
    stub_a = stub_request(:get, "https://api.github.com/users/vim-scripts/repos?page=1").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => [{ :name => "one" }].to_json, :headers => {})
    stub_b = stub_request(:get, "https://api.github.com/users/vim-scripts/repos?page=2").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => [{ :name => "two" }].to_json, :headers => {})
    stub_c = stub_request(:get, "https://api.github.com/users/vim-scripts/repos?page=3").
      with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => [].to_json, :headers => {})

    result = github.list_all_repos
    result.sort { |a,b| a['name'] <=> b['name'] }.should == [ { 'name' => 'one' }, { 'name' => 'two' } ]

    stub_a.should have_been_requested
    stub_b.should have_been_requested
    stub_c.should have_been_requested
  end

  it "should hold off before hitting github limit" do
    fakehub = GitHub.new :client => FakeClient.new, :logger => lambda { |msg| }
    fakehub.should_receive(:sleep).once.with(60)
    65.times { fakehub.turn_off_features "repo" }
    fakehub.client.count.should == 65
  end
end
