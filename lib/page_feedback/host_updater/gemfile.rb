# frozen_string_literal: true

module PageFeedback
  class HostUpdater
    # Parses a host Gemfile for the page_feedback declaration and its tag
    # option. Pure text work so the updater class only orchestrates.
    # @api private
    class Gemfile
      DECLARATION = /\Agem\s+["']page_feedback["']/
      TAG_OPTION = /(tag:\s*)(:?)(["']?)(v[0-9]+\.[0-9]+\.[0-9]+)(["']?)/

      # Locate the page_feedback declaration and its tag option.
      # @param path [String] the host Gemfile path
      # @return [Array(Array<String>, Hash), Symbol] the file lines plus the
      #   matched tag (groups `:prefix`, `:colon`, `:quote`, `:value`,
      #   `:line_index`), or one of `:no_declaration`, `:ref_pin`,
      #   `:branch_pin`, `:no_tag`
      def self.analyze(path)
        new(File.read(path)).analyze
      end

      def initialize(text)
        @lines = text.lines
      end

      # @return (see .analyze)
      def analyze
        index = @lines.index { |line| line =~ DECLARATION }
        return :no_declaration unless index

        statement = statement_lines(index)
        tag = locate_tag(statement, index)
        return pin_symbol(statement) unless tag

        [@lines, tag]
      end

      private

      # Collect the continuation lines of a multi-line gem declaration.
      # @param index [Integer] the declaration line
      # @return [Array<String>] lines up to and including the last comma-less line
      def statement_lines(index)
        statement = []
        @lines[index..].each do |line|
          statement << line
          break unless line.chomp.end_with?(",")
        end
        statement
      end

      # @return [Hash, nil] the tag match with its absolute line index
      def locate_tag(statement, index)
        statement.each_with_index do |line, offset|
          match = line.match(TAG_OPTION)
          next unless match

          return { prefix: match[1], colon: match[2], quote: match[3], value: match[4], line_index: index + offset }
        end
        nil
      end

      # @return [Symbol] why a tag-less declaration cannot be auto-updated
      def pin_symbol(statement)
        return :ref_pin if statement.join.include?("ref:")
        return :branch_pin if statement.join.include?("branch:")

        :no_tag
      end
    end
  end
end
