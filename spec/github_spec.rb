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


  it "should turn off issues and wikis" do
      # For some reason these don't work:
        # :body => { :data => { :values => {:has_issues => false, :has_wiki => false}}},
        # :body => { :data => { "values[has_issues]" => false, "values[has_wiki]" => false}},
    stub = stub_request(:post, "https://loggyin%2Ftoken:tokkyen@github.com/api/v2/json/repos/show/vim-scripts/repo").
      with(:body => "values[has_issues]=false&values[has_wiki]=false").to_return(:body => {}.to_json)
    github.turn_off_features "repo"
    stub.should have_been_requested
  end

  it "should delete repos" do
    stub_a = stub_request(:post, "https://loggyin%2Ftoken:tokkyen@github.com/api/v2/json/repos/delete/repo").
         with(:headers => {'Content-Length'=>'0'}).to_return(:body => {}.to_json)

    stub_b = stub_request(:post, "https://loggyin%2Ftoken:tokkyen@github.com/api/v2/json/repos/delete/repo").
         with(:headers => {'Content-Type'=>'application/x-www-form-urlencoded'}).to_return(:body => { :status => :deleted }.to_json)

    github.delete "repo"

    stub_a.should have_been_requested
    stub_b.should have_been_requested
  end

  it "should hold off before hitting github limit" do
    fakehub = GitHub.new :client => FakeClient.new, :logger => lambda { |msg| }
    fakehub.should_receive(:sleep).once.with(60)
    65.times { fakehub.turn_off_features "repo" }
    fakehub.client.count.should == 65
  end
end

