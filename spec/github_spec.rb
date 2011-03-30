require File.dirname(File.absolute_path(__FILE__)) + '/../lib/github'

describe "GitHub" do
  before :each do
    @adapter = Faraday::Adapter::Test
    client = Octokit::Client.new :login => "<LOGIN>", :token => "<TOKEN>", :adapter => @adapter
    @github = GitHub.new :client => client
  end

  it "should turn off issues and wikis" do
    stubs = Faraday::Adapter::Test::Stubs.new do |b|
      b.post('/api/v2/json/repos/show/vim-scripts/repo',
             :values => {:has_issues => false, :has_wiki => false}
            ) {
              [200, {}, "whatev"]
            }
    end

    @github.turn_off_features "repo"
  end
end

