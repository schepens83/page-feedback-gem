# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_08_08_000004) do
  create_table "page_feedback_comments", force: :cascade do |t|
    t.datetime "approved_at"
    t.string "category", default: "idea", null: false
    t.text "comment_text", null: false
    t.json "context", default: {}, null: false
    t.string "controller_action"
    t.datetime "created_at", null: false
    t.text "css_selector"
    t.text "element_html"
    t.string "page_path", null: false
    t.string "page_title"
    t.text "refined_text"
    t.datetime "rejected_at"
    t.bigint "reviewed_by_id"
    t.string "reviewed_by_type"
    t.text "reviewer_notes"
    t.string "status", default: "pending", null: false
    t.bigint "submitter_id"
    t.string "submitter_type"
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_page_feedback_comments_on_category"
    t.index ["created_at"], name: "index_page_feedback_comments_on_created_at"
    t.index ["page_path"], name: "index_page_feedback_comments_on_page_path"
    t.index ["reviewed_by_type", "reviewed_by_id"], name: "idx_on_reviewed_by_type_reviewed_by_id_2ace12f120"
    t.index ["status"], name: "index_page_feedback_comments_on_status"
    t.index ["submitter_type", "submitter_id"], name: "idx_on_submitter_type_submitter_id_c560a7d304"
  end

  create_table "page_feedback_export_items", force: :cascade do |t|
    t.string "comment_fingerprint", null: false
    t.integer "comment_id", null: false
    t.datetime "created_at", null: false
    t.integer "export_id", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id", "comment_fingerprint"], name: "idx_on_comment_id_comment_fingerprint_f96903ad28"
    t.index ["comment_id"], name: "index_page_feedback_export_items_on_comment_id"
    t.index ["export_id", "comment_id"], name: "index_page_feedback_export_items_on_export_id_and_comment_id", unique: true
    t.index ["export_id"], name: "index_page_feedback_export_items_on_export_id"
  end

  create_table "page_feedback_exports", force: :cascade do |t|
    t.text "body", null: false
    t.string "body_digest", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "created_by_type"
    t.string "format", default: "markdown", null: false
    t.string "label"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_page_feedback_exports_on_created_at"
    t.index ["created_by_type", "created_by_id"], name: "idx_on_created_by_type_created_by_id_4eb9949f3a"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "page_feedback_export_items", "page_feedback_comments", column: "comment_id"
  add_foreign_key "page_feedback_export_items", "page_feedback_exports", column: "export_id"
end
