# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PageFeedback database schema" do
  subject(:connection) { ActiveRecord::Base.connection }

  it "creates the three engine tables" do
    expect(connection).to be_table_exists(:page_feedback_comments)
    expect(connection).to be_table_exists(:page_feedback_exports)
    expect(connection).to be_table_exists(:page_feedback_export_items)
  end

  it "uses portable JSON for captured context" do
    context_column = connection.columns(:page_feedback_comments).find do |column|
      column.name == "context"
    end

    expect(context_column.type).to eq(:json)
    expect(context_column.default).to eq("{}")
    expect(context_column.null).to be(false)
  end

  it "enforces unique export membership in the database" do
    unique_index = connection.indexes(:page_feedback_export_items).find do |index|
      index.columns == %w[export_id comment_id]
    end

    expect(unique_index.unique).to be(true)
  end
end
