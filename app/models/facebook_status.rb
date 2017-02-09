class FacebookStatus < ActiveRecord::Base
  self.primary_key = 'facebook_status_id'
  has_many :facebook_comments

  #FacebookStatus.scrape_facebook_page_feed_status('breitbart')

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

    #        puts "Error for URL #{url}: #{DateTime.now}"
    #        puts "Retrying."

    #return response.read()
    open(url).read
  end

  def self.get_facebook_page_feed_data(page_id, num_statuses)

    # Construct the URL string; see http://stackoverflow.com/a/37239851 for
    # Reactions parameters
    base = "https://graph.facebook.com/v2.6"
    node = "/#{page_id}/posts" 
    fields = "/?fields=message,link,created_time,type,name,id," +
            "comments.limit(0).summary(true),shares,reactions" +
            ".limit(0).summary(true)"
    parameters = "&limit=#{num_statuses}&access_token=#{ENV['FACEBOOK_APP_ID'] + "|" + ENV['FACEBOOK_APP_SECRET']}"
    url = base + node + fields + parameters

    # retrieve data
    data = JSON.parse(request_until_succeed(url))

    return data
  end

  def self.get_reactions_for_status(status_id)

    # See http://stackoverflow.com/a/37239851 for Reactions parameters
        # Reactions are only accessable at a single-post endpoint

    base = "https://graph.facebook.com/v2.6"
    node = "/#{status_id}"
    reactions = "/?fields=" +
            "reactions.type(LIKE).limit(0).summary(total_count).as(like)" +
            ",reactions.type(LOVE).limit(0).summary(total_count).as(love)" +
            ",reactions.type(WOW).limit(0).summary(total_count).as(wow)" +
            ",reactions.type(HAHA).limit(0).summary(total_count).as(haha)" +
            ",reactions.type(SAD).limit(0).summary(total_count).as(sad)" +
            ",reactions.type(ANGRY).limit(0).summary(total_count).as(angry)"
    parameters = "&access_token=#{ENV['FACEBOOK_APP_ID'] + "|" + ENV['FACEBOOK_APP_SECRET']}"
    url = base + node + reactions + parameters

    # retrieve data
    data = JSON.parse(request_until_succeed(url))

    return data
  end

  def self.process_facebook_page_feed_status(status, page_id)

    # The status is now a Python dictionary, so for top-level items,
    # we can simply call the key.

    # Additionally, some items may not always exist,
    # so must check for existence first

    status_id = status['id']
    status_message = status['message'] || ''
    link_name = status['name'] || ''
    status_type = status['type']
    status_link = status['link'] || ''

    # Time needs special care since a) it's in UTC and
    # b) it's not easy to use in statistical programs.

    status_published = DateTime.strptime(
            status['created_time'],'%Y-%m-%dT%H:%M:%S+0000')
    status_published = status_published - 5.hours # EST
    status_published = status_published.strftime(
            '%Y-%m-%d %H:%M:%S') # best time format for spreadsheet programs

    # Nested items require chaining dictionary keys.

    num_reactions = status['reactions'] ? status['reactions']['summary']['total_count'] : 0
    num_comments = status['comments'] ? status['comments']['summary']['total_count'] : 0
    num_shares = status['shares'] ? status['shares']['count'] : 0

    # Counts of each reaction separately; good for sentiment
    # Only check for reactions if past date of implementation:
    # http://newsroom.fb.com/news/2016/02/reactions-now-available-globally/

    reactions = status_published > '2016-02-24 00:00:00' ? get_reactions_for_status(status_id) : {}

    num_likes = reactions['like'] ? reactions['like']['summary']['total_count'] : 0

    # Special case: Set number of Likes to Number of reactions for pre-reaction
    # statuses

    num_likes = status_published < '2016-02-24 00:00:00' ? num_reactions : num_likes

    get_num_total_reactions = lambda { |reaction_type, reactions|
      if !reactions[reaction_type]
          return 0
      else
          return reactions[reaction_type]['summary']['total_count']
      end
    }

    num_loves = get_num_total_reactions.call('love', reactions)
    num_wows = get_num_total_reactions.call('wow', reactions)
    num_hahas = get_num_total_reactions.call('haha', reactions)
    num_sads = get_num_total_reactions.call('sad', reactions)
    num_angrys = get_num_total_reactions.call('angry', reactions)

    # Return a tuple of all processed data
    a = {"facebook_status_id" => status_id, "facebook_page_id" => page_id, "status_message" => status_message,
                          "link_name" => link_name, "status_type" => status_type, "status_link" => status_link,
                          "status_published_at" => status_published, "num_reactions" => num_reactions, "num_comments" => num_comments,
                          "num_shares" => num_shares, "num_likes" => num_likes, "num_loves" => num_loves, "num_wows" => num_wows,
                          "num_hahas" => num_hahas, "num_sads" => num_sads, "num_angrys" => num_angrys}
    puts a
    
    FacebookStatus.create(facebook_status_id: status_id, facebook_page_id: page_id, status_message: status_message, 
                          link_name: link_name, status_type: status_type, status_link: status_link,
                          status_published_at: status_published, num_reactions: num_reactions, num_comments: num_comments, 
                          num_shares: num_shares, num_likes: num_likes, num_loves: num_loves, num_wows: num_wows, 
                          num_hahas: num_hahas, num_sads: num_sads, num_angrys: num_angrys)
  end

  def self.scrape_facebook_page_feed_status(page_id)
    page = FacebookPage.first_or_create(facebook_page_id: page_id)
    
    has_next_page = true
    num_processed = 0   # keep a count on how many we've processed
    scrape_starttime = DateTime.now

    puts "Scraping #{page_id} Facebook Page: #{scrape_starttime}\n"

    statuses = get_facebook_page_feed_data(page_id, 100)

    while has_next_page
      statuses['data'].each do |status|

        # Ensure it is a status with the expected metadata
        if status['reactions']
            process_facebook_page_feed_status(status, page_id)
        end

        # output progress occasionally to make sure code is not
        # stalling
        num_processed += 1
        if num_processed % 100 == 0
            puts "#{num_processed} Statuses Processed: #{DateTime.now}"
        end
      end

      # if there is no next page, we're done.
      if statuses['paging']
        statuses = JSON.parse(request_until_succeed(
                                statuses['paging']['next']))
      else
        has_next_page = false
      end
    end

    puts "\nDone!\n#{num_processed} Statuses Processed in #{DateTime.now - scrape_starttime}"
  end
end