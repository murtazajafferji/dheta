class FacebookComment < ActiveRecord::Base
  self.primary_key = 'facebook_comment_id'
  belongs_to :parent, class_name: "FacebookComment", foreign_key: :parent_id
  belongs_to :facebook_status
  belongs_to :facebook_page

  #FacebookComment.scrape_facebook_page_feed_comments('breitbart')

  def self.request_until_succeed(url)
    #req = urllib2.Request(url)
    #success = False
    #while success is False:
    #    try: 
    #        response = urllib2.urlopen(req)
    #        if response.getcode() == 200:
    #            success = True
    #    except Exception, e:
    #        print e
    #        time.sleep(5)

    #        puts "Error for URL %s: %s" % (url, DateTime.now)
    #        puts "Retrying."

    #        if '400' in str(e):
    #            return None;

    #return response.read()
    open(url).read
  end

  def self.get_facebook_comment_feed_data(status_id, num_comments)

    # Construct the URL string
    base = "https://graph.facebook.com/v2.6"
    node = "/#{status_id}/comments" 
    fields = "?fields=id,message,like_count,created_time,comments,from,attachment"
    parameters = "&order=chronological&limit=#{num_comments}&access_token=#{ENV['FACEBOOK_APP_ID'] + "|" + ENV['FACEBOOK_APP_SECRET']}"
    url = base + node + fields + parameters

    # retrieve data
    data = request_until_succeed(url)
    if !data
      return nil
    else
      return JSON.parse(data)
    end
  end

  def self.process_facebook_comment(comment, status_id, parent_id = '')

    # The status is now a Python dictionary, so for top-level items,
    # we can simply call the key.

    # Additionally, some items may not always exist,
    # so must check for existence first

    comment_id = comment['id']
    comment_message = comment['message'] || ''
    comment_author = comment['from']['name']
    comment_likes = comment['like_count'] || 0

    if comment['attachment']
      attach_tag = "[[#{comment['attachment']['type'].upcase}]]"
      comment_message = comment_message == '' ? attach_tag : (comment_message + " " + attach_tag)
    end

    # Time needs special care since a) it's in UTC and
    # b) it's not easy to use in statistical programs.

    comment_published = DateTime.strptime(
            comment['created_time'],'%Y-%m-%dT%H:%M:%S+0000')
    comment_published = comment_published - 5.hours # EST
    comment_published = comment_published.strftime(
            '%Y-%m-%d %H:%M:%S') # best time format for spreadsheet programs

    # Return a tuple of all processed data

    FacebookComment.create(facebook_comment_id: comment_id, facebook_status_id: status_id, 
                          parent_id: parent_id, comment_message: comment_message, comment_author: comment_author, 
                          comment_published_at: comment_published, comment_likes: comment_likes)
  end

  def self.scrape_facebook_page_feed_comments(page_id)
    num_processed = 0   # keep a count on how many we've processed
    scrape_starttime = DateTime.now

    puts "Scraping #{page_id} Comments From Posts: #{scrape_starttime}\n"

    statuses = FacebookStatus.where(facebook_page_id: page_id)

    statuses.each do |status|
      has_next_page = true

      comments = get_facebook_comment_feed_data(status['facebook_status_id'], 100)

      while has_next_page and comments != nil
        comments['data'].each do |comment|
          process_facebook_comment(comment, status['facebook_status_id'])

          if comment['comments']
            has_next_subpage = true

            subcomments = get_facebook_comment_feed_data(comment['id'], 100)

            while has_next_subpage
              subcomments['data'].each do |subcomment|
                # print (process_facebook_comment(
                    # subcomment, status['facebook_status_id'], 
                    # comment['id']))
                process_facebook_comment(
                        subcomment, 
                        status['facebook_status_id'], 
                        comment['id'])

                num_processed += 1
                if num_processed % 1000 == 0
                    puts "#{num_processed} Comments Processed: #{DateTime.now}"
                end
              end

              if subcomments['paging']
                if subcomments['paging']['next']
                  subcomments = JSON.parse(request_until_succeed(subcomments['paging']['next']))
                else
                  has_next_subpage = false
                end
              else
                has_next_subpage = false
              end
            end
          end

          # output progress occasionally to make sure code is not
          # stalling
          num_processed += 1
          if num_processed % 1000 == 0
            puts "#{num_processed} Comments Processed: #{DateTime.now}"
          end
        end

        if comments['paging']
          if comments['paging']['next']
            comments = JSON.parse(request_until_succeed(comments['paging']['next']))
          else
            has_next_page = false
          end
        else
          has_next_page = false
        end
      end
    end

    puts "\nDone!\n#{num_processed} Comments Processed in #{DateTime.now - scrape_starttime}"
  end
end