# frozen_string_literal: true

module PageFeedback
  # Host-controlled callbacks and presentation settings for the engine.
  class Configuration
    DEFAULT_CATEGORIES = {
      "bug" => "Bug",
      "idea" => "Idea",
      "question" => "Question",
      "compliment" => "Compliment"
    }.freeze
    DEFAULT_CURRENT_ACTOR = ->(_controller) {}.freeze
    DEFAULT_AUTHORIZER = ->(_controller) { true }.freeze
    DEFAULT_ACTOR_LABEL = lambda do |actor|
      actor.respond_to?(:email) ? actor.email : actor.to_s
    end.freeze
    DEFAULT_SOURCE_LOCATOR = ->(_comment) {}.freeze

    # @return [Proc] receives an engine controller and returns an actor or nil
    attr_accessor :current_actor

    # @return [Proc] receives an engine controller and returns whether capture is allowed
    attr_accessor :capture_authorizer

    # @return [Proc] receives an engine controller and returns whether review is allowed
    attr_accessor :review_authorizer

    # @return [Proc] receives an actor and returns its display label
    attr_accessor :actor_label

    # @return [Hash<String, String>] stored category keys mapped to display labels
    attr_accessor :categories

    # @return [String] the category key assigned when the client omits one
    attr_accessor :default_category

    # @return [Hash<Symbol, Object>] modifier and key settings for capture activation
    attr_accessor :activation_shortcut

    # @return [Array<String>] runtime CSS classes omitted from generated selectors
    attr_accessor :ignored_css_classes

    # @return [Proc] receives a comment and returns a source path or nil
    attr_accessor :source_locator

    # @return [#call] formatter called with comments and generated_at keyword arguments
    attr_accessor :export_formatter

    def initialize
      assign_callback_defaults
      assign_presentation_defaults
      @export_formatter = PageFeedback::Exporters::Markdown
    end

    private

    def assign_callback_defaults
      @current_actor = DEFAULT_CURRENT_ACTOR
      @capture_authorizer = DEFAULT_AUTHORIZER
      @review_authorizer = DEFAULT_AUTHORIZER
      @actor_label = DEFAULT_ACTOR_LABEL
      @source_locator = DEFAULT_SOURCE_LOCATOR
    end

    def assign_presentation_defaults
      @categories = DEFAULT_CATEGORIES.dup
      @default_category = "idea"
      @activation_shortcut = { alt: true, key: "f" }
      @ignored_css_classes = []
    end
  end
end
