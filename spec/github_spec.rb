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

  it "should turn off issues and wikis" do
      # For some reason these don't work:
        # :body => { :data => { :values => {:has_issues => false, :has_wiki => false}}},
        # :body => { :data => { "values[has_issues]" => false, "values[has_wiki]" => false}},
    stub_request(:post, "https://loggyin%2Ftoken:tokkyen@github.com/api/v2/json/repos/show/vim-scripts/repo").
      with(:body => "values[has_issues]=false&values[has_wiki]=false").to_return(:body => {}.to_json)

    @github = GitHub.new :client => Octokit::Client.new(:login => "loggyin", :token => "tokkyen"), :logger => lambda { |msg| }
    @github.turn_off_features "repo"

    WebMock.should have_requested(:post, "https://loggyin%2Ftoken:tokkyen@github.com/api/v2/json/repos/show/vim-scripts/repo").
      with(:body => "values[has_issues]=false&values[has_wiki]=false")
  end

  it "should hold off before hitting github limit" do
    @github = GitHub.new :client => FakeClient.new, :logger => lambda { |msg| }
    @github.should_receive(:sleep).once.with(60)
    65.times { @github.turn_off_features "repo" }
    @github.client.count.should == 65
  end
end

