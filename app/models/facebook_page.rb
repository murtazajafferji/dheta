class FacebookPage < ActiveRecord::Base
  self.primary_key = 'facebook_page_id'
  has_many :facebook_statuses
  has_many :facebook_comments, :through => :facebook_statuses 
  has_many :segments, as: :segmentable, dependent: :destroy
end