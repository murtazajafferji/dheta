class Segment < ActiveRecord::Base
    belongs_to :segmentable, polymorphic: true
end