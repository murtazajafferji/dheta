class Delayed::Job < ActiveRecord::Base
  belongs_to :owner, :polymorphic => true
end