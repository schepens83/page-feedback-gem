# frozen_string_literal: true

require "json"

module PageFeedback
  # Normalizes untrusted browser-supplied capture context into safe, bounded values.
  module CommentContextNormalization
    extend ActiveSupport::Concern

    private

    def normalize_context(raw_context)
      context = context_hash(raw_context)
      normalized_scalar_context(context).merge(normalized_collection_context(context))
    end

    def normalized_scalar_context(context)
      {
        "parent_html" => context_value(context, "parent_html", "parentHTML"),
        "viewport" => context["viewport"],
        "scroll_y" => normalized_integer(context_value(context, "scroll_y", "scrollY")),
        "pointer_type" => normalized_pointer_type(context),
        "device_pixel_ratio" => normalized_device_pixel_ratio(context),
        "orientation" => normalized_orientation(context)
      }
    end

    def normalized_pointer_type(context)
      value = context_value(context, "pointer_type", "pointerType")
      value if %w[mouse touch pen].include?(value)
    end

    def normalized_device_pixel_ratio(context)
      value = Float(context_value(context, "device_pixel_ratio", "devicePixelRatio"), exception: false)
      return unless value&.positive? && value <= 100

      value.round(2)
    end

    def normalized_orientation(context)
      value = context["orientation"]
      value if %w[portrait landscape].include?(value)
    end

    def normalized_collection_context(context)
      {
        "console_errors" => normalize_context_collection(
          context_value(context, "console_errors", "consoleErrors"),
          content_key: "message"
        ),
        "navigation_history" => normalize_context_collection(
          context_value(context, "navigation_history", "navigationHistory"),
          content_key: "url"
        )
      }
    end

    def context_hash(raw_context)
      value = raw_context.is_a?(String) ? JSON.parse(raw_context) : raw_context
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)
      value.is_a?(Hash) ? value.stringify_keys : {}
    rescue JSON::ParserError, TypeError
      {}
    end

    def context_value(context, snake_case_key, camel_case_key)
      context.key?(snake_case_key) ? context[snake_case_key] : context[camel_case_key]
    end

    def normalize_context_collection(value, content_key:)
      collection = value.is_a?(String) ? JSON.parse(value) : value
      return [] unless collection.is_a?(Array)

      collection.filter_map { |entry| normalized_context_entry(entry, content_key:) }
    rescue JSON::ParserError, TypeError
      []
    end

    def normalized_context_entry(entry, content_key:)
      entry = entry.to_unsafe_h if entry.respond_to?(:to_unsafe_h)
      return unless entry.is_a?(Hash)

      attributes = entry.stringify_keys
      timestamp = context_value(attributes, "timestamp_ms", "timestampMs")
      attributes.slice(content_key).merge("timestamp_ms" => normalized_integer(timestamp))
    end

    def normalized_integer(value)
      Integer(value, exception: false)
    end
  end
end
