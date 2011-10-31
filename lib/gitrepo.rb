# interface for working on git repos, insulates app from underlying implementation

# todo: only call git via array so no shell interp issues
# todo: make a way for caller to tell Repo to indent all messages

require 'gitrb'
require 'retryable'


class GitRepo
    include Retryable   # only for network operations

    class GitError < RuntimeError; end

    # required: :root, the directory to contain the repo
    # optional: :clone a repo to clone (:bare => true if it should be bare)
    #           :create to create a new empty repo if it doesn't already exist
    def initialize opts
        @root = opts[:root]

        if opts[:clone]
            retryable(:task => "cloning #{opts[:clone]}") do
                # todo: add support for :bare
                bare = '--bare' if opts[:bare]
                output = `git clone #{opts[:clone]} #{opts[:root]} #{bare} 2>&1`
                raise GitError.new("git clone failed: #{output}") unless $?.success?
            end
        end

        unless opts[:create]    # unless we're creating it, repo needs to exist by now
            raise "#{@root} doesn't exist" unless test ?d, @root
        end

        # gitrb has a bug where it will complain about frozen strings unless you dup the path
        @repo = Gitrb::Repository.new(:path => @root.dup, :bare => opts[:bare], :create => opts[:create])
    end

    def root
        @root
    end

    def git *args
        args = args.map { |a| a.to_s }
        Dir.chdir(@root) do
            out = IO.popen('-', 'r') do |io|
                if io
                    # parent, read the git output
                    block_given? ? yield(io) : io.read
                else
                    STDERR.reopen STDOUT
                    exec 'git', *args
                end
            end

            if $?.exitstatus > 0
                # return '' if $?.exitstatus == 1 && out == ''
                raise GitError.new("git #{args.join(' ')}: #{out}")
            end

            out
        end
    end

    def remote_add name, remote
        git :remote, :add, name, remote
    end

    def remote_remove name
        git :remote, :rm, name
    end


    # todo: get rid of this call, should be regular git add / git commit
    def commit_all message
        Dir.chdir(@root) {
            output = `git commit -a -m '#{message}' 2>&1`
            if output =~ /nothing to commit/
                puts "  no changes to generated files"
            else
                raise GitError.new("git commit failed: #{output}") unless $?.success?
            end
        }
    end


    def pull *args
        # Can we tell the difference between a network error, which we want to retry,
        # and a merge error, which we want to fail immediately?
        retryable(:task => "pulling #{args.join ' '}") do
            git :pull, '--no-rebase',  *args
        end
    end

    def push *args
        # like pull, can we tell the difference between a network error and local error?
        retryable(:task => "pushing #{args.join ' '}") do
            git :push, *args
        end
    end


    # todo: get rid of branch since we should only ever produce commits on master.
    def create_tag name, message, committer, branch='master'
        # gitrb doesn't handle annotated tags so we call git directly
        # todo: this blows away the environment, should set env after forking & before execing
        ENV['GIT_COMMITTER_NAME'] = committer[:name]
        ENV['GIT_COMMITTER_EMAIL'] = committer[:email]
        ENV['GIT_COMMITTER_DATE'] = (committer[:date] || Time.now).strftime("%s %z")

        result = git :tag, '-a', name, '-m', message, branch

        ENV.delete 'GIT_COMMITTER_NAME'
        ENV.delete 'GIT_COMMITTER_EMAIL'
        ENV.delete 'GIT_COMMITTER_DATE'

        result
    end

    def find_tag tagname
        tag = git :tag, '-l', tagname
        return !tag || tag =~ /^\s*$/ ? nil : tag.chomp
    end


    # all the things you can do while committing
    class CommitHelper
        def initialize repo
            @repo = repo
        end

        # this empties out the commit tree so you can start fresh
        def empty
            @repo.root.to_a.map { |name,value| remove name }
        end

        # to test: returns the value of the deleted object
        def remove name
            @repo.root.delete name
        end

        def add name, contents
            @repo.root[name] = Gitrb::Blob.new(:data => contents)
        end

        # todo: this returns |name,value| ????
        def entries
            @repo.root.to_a
        end
    end


    def commit message, author, committer=author
        author    = Gitrb::User.new(author[:name],    author[:email],    author[:date] || Time.now)
        committer = Gitrb::User.new(committer[:name], committer[:email], committer[:date] || Time.now)
        @repo.transaction(message, author, committer) do
            yield CommitHelper.new @repo
        end
    end
end
