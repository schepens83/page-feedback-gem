# frozen_string_literal: true

module PageFeedback
  # Vendor-neutral representations of approved feedback revisions.
  module Exporters
    # Deterministic, safely fenced Markdown for coding-agent handoff.
    class Markdown
      # Category ordering used for groups and comments.
      CATEGORY_PRIORITY = %w[bug question idea compliment].freeze

      # Render feedback as UTF-8 Markdown.
      #
      # @param comments [Enumerable<PageFeedback::Comment>] approved revisions
      # @param generated_at [Time] snapshot timestamp
      # @return [String] a UTF-8 Markdown document
      def self.call(comments:, generated_at:)
        new(comments:, generated_at:).render
      end

      # @param comments [Enumerable<PageFeedback::Comment>]
      # @param generated_at [Time]
      def initialize(comments:, generated_at:)
        @comments = comments.to_a
        @generated_at = generated_at
      end

      # Render the complete grouped snapshot.
      #
      # @return [String]
      def render
        lines = ["# Feedback Export", "", "Generated: #{generated_label}", ""]
        grouped_pages.each { |page_path, comments| render_page(lines, page_path, comments) }
        lines.join("\n").strip.concat("\n").encode(Encoding::UTF_8)
      end

      private

      def grouped_pages
        @comments.group_by(&:page_path).sort.to_h
      end

      def render_page(lines, page_path, comments)
        lines.push("## #{markdown_text(page_path)}", "")
        source = comments.filter_map(&:source_location).first
        lines.push("Source: #{inline_code(source)}", "") if source
        selector_groups(comments).each { |selector, group| render_group(lines, selector, group) }
      end

      def selector_groups(comments)
        comments.group_by { |comment| comment.css_selector.presence }.sort_by do |selector, group|
          [selector ? 1 : 0, group.map { |comment| category_rank(comment) }.min, selector.to_s]
        end
      end

      def render_group(lines, selector, comments)
        lines.push(group_heading(selector, comments), "")
        sorted_comments(comments).each { |comment| render_comment(lines, comment) }
        render_html(lines, comments.first.element_html.presence)
      end

      def group_heading(selector, comments)
        heading = selector ? inline_code(selector) : "Page-level"
        categories = CATEGORY_PRIORITY.select { |category| comments.any? { |comment| comment.category == category } }
        badges = categories.map { |category| "[#{category}]" }.join(" ")
        "### #{heading} — #{badges}"
      end

      def sorted_comments(comments)
        comments.sort_by { |comment| [category_rank(comment), comment.id] }
      end

      def render_comment(lines, comment)
        lines << "- [#{comment.category}] #{markdown_text(comment.effective_text)}"
        lines << "  - Reviewer note: #{markdown_text(comment.reviewer_notes)}" if comment.reviewer_notes.present?
      end

      def render_html(lines, html)
        lines << ""
        return unless html

        fence = code_fence(html)
        lines.push("**Current HTML:**", "", "#{fence}html", html, fence, "")
      end

      def markdown_text(value)
        value.to_s.gsub(/\s+/, " ").strip.gsub(/([\\`*_{}\[\]()#+.!>|-])/) { |character| "\\#{character}" }
      end

      def inline_code(value)
        longest_run = value.to_s.scan(/`+/).map(&:length).max.to_i
        fence = "`" * [1, longest_run + 1].max
        "#{fence}#{value}#{fence}"
      end

      def code_fence(value)
        longest_run = value.to_s.scan(/`+/).map(&:length).max.to_i
        "`" * [3, longest_run + 1].max
      end

      def category_rank(comment)
        CATEGORY_PRIORITY.index(comment.category) || CATEGORY_PRIORITY.length
      end

      def generated_label
        @generated_at.strftime("%Y-%m-%d %H:%M %Z")
      end
    end
  end
end
