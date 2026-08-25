# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Engine do
  let(:stylesheet) { File.read("app/assets/stylesheets/page_feedback/page_feedback.css") }
  # Declarations only. The prose in these examples explains the constructs
  # being avoided by naming them, and must not read as the constructs
  # themselves.
  let(:declarations) { stylesheet.gsub(%r{/\*.*?\*/}m, "") }
  let(:selectors) do
    stylesheet.gsub(%r{/\*.*?\*/}m, "").scan(/([^{}]+)\{/).flatten.filter_map do |block_header|
      header = block_header.strip
      next if header.start_with?("@") || header.match?(/\A(?:from|to|\d+%)/)

      header.lines.map { |line| line.strip.delete_suffix(",") }.reject(&:empty?)
    end.flatten
  end

  it "namespaces every CSS custom property" do
    custom_properties = stylesheet.scan(/(?:var\(|^\s*)(--[a-z0-9-]+)/).flatten

    expect(custom_properties).not_to be_empty
    expect(custom_properties).to all(start_with("--page-feedback-"))
  end

  it "scopes every CSS selector to PageFeedback" do
    expect(selectors).not_to be_empty
    expect(selectors).to all(
      satisfy do |selector|
        selector == ":root" || selector.include?(".page-feedback-") || selector.include?("body.page-feedback-")
      end
    )
  end

  it "anchors floating capture chrome to host-overridable offsets" do
    expect(stylesheet).to include("--page-feedback-offset-bottom:", "--page-feedback-offset-inline:")

    %w[.page-feedback-widget__trigger .page-feedback-mode-indicator .page-feedback-toasts].each do |selector|
      block = stylesheet[/^#{Regexp.escape(selector)} \{(.+?)\}/m, 1]

      expect(block).to include("var(--page-feedback-offset-bottom)", "var(--page-feedback-offset-inline)")
    end
  end

  it "stretches the armed trigger into a mode bar on small screens" do
    small_screen_rules = stylesheet[/^@media \(max-width: 36rem\) \{(.+?)^\}/m, 1]

    expect(stylesheet).to include(".page-feedback-widget__trigger--active")
    expect(small_screen_rules).to include(".page-feedback-widget__trigger--active")
  end

  it "keeps the capture modal inside the visual viewport" do
    modal_blocks = stylesheet.scan(/^\s*\.page-feedback-modal \{(.+?)\}/m).flatten

    expect(modal_blocks.length).to be >= 2
    expect(modal_blocks).to all(include("var(--page-feedback-visual-viewport-height, 100dvh)"))
    expect(modal_blocks.last).to include("var(--page-feedback-visual-viewport-offset-bottom, 0px)")
  end

  it "sizes the capture sheet without engine-dependent layout" do
    small_screen_rules = declarations[/^@media \(max-width: 36rem\) \{(.+?)^\}/m, 1]
    sheet = small_screen_rules[/\.page-feedback-modal \{(.+?)\}/m, 1]
    surface = declarations[/^\.page-feedback-modal__surface \{(.+?)\}/m, 1]

    # An `inset: 0` dialog lifted by `margin: auto 0 <offset>` is an
    # over-constrained absolutely positioned box. Blink resolves it to the
    # content height; WebKit resolves it to zero, which collapses the sheet to
    # its top border on iPhone. Anchor the bottom edge and leave the top auto.
    expect(sheet).to include("bottom: var(--page-feedback-visual-viewport-offset-bottom, 0px)")
    expect(sheet).not_to match(/margin:\s*auto/)

    # A percentage max-height against a fit-content dialog is circular.
    expect(surface).not_to match(/max-height:\s*\d+%/)
  end

  it "leaves a closed capture sheet hidden" do
    # `dialog:not([open]) { display: none }` is a user-agent rule, and an
    # author `display` on the dialog outranks it on origin alone, whatever
    # their specificities. Stating the sheet's display only for the open state
    # keeps the closed sheet out of the page.
    dialog_rules = declarations.scan(/^\s*(\.page-feedback-modal(?:\[[^\]]+\])?) \{(.+?)^\s*\}/m)
    displaying = dialog_rules.select { |_selector, body| body.match?(/^\s*display:/) }

    expect(dialog_rules).not_to be_empty
    expect(displaying).not_to be_empty
    expect(displaying.map(&:first)).to all(include("[open]"))
  end

  it "uses an achromatic visual palette" do
    hex_colors = stylesheet.scan(/#[0-9a-f]{3,8}\b/i)
    rgb_colors = stylesheet.scan(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i)

    expect(hex_colors).to all(satisfy("be grayscale") do |color|
      channels = color.delete_prefix("#").chars
      channels = channels.first(3).flat_map { |channel| [channel, channel] } if channels.length == 3
      channels.first(6).each_slice(2).map(&:join).uniq.one?
    end)
    expect(rgb_colors).to all(satisfy("be grayscale") { |channels| channels.uniq.one? })
  end
end
