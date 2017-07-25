class CreateFacebookComments < ActiveRecord::Migration[5.0]   
  def change
    create_table(:facebook_comments, {:id => false, :primary_key => :facebook_comment_id}) do |t|
      t.string        :facebook_comment_id
      t.string        :facebook_status_id, index: true
      t.string        :parent_id, index: true
      t.text          :comment_message
      t.string        :comment_author
      t.datetime      :comment_published_at
      t.integer       :comment_likes
      t.string        :offensive_words
      t.string        :comment_message_without_stopwords
      t.integer        :offensive_class

      t.timestamps
    end
  end   
end
