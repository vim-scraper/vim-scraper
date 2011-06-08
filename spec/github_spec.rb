require File.dirname(File.absolute_path(__FILE__)) + '/../lib/github'

require 'webmock/rspec'
include WebMock::API


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
    "https://loggyin%2Ftoken:tokkyen@github.com/api/v2/json"
  end

  def should_raise e
    lambda { yield }.should raise_error e
  end


  it "should get repo info" do
    stub = stub_request(:get, "#{base}/repos/show/vim-scripts/repo").
      to_return(:body => {}.to_json)
    github.info "repo"
    stub.should have_been_requested
  end

  it "should get repo info for a nonexistent repo" do
    stub = stub_request(:get, "#{base}/repos/show/vim-scripts/repo").
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
    stub = stub_request(:post, "#{base}/repos/show/vim-scripts/repo").
      with(:body => "values[has_issues]=false&values[has_wiki]=false").to_return(:body => {}.to_json)
    github.turn_off_features "repo"
    stub.should have_been_requested
  end

  it "should create a repository" do
    stub_a = stub_request(:post, "#{base}/repos/create").
      with(:body => "description=description&homepage=http%3A%2F%2Fhomepage&public=true&name=repo").
      to_return(:body => {:repository => {}}.to_json)
    stub_b = stub_request(:post, "#{base}/repos/show/vim-scripts/repo").
      with(:body => "values[has_issues]=false&values[has_wiki]=false").to_return(:body => {}.to_json)

    github.create "repo",
      :description => "description",
      :homepage => "http://homepage",
      :public => true

    stub_a.should have_been_requested
    stub_b.should have_been_requested
  end

  it "should delete a repository" do
    stub_a = stub_request(:post, "#{base}/repos/delete/repo").
         with(:headers => {'Content-Length'=>'0'}).to_return(:body => {}.to_json)
    stub_b = stub_request(:post, "#{base}/repos/delete/repo").
         with(:headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:body => { :status => :deleted }.to_json)

    github.delete "repo"

    stub_a.should have_been_requested
    stub_b.should have_been_requested
  end

  it "should list all repos" do
    stub_a = stub_request(:get, "#{base}/repos/show/vim-scripts?page=1").
      to_return(:body => {:repositories => [{ :name => "one" }]}.to_json )
    stub_b = stub_request(:get, "#{base}/repos/show/vim-scripts?page=2").
      to_return(:body => {:repositories => [{ :name => "two" }]}.to_json )
    stub_c = stub_request(:get, "#{base}/repos/show/vim-scripts?page=3").
      to_return(:body => {:repositories => []}.to_json )

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

