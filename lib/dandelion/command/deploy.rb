module Dandelion
  module Command
    class Deploy < Command::Base
      command 'deploy'

      class << self
        def parser(options)
          OptionParser.new do |opts|
            opts.banner = 'Usage: deploy [options] [<revision>]'

            options[:force] = false
            opts.on('-f', '--force', 'Force deployment') do
              options[:force] = true
            end

            options[:dry] = false
            opts.on('--dry-run', 'Show what would have been deployed') do
              options[:dry] = true
            end

            options[:full] = false
            opts.on('--full', 'Issue a full deployment') do
              options[:full] = true
            end
          end
        end
      end

      def setup(args)
        @revision = args.shift || 'HEAD'
      end

      def execute
        begin
          original_branch = @repo.git.native(:rev_parse, {:abbrev_ref => true}, 'HEAD').to_s
          @deployment = deployment(@revision)
        rescue Git::RevisionError
          log.fatal("Invalid revision: #{@revision}")
          exit 1
        end

        log.info("Remote revision:        #{@deployment.remote_revision || '---'}")
        log.info("Deployment Branch:      #{@deployment.target_branch}")
        log.info("Deploying revision:     #{@deployment.local_revision}")

        begin
          @deployment.validate
        rescue Deployment::FastForwardError
          if !@options[:force]
            log.warn('Warning: you are trying to deploy unpushed commits')
            log.warn('This could potentially prevent others from being able to deploy')
            log.warn('If you are sure you want to do this, use the -f option to force deployment')
            exit 1
          end
        end

        @deployment.deploy
        @deployment.checkout("#{original_branch}")
        log.info("Deployment complete")

      end
    end
  end
end
