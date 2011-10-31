# Ensures git operations can occur on repos.
# Avoids stubbing as much as possible so the testfile doesn't prescribe the implementation.

require File.dirname(File.absolute_path(__FILE__)) + '/../lib/gitrepo'

require 'tmpdir'


describe 'GitRepo' do
  # creates an empty Git repo.
  def with_git_repo args={}, &block
    stub = lambda { |tmpdir|
      options = { :root => "#{tmpdir}/repo", :create => true }
      options.merge! args
      block.call GitRepo.new options
    }

    if ENV['PRESERVE']
      dir = Dir.mktmpdir 'gitrepo-test-'
      stub.call dir
    else
      Dir.mktmpdir 'gitrepo-test-', &stub
    end
  end

  # creates a git repo with one commit (git can get psychotic when a repo has 0 commits)
  def with_git_commit *args
    with_git_repo(*args) do |repo|
      author = { :name => "test author", :email => "testemail@example.com" }
      repo.commit("initial commit", author) do |commit|
        commit.add "README", "This is a test readme file\n"
      end
      yield repo
    end
  end

  it "should allow remotes to be added and removed" do
    with_git_commit(:bare => true) do |repo|
      repo.remote_add :origin, 'http://example.com/'
      repo.git(:remote).should == "origin\n"
      repo.remote_remove :origin
      repo.git(:remote).should == ""
    end
  end

  it "should allow pulling" do
    with_git_repo do |repo|
      repo.should_receive(:git).once.with(:pull, '--no-rebase', :origin, :master)
      repo.pull :origin, :master
    end
  end

  it "should allow pushing" do
    with_git_repo do |repo|
      repo.should_receive(:git).once.with(:push, :origin, :master)
      repo.push :origin, :master
    end
  end
end
