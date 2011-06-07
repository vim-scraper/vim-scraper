require File.dirname(File.absolute_path(__FILE__)) + '/../lib/github'

describe "GitHub" do
  class FakeClient
    attr_accessor :count
    def update_repository *args
      @count ||= 0
      @count += 1
    end
  end

#  before :each do
#    @adapter = Faraday::Adapter::Test
#    client = Octokit::Client.new :login => "<LOGIN>", :token => "<TOKEN>", :adapter => @adapter
#    @github = GitHub.new :client => client
#  end
#
#  it "should turn off issues and wikis" do
#    stubs = Faraday::Adapter::Test::Stubs.new do |b|
#      b.post('/api/v2/json/repos/show/vim-scripts/repo',
#             :values => {:has_issues => false, :has_wiki => false}
#            ) {
#              [200, {}, "whatev"]
#            }
#    end
#
#    @github.turn_off_features "repo"
#  end

  it "should hold off before hitting github limit" do
    @github = GitHub.new :client => FakeClient.new, :logger => lambda { |msg| }
    @github.should_receive(:sleep).once.with(60)
    65.times { @github.turn_off_features "repo" }
    @github.client.count.should == 65
  end
end

