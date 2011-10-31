# Ensures git operations can occur on repos.
# Avoids stubbing as much as possible so the testfile doesn't prescribe the implementation.
#
# to run specs with 'date' in the name and preserve the results: PRESERVE=1 bundle exec rspec spec/* -e date

require File.dirname(File.absolute_path(__FILE__)) + '/../lib/gitrepo'

require 'tmpdir'


describe 'GitRepo' do
  # creates an empty Git repo.
  def with_git_repo args={}, &block
    stub = lambda { |tmpdir|
      options = { :root => "#{tmpdir}/repo", :create => true }
      options.merge! args
      repo = GitRepo.new options
      repo.retryable_options :logger => lambda { |task,retries,error| }  # turn off logging when testing
      block.call repo
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


  it "should create a tag at the right date" do
    with_git_commit(:bare => true) do |repo|
      date = Time.new 2010,10,10, 16,40,0, '-07:00'
      committer = { :name => "test committer", :email => "testemail@example.com", :date => date }
      repo.create_tag '1.2', 'tag 1.2', committer
      # wish there was a better way of checking this but git show doesn't support --format for tags.
      repo.git(:show, '1.2').should match /^tag 1.2\nTagger: test committer <testemail@example.com>\nDate:\s*Sun Oct 10 16:40:00 2010 -0700\n\ntag 1.2\n/
    end
  end

  it "should not create an invalid tag" do
    with_git_commit(:bare => true) do |repo|
      committer = { :name => "test committer", :email => "testemail@example.com" }
      lambda {
        repo.create_tag '5 4.3', 'tag 5.4.3', committer
      }.should raise_error(GitRepo::GitError, /is not a valid tag name/)
    end
  end

  it "should find tags" do
    with_git_commit(:bare => true) do |repo|
      committer = { :name => "test committer", :email => "testemail@example.com" }
      repo.create_tag '5.4.3', 'tag message for 5.4.3', committer
      repo.find_tag('5.4.3').should == '5.4.3'   # find an existing tag
      repo.find_tag('5.4.4').should == nil       # find a nonexistent tag
      repo.find_tag('5 4.4').should == nil       # find an invalid tag
    end
  end


  # testing commits:
  #   committer same as author
  #   omit committer
  #   empty commit
  #   -700 in commits
end
