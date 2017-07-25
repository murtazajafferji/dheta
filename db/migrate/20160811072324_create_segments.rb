class CreateSegments < ActiveRecord::Migration[5.0]   
  def change
    create_table(:segments) do |t|
      t.string        :segmentable_id
      t.string        :segmentable_type

      t.datetime      :start_time
      t.datetime      :end_time
      t.boolean       :beginning_reached

      t.timestamps
    end

    add_index :segments, [:segmentable_type, :segmentable_id]
  end   
end
