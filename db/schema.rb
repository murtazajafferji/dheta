# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160811072324) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "owner_id"
    t.string   "owner_type"
    t.index ["owner_id"], name: "owner_id", using: :btree
    t.index ["owner_type"], name: "owner_type", using: :btree
    t.index ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree
    t.index ["queue"], name: "delayed_jobs_queue", using: :btree
  end

  create_table "facebook_comments", id: false, force: :cascade do |t|
    t.string   "facebook_comment_id"
    t.string   "facebook_status_id"
    t.string   "parent_id"
    t.text     "comment_message"
    t.string   "comment_author"
    t.datetime "comment_published_at"
    t.integer  "comment_likes"
    t.string   "offensive_words"
    t.string   "comment_message_without_stopwords"
    t.integer  "offensive_class"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.index ["facebook_status_id"], name: "index_facebook_comments_on_facebook_status_id", using: :btree
    t.index ["parent_id"], name: "index_facebook_comments_on_parent_id", using: :btree
  end

  create_table "facebook_pages", id: false, force: :cascade do |t|
    t.string   "facebook_page_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "facebook_statuses", id: false, force: :cascade do |t|
    t.string   "facebook_status_id"
    t.string   "facebook_page_id"
    t.text     "status_message"
    t.string   "link_name"
    t.string   "status_type"
    t.string   "status_link"
    t.datetime "status_published_at"
    t.integer  "num_reactions"
    t.integer  "num_comments"
    t.integer  "num_shares"
    t.integer  "num_likes"
    t.integer  "num_loves"
    t.integer  "num_wows"
    t.integer  "num_hahas"
    t.integer  "num_sads"
    t.integer  "num_angrys"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
    t.index ["facebook_page_id"], name: "index_facebook_statuses_on_facebook_page_id", using: :btree
  end

  create_table "segments", force: :cascade do |t|
    t.string   "segmentable_id"
    t.string   "segmentable_type"
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean  "beginning_reached"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.index ["segmentable_type", "segmentable_id"], name: "index_segments_on_segmentable_type_and_segmentable_id", using: :btree
  end

end
