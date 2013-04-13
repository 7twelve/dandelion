require 'grit'

module Dandelion
  module Git
    class DiffError < StandardError; end
    class RevisionError < StandardError; end

    class Repo < Grit::Repo
      def initialize(dir)
        super(dir)
      end
    end

    class Diff
      attr_reader :from_revision, :to_revision

      @files = nil

      def initialize(repo, from_revision, to_revision)
        @repo = repo
        @from_revision = from_revision
        @to_revision = to_revision
        begin
          @files = parse(diff)
        rescue Grit::Git::CommandFailed
          raise DiffError
        end
      end

      def changed
        @files.to_a.select { |f| ['A', 'C', 'M'].include?(f.last) }.map { |f| f.first }
      end

      def deleted
        @files.to_a.select { |f| 'D' == f.last }.map { |f| f.first }
      end

      private

      def diff
        @repo.git.native(:diff, {:name_status => true, :raise => true}, from_revision, to_revision)
      end

      def parse(diff)
        files = {}
        diff.split("\n").each do |line|
          status, file = line.split("\t")
          files[file] = status
        end
        files
      end
    end

    class Tree
      def initialize(repo, options = {})
        @repo = repo
        @options = options

        @commit = @repo.commit(@options[:revision])
        raise RevisionError if @commit.nil?
        @tree = @commit.tree
      end

      def files
        if @options[:use_gitignore] == true
          treeish = @options[:local_path].nil? ? revision : "#{revision}:#{@options[:local_path]}"
          @repo.git.native(:ls_tree, {:name_only => true, :r => true}, treeish).split("\n")
        else
          Dir.chdir @options[:local_path] unless @options[:local_path].nil?
          @repo.git.native(:ls_files, {:base => false, :o => true, :c => true}).split("\n")
        end
      end

      def show(file)
        file
      end

      def revision
        @commit.sha
      end

      def log
        Dandelion.logger
      end

    end
  end
end
