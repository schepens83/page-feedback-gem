# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageFeedback::Pager do
  def pager(page, total: 45, per: 20)
    described_class.new(page:, total:, per:)
  end

  it "computes pages, offset and limit" do
    expect(pager("2")).to have_attributes(page: 2, pages: 3, offset: 20, limit: 20)
  end

  it "falls back to page 1 for blank, non-numeric or non-positive input" do
    [nil, "", "abc", "0", "-3", "1.5"].each { |raw| expect(pager(raw).page).to eq(1) }
  end

  it "clamps out-of-range pages to the last page" do
    expect(pager("99").page).to eq(3)
  end

  it "has one page when empty" do
    expect(pager(nil, total: 0)).to have_attributes(page: 1, pages: 1, newer_page: nil, older_page: nil)
  end

  it "points at neighbouring pages" do
    expect(pager("2")).to have_attributes(newer_page: 1, older_page: 3)
    expect(pager("1").newer_page).to be_nil
    expect(pager("3").older_page).to be_nil
  end

  it "reports whether paging is needed" do
    expect(pager(nil, total: 20)).not_to be_paged
    expect(pager(nil, total: 21)).to be_paged
  end
end
