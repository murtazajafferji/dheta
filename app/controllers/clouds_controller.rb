class CloudsController < ApplicationController
  def facebook
    #status = FacebookStatus.joins(:facebook_comments).group('facebook_statuses.facebook_status_id').select('facebook_status_id').first
    page = FacebookPage.first
    if page
      @text = score(page.facebook_comments.where(offensive_class: 1).collect{|x| x.comment_message_without_stopwords.downcase }.join(' ').split(' ')).to_json.html_safe
      #@text = score(page.facebook_comments.where.not(offensive_words: [nil, '']).collect{|x| x.offensive_words }.join(',').downcase.split(',')).to_json.html_safe
      #@text = score(page.facebook_comments.where.not(comment_message_without_stopwords: [nil, '']).collect{|x| x.comment_message_without_stopwords.downcase }.split(' ')).to_json.html_safe
    end
    if page
      @timeline = page.segments.map{|x| {id: x.id, content: "Segment #{x.id}", end: x.end_time, start: x.start_time}}.to_json.html_safe
    end
  end

  def score array
    hash = Hash.new(0)
    array.each{|key| hash[key] += 1}
    Hash[hash.sort_by{|k,v| v}.reverse]
  end
end
