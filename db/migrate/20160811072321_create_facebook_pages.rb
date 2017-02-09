class CreateFacebookPages < ActiveRecord::Migration[5.0]   
  def change
    create_table(:facebook_pages, {:id => false, :primary_key => :facebook_page_id}) do |t|
      t.string        :facebook_page_id

      t.timestamps
    end   
  end   
end
