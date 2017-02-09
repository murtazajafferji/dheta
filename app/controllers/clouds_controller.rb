class CloudsController < ApplicationController
  def facebook
    @text = FacebookStatus.first.facebook_comments.collect{|x| x.comment_message }.join(' ')
  end
end
