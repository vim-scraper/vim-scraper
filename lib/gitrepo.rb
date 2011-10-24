# interface for working on git repos, insulates app from underlying implementation

# todo: only call git via array so no shell interp issues
# todo: make a way for caller to tell Repo to indent all messages

class GitRepo
    include Retryable   # only for network operations

    class GitError < RuntimeError; end

    # required: :root, the directory to contain the repo
    # optional: :clone a repo to clone (:bare => true if it should be bare)
    def initialize opts
        @root = opts[:root]

        if opts[:clone]
            retryable(:task => "cloning #{opts[:clone]}") do
                # todo: add support for :bare
                output = `git clone #{opts[:clone]} #{opts[:root]} 2>&1`
                raise GitError.new("git clone failed: #{output}") unless $?.success?
            end
        else
            raise "#{@root} doesn't exist" unless test ?d, @root
        end
    end

    # i.e. remote_add 'rails', 'http://github.com/rails/rails.git'
    def remote_add name, remote
        Dir.chdir(@root) {
            output = `git remote add #{name} #{remote} 2>&1`
            raise GitError.new("generate_docs: git remote add #{name} failed: #{output}") unless $?.success?
        }
    end

    # todo: get rid of this call, should be regular git add / git commit
    def commit_all message
        Dir.chdir(@root) {
            output = `git commit -a -m '#{message}' 2>&1`
            if output =~ /nothing to commit/
                puts "  no changes to generated files"
            else
                raise GitError.new("generate_docs: git commit failed: #{output}") unless $?.success?
            end
        }
    end

    def pull *args
        Dir.chdir(@root) do
            retryable(:task => "pulling #{args.join ' '}") do
                # Can we tell the difference between a network error, which we want to retry,
                # and a merge error, which we want to fail immediately?
                output = `git pull --no-rebase #{args.join ' '} 2>&1`
                raise GitError.new("generate_docs: git pull failed: #{output}") unless $?.success?
            end
        end
    end

    def push *args
        Dir.chdir(@root) do
            retryable(:task => "pushing #{args.join ' '}") do
                output = `git push #{args.join ' '} 2>&1`
                raise "generate_docs: git push failed: #{output}" unless $?.success?
            end
        end
    end
end
