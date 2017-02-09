class CreateFacebookStatuses < ActiveRecord::Migration[5.0]   
  def change
    create_table(:facebook_statuses, {:id => false, :primary_key => :facebook_status_id}) do |t|
      t.string        :facebook_status_id
      t.string        :facebook_page_id, index: true
      t.text          :status_message
      t.string        :link_name
      t.string        :status_type
      t.string        :status_link
      t.datetime      :status_published_at
      t.integer       :num_reactions
      t.integer       :num_comments
      t.integer       :num_shares
      t.integer       :num_likes
      t.integer       :num_loves
      t.integer       :num_wows
      t.integer       :num_hahas
      t.integer       :num_sads
      t.integer       :num_angrys

      t.timestamps
    end   
  end   
end
