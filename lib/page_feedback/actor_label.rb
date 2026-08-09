# frozen_string_literal: true

module PageFeedback
  # Resolves a display label for a host actor.
  #
  # Hosts name their display attribute differently, and some have none at all,
  # so this walks conventional names first and falls back to model identity.
  # It never returns Ruby's inherited +to_s+, because that leaks an object's
  # memory address into the review UI instead of naming a person.
  module ActorLabel
    # Reader names checked in order; the first non-empty String wins.
    DISPLAY_ATTRIBUTES = %i[
      to_page_feedback_label
      display_name
      full_name
      name
      username
      nickname
      email
    ].freeze

    # Owners of a +to_s+ that describes memory rather than the object itself.
    GENERIC_TO_S_OWNERS = [BasicObject, Kernel, Object, Struct].freeze

    # Last resort for an actor whose class cannot even be named.
    UNKNOWN_LABEL = "Unknown"

    class << self
      # Label an actor for display.
      #
      # @param actor [Object, nil] the object returned by the host's current_actor
      # @return [String, nil] nil only when the actor is nil
      def call(actor)
        return if actor.nil?

        from_display_attribute(actor) ||
          from_own_to_s(actor) ||
          from_model_identity(actor) ||
          actor.class.name ||
          UNKNOWN_LABEL
      end

      private

      def from_display_attribute(actor)
        DISPLAY_ATTRIBUTES.each do |attribute|
          next unless actor.respond_to?(attribute)

          value = actor.public_send(attribute)
          return value if value.is_a?(String) && !value.strip.empty?
        end

        nil
      end

      # A class that writes its own to_s is describing itself, so trust it.
      # Scalars such as Integer land here; Active Record objects never do.
      def from_own_to_s(actor)
        return if GENERIC_TO_S_OWNERS.include?(actor.method(:to_s).owner)

        value = actor.to_s
        value unless value.strip.empty?
      end

      # "User #3" identifies the actor without exposing object internals, and
      # follows the host's own model translations.
      def from_model_identity(actor)
        return unless actor.class.respond_to?(:model_name)

        model = actor.class.model_name.human
        identifier = actor.id if actor.respond_to?(:id)
        identifier.nil? ? model : "#{model} ##{identifier}"
      end
    end
  end
end
