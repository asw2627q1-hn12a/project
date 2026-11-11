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

ActiveRecord::Schema[8.1].define(version: 2026_11_10_163000) do
  create_table "comment_favorites", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "comment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_comment_favorites_on_comment_id"
    t.index ["user_id", "comment_id"], name: "index_comment_favorites_on_user_id_and_comment_id", unique: true
    t.index ["user_id"], name: "index_comment_favorites_on_user_id"
  end

  create_table "comment_votes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "comment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_comment_votes_on_comment_id"
    t.index ["user_id", "comment_id"], name: "index_comment_votes_on_user_id_and_comment_id", unique: true
    t.index ["user_id"], name: "index_comment_votes_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.integer "submission_id", null: false
    t.integer "user_id", null: false
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.integer "points", default: 1, null: false
    t.index ["deleted_at"], name: "index_comments_on_deleted_at"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["submission_id"], name: "index_comments_on_submission_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "submission_favorites", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "submission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["submission_id"], name: "index_submission_favorites_on_submission_id"
    t.index ["user_id", "submission_id"], name: "index_submission_favorites_on_user_id_and_submission_id", unique: true
    t.index ["user_id"], name: "index_submission_favorites_on_user_id"
  end

  create_table "submission_hides", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "submission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["submission_id"], name: "index_submission_hides_on_submission_id"
    t.index ["user_id", "submission_id"], name: "index_submission_hides_on_user_id_and_submission_id", unique: true
    t.index ["user_id"], name: "index_submission_hides_on_user_id"
  end

  create_table "submission_votes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "submission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["submission_id"], name: "index_submission_votes_on_submission_id"
    t.index ["user_id", "submission_id"], name: "index_submission_votes_on_user_id_and_submission_id", unique: true
    t.index ["user_id"], name: "index_submission_votes_on_user_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.string "title", null: false
    t.string "url"
    t.integer "points", default: 1, null: false
    t.string "submission_type", default: "url", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "text"
    t.index ["user_id"], name: "index_submissions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "avatar", default: "default-avatar.png"
    t.string "banner", default: "default-banner.png"
    t.text "about"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "comment_favorites", "comments"
  add_foreign_key "comment_favorites", "users"
  add_foreign_key "comment_votes", "comments"
  add_foreign_key "comment_votes", "users"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "submissions"
  add_foreign_key "comments", "users"
  add_foreign_key "submission_favorites", "submissions"
  add_foreign_key "submission_favorites", "users"
  add_foreign_key "submission_hides", "submissions"
  add_foreign_key "submission_hides", "users"
  add_foreign_key "submission_votes", "submissions"
  add_foreign_key "submission_votes", "users"
  add_foreign_key "submissions", "users"
end
