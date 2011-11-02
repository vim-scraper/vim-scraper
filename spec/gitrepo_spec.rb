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

  # creates a git repo with one commit ugit can get psychotic when a repo has 0 commits)
  def with_git_commit *args
    with_git_repo(*args) do |repo|
      author = { :name => "test author", :email => "testemail@example.com" }
      repo.commit("initial commit", author) do |commit|
        commit.add "README", "This is a test readme file\n"
      end
      yield repo
    end
  end


  it "should create a regular repo" do
    Dir.mktmpdir 'gitrepo-test-' do |dir|
      GitRepo.new :root => dir, :create => true
      raise "no .git" unless test ?d, File.join(dir, '.git')
      raise "no .git/objects" unless test ?d, File.join(dir, '.git', 'objects')
      GitRepo.new :root => dir
    end
  end

  it "should create a bare repo" do
    Dir.mktmpdir 'gitrepo-test-' do |dir|
      GitRepo.new :root => dir, :bare => true, :create => true
      raise "no objects" unless test ?d, File.join(dir, 'objects')
      GitRepo.new :root => dir, :bare => true
    end
  end

  it "should error out if no repo" do
    lambda {
      GitRepo.new :root => '/usr/haha'
    }.should raise_error(GitRepo::GitError, /does not exist/)
  end

  it "should refuse to open a bare repo as regular" do
    with_git_repo(:bare => true) do |repo|
      lambda {
        GitRepo.new :root => repo.root
      }.should raise_error(GitRepo::GitError, /does not exist/)
    end
  end

  it "should refuse to open a regular repo as bare" do
    with_git_repo do |repo|
      lambda {
        GitRepo.new :root => repo.root, :bare => true
      }.should raise_error(GitRepo::GitError, /does not appear to be a bare repo/)
    end
  end

  it "should clone a regular repo" do
    Dir.mktmpdir 'gitrepo-test-' do |dir|
      root = "#{dir}/thedir"
      GitRepo.any_instance.should_receive(:git_exec).once.with(:clone, 'feta', root).and_return { |a,b,c,d|
        Dir.mkdir root     # need to make it look like git ran the clone, otherwise sanity checks fail
        Dir.mkdir File.join(root, '.git')
        Dir.mkdir File.join(root, '.git', 'objects')
      }
      GitRepo.new :root => root, :clone => 'feta', :retryable_options => { :logger => lambda { |task,retries,error| } }
    end
  end

  it "should clone a bare repo" do
    Dir.mktmpdir 'gitrepo-test-' do |dir|
      root = "#{dir}/thedir"
      GitRepo.any_instance.should_receive(:git_exec).once.with(:clone, 'feta', root, '--bare').and_return { |a,b,c,d|
        Dir.mkdir root     # need to make it look like git ran the clone, otherwise sanity checks fail
        Dir.mkdir File.join(root, 'objects')
      }
      GitRepo.new :root => root, :clone => 'feta', :bare => true, :retryable_options => { :logger => lambda { |task,retries,error| } }
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
    # sentinels to ensure we don't modify the environment
    ENV['GIT_COMMITTER_NAME'] = "abc"
    ENV['GIT_COMMITTER_EMAIL'] = "def"
    ENV['GIT_COMMITTER_DATE'] = "ghi"

    with_git_commit(:bare => true) do |repo|
      date = Time.new 2010,10,10, 16,40,0, '-07:00'
      committer = { :name => "test committer", :email => "testemail@example.com", :date => date }
      repo.create_tag '1.2', 'tag 1.2', committer
      # wish there was a better way of checking this but git show doesn't support --format for tags.
      repo.git(:show, '1.2').should match /^tag 1.2\nTagger: test committer <testemail@example.com>\nDate:\s*Sun Oct 10 16:40:00 2010 -0700\n\ntag 1.2\n/
    end

    ENV['GIT_COMMITTER_NAME'].should == "abc"
    ENV['GIT_COMMITTER_EMAIL'].should == "def"
    ENV['GIT_COMMITTER_DATE'].should == "ghi"

    ENV.delete 'GIT_COMMITTER_NAME'
    ENV.delete 'GIT_COMMITTER_EMAIL'
    ENV.delete 'GIT_COMMITTER_DATE'
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


  it "should commit with correct dates" do
    with_git_repo(:bare => true) do |repo|
      authordate =    Time.new 2010, 9, 5, 15,30,0, '-07:00'
      committerdate = Time.new 2010,10,10, 16,40,0, '-07:00'
      author =    { :name => "the author",    :email => "auemail@example.com",  :date => authordate }
      committer = { :name => "the committer", :email => "comemail@example.com", :date => committerdate }
      repo.commit("date commit", author, committer) do |commit|
        commit.add "README", "This is a test readme file\n"
      end

      # This ensures the time is represented as -0700, not -700.  http://vim-scripts.org/news/2011/06/23/picky-about-timezones.html
      repo.git(:log, '--pretty=raw').should match /^commit [0-9a-f]+\ntree [0-9a-f]+\nauthor the author <auemail@example.com> 1283725800 -0700\ncommitter the committer <comemail@example.com> 1286754000 -0700\n\n\s*date commit/
    end
  end

  it "should replace files" do
    with_git_commit(:bare => true) do |repo|
      author = { :name => "replace author", :email => "auemail@example.com" }
      repo.commit("replace commit", author) do |commit|
        commit.entries.should == ['README']
        commit.remove('README').should == "This is a test readme file\n"
        commit.add 'zarg one', 'some content for zarg\n'
        commit.entries.should == ['zarg one']
      end
      repo.git('log', '--pretty=oneline').split("\n").length.should == 2   # 2 commits
      repo.git('ls-tree', 'HEAD').should match /^[^\n]+zarg one$/          # only one file
    end
  end

  def git_tree repo, spec
    # returns an array of all entries in the tree in the format ["blob r", "tree s"]
    repo.git('ls-tree', spec).split("\n").map { |s| s =~ /^[0-9]+ (\S+) [0-9a-f]+\t(.*)$/; "#{$1} #{$2}" }.sort
  end

  it "should handle trees" do
    with_git_commit(:bare => true) do |repo|
      author = { :name => "tree author", :email => "auemail@example.com" }
      repo.commit("tree commit", author) do |commit|
        commit.add 'a/b/c dir/d/e.txt', "e text file contents\n"
        commit.add 'a/b/c dir/d/f.txt', "f text file contents\n"
        commit.entries.sort.should == ['README', 'a']
        # exercise the entry function
        commit.entry('a', :tree).should == ['b']
        commit.entry('a/b/c dir/d').sort.should == ['e.txt', 'f.txt']
        commit.entry('a/b/c dir/d/e.txt', :blob).should == "e text file contents\n"
        lambda {
          commit.entry('a', :blob)
        }.should raise_error(GitRepo::GitError, /type was tree not blob/)
        lambda {
          commit.entry('a/b/c dir/d/e.txt', :tree)
        }.should raise_error(GitRepo::GitError, /type was blob not tree/)
      end
      repo.git('log', '--pretty=oneline').split("\n").length.should == 2
      git_tree(repo, 'HEAD').should == ['blob README', 'tree a']
      git_tree(repo, 'HEAD:a/b/c dir/d').should == ['blob e.txt', 'blob f.txt']
    end
  end

  it "should not commit null blob contents" do
    with_git_commit(:bare => true) do |repo|
      author = { :name => "tree author", :email => "auemail@example.com" }
      repo.commit("tree commit", author) do |commit|
        lambda {
          commit.add "nilbog", nil
        }.should raise_error(GitRepo::GitError, /no data in nilbog: nil/)
      end
      # ensure we didn't create another commit
      repo.git('log', '--pretty=oneline').split("\n").length.should == 1
    end
  end

  it "should create empty commits" do
    with_git_commit(:bare => true) do |repo|
      author = { :name => "an author", :email => "auemail@example.com" }
      repo.commit("empty commit", author) do |commit|
        commit.empty_index
        commit.entries.empty?.should == true
      end
      repo.git('ls-tree', 'HEAD').should == ''
    end
  end

  it "should not create nop commits" do
    # dunno why not but it's the current behavior
    with_git_commit(:bare => true) do |repo|
      author = { :name => "nop author", :email => "nop@example.com" }
      repo.commit("nop commit", author) { |commit| 'do nothing' }
      repo.git(:log, '--pretty=raw').should match /^commit [0-9a-f]+\ntree [0-9a-f]+\nauthor test author <testemail@example.com>/
      repo.git('ls-tree', 'HEAD').should match /^[^\n]+README$/
    end
  end

  it "should return the original object when deleting" do
    with_git_commit(:bare => true) do |repo|
      author = { :name => "delete author", :email => "del@example.com" }
      repo.commit("delete commit", author) do |commit|
        del = commit.remove "README"
        del.should == "This is a test readme file\n"
      end
      repo.git('ls-tree', 'HEAD').should == ""
    end
  end
end
