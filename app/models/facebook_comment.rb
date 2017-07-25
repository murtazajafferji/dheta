#require 'liblinear'
require 'csv'

class FacebookComment < ActiveRecord::Base
  
  self.primary_key = 'facebook_comment_id'
  belongs_to :parent, class_name: "FacebookComment", foreign_key: :parent_id
  belongs_to :facebook_status
  belongs_to :facebook_page
  @scrape_page_limit = 100

  #FacebookComment.scrape_facebook_page_feed_comments('breitbart')
  #ActiveRecord::Base.logger = nil

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

  def self.get_facebook_user_data(user_id)

    # Construct the URL string
    base = "https://graph.facebook.com/v2.6"
    node = "/#{user_id}" 
    fields = "?fields=id,about,admin_notes,age_range,birthday,cover,currency,devices,education,email,favorite_athletes,favorite_teams,first_name,gender,hometown,inspirational_people,install_type,installed,interested_in,is_verified,labels,languages,last_name,link,locale,location,middle_name,name,name_format,political,public_key,quotes,relationship_status,religion,significant_other,sports,timezone,updated_time,website,work"
    #fields = "?fields=id,about,admin_notes,age_range,birthday,context,cover,currency,devices,education,email,employee_number,favorite_athletes,favorite_teams,first_name,gender,hometown,inspirational_people,install_type,installed,interested_in,is_shared_login,is_verified,labels,languages,last_name,link,locale,location,meeting_for,middle_name,name,name_format,payment_pricepoints,political,public_key,quotes,relationship_status,religion,security_settings,shared_login_upgrade_required_by,significant_other,sports,test_group,third_party_id,timezone,token_for_business,updated_time,verified,video_upload_limits,viewer_can_send_gift,website,work"
    parameters = "&access_token=#{ENV['FACEBOOK_APP_ID'] + "|" + ENV['FACEBOOK_APP_SECRET']}"
    url = base + node + fields + parameters

    # retrieve data
    data = request_until_succeed(url)
    if !data
      return nil
    else
      return JSON.parse(data)
    end
  end
  # 2006845566203408

  def self.process_facebook_comment(comment, status_id, parent_id = '')

    # The status is now a Python dictionary, so for top-level items,
    # we can simply call the key.

    # Additionally, some items may not always exist,
    # so must check for existence first

    comment_id = comment['id']
    comment_message = comment['message'] || ''
    comment_author = comment['from']['name']
    puts comment['from']
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

    # Get statuses without comments
    statuses = FacebookStatus.includes(:facebook_comments).where(facebook_page_id: page_id, facebook_comments: { facebook_status_id: nil })

    statuses.each do |status|
      has_next_page = true

      comments = get_facebook_comment_feed_data(status['facebook_status_id'], @scrape_page_limit)

      while has_next_page and comments != nil
        comments['data'].each do |comment|
          process_facebook_comment(comment, status['facebook_status_id'])

          if comment['comments']
            has_next_subpage = true

            subcomments = get_facebook_comment_feed_data(comment['id'], @scrape_page_limit)

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

  def process_offensive_words
    self.offensive_words = self.comment_message.scan(self.class.offensive_words).join(',')
  end

  def process_stopwords
    stemmer = UEAStemmer.new
    self.comment_message_without_stopwords = self.comment_message.gsub(self.class.stop_words, '').split(' ').map{|x| stemmer.stem(x)}.join(' ')
  end

  def self.process_offensive_class reset = false
    model = File.read(Rails.root.join('ml', 'classifier_data.zip'))
    classifier = Marshal.load(model)

    comments = reset ? FacebookComment.all : FacebookComment.where('offensive_class IS NULL')
    comments.each do |comment|
      if reset || comment.offensive_class == nil
        comment.process_offensive_class classifier
      end
      comment.save
    end
  end

  def process_offensive_class classifier
    self.offensive_class = classifier.classify self.comment_message
  end

  def self.process_comments reset = false
    model = File.read(Rails.root.join('ml', 'classifier_data.zip'))
    classifier = Marshal.load(model)

    comments = reset ? FacebookComment.all : FacebookComment.where('comment_message_without_stopwords IS NULL or offensive_words IS NULL or offensive_class IS NULL')
    comments.each do |comment|
      if reset || comment.offensive_words == nil
        comment.process_offensive_words
      end
      if reset || comment.comment_message_without_stopwords == nil
        comment.process_stopwords
      end
      if reset || comment.offensive_class == nil
        comment.process_offensive_class classifier
      end
      comment.save
    end
  end

  def self.unprocess_comments
    comments = FacebookComment.where('comment_message_without_stopwords IS NOT NULL or offensive_words IS NOT NULL')
    comments.each do |comment|
      if comment.offensive_words != nil
        comment.offensive_words = nil
      end
      if comment.comment_message_without_stopwords != nil
        comment.comment_message_without_stopwords = nil
      end
      comment.save
    end
  end

  def self.offensive_words
/\bbacon\b|\bwhite power\b|\bbeta\b|\bblue pill\b|\bpurple-haired\b|\bblue-haired\b|\bBTFO\b|\bcoloring book\b|\bctr\b|\bcuck\b|\bcurrent year\b|\bfeminist\b|\bglobalist\b|\blow engergy\b|\bparticipation trophy\b|\bpc\b|\bpolitically correct\b|\bregressive left\b|\bsafe space\b|\bsjw\b|\bsnowflake\b|\btrigger\b|\btriggered\b|\btolerant left\b|\btumblrina\b|\bimmigrant\b|\brefugee\b|\bmohammad\b|\bmohammed\b|\bmuhammad\b|\bmuhammed\b|\bmohamad\b|\bmuhamad\b|\bmohamed\b|\bmuhamed\b|\bmuslim\b|\bislam\b|\bjew\b|\bjewish\b|\bnazi\b|\bkill\b|\bjihad\b|\bpig\b|\bplanned parenthood\b|\bgenocide\b|\bban\b|\bwall\b|\blibtard\b|\buncivilised\b|\bgypo\b|\bgypos\b|\bcunt\b|\bcunts\b|\bpeckerwood\b|\bpeckerwoods\b|\braghead\b|\bragheads\b|\bcripple\b|\bcripples\b|\bniggur\b|\bniggurs\b|\byellow bone\b|\byellow bones\b|\bmuzzie\b|\bmuzzies\b|\bniggar\b|\bniggars\b|\bnigger\b|\bniggers\b|\bgreaseball\b|\bgreaseballs\b|\bwhite trash\b|\bwhite trashes\b|\bnig nog\b|\bnig nogs\b|\bfaggot\b|\bfaggots\b|\bcotton picker\b|\bcotton pickers\b|\bdarkie\b|\bdarkies\b|\bhoser\b|\bhosers\b|\bUncle Tom\b|\bUncle Toms\b|\bJihadi\b|\bJihadis\b|\bretard\b|\bretards\b|\bhillbilly\b|\bhillbillies\b|\bfag\b|\bfags\b|\btrailer trash\b|\btrailer trashes\b|\bpikey\b|\bpikies\b|\bnicca\b|\bniccas\b|\btranny\b|\btrannies\b|\bporch monkey\b|\bporch monkies\b|\bwigger\b|\bwiggers\b|\bwetback\b|\bwetbacks\b|\bnigglet\b|\bnigglets\b|\bwigga\b|\bwiggas\b|\bdhimmi\b|\bdhimmis\b|\bhonkey\b|\bhonkies\b|\beurotrash\b|\beurotrashes\b|\byardie\b|\byardies\b|\btrailer park trash\b|\btrailer park trashes\b|\bniggah\b|\bniggahes\b|\byokel\b|\byokels\b|\bnigguh\b|\bnigguhes\b|\bcamel jockey\b|\bcamel jockies\b|\bhonkie\b|\bhonkies\b|\bniglet\b|\bniglets\b|\bgyppo\b|\bgyppos\b|\bdyke\b|\bdykes\b|\bhalf breed\b|\bhonky\b|\bhonkies\b|\brace traitor\b|\brace traitors\b|\bjiggaboo\b|\bjiggaboos\b|\bChinaman\b|\bChinamans\b|\bcurry muncher\b|\bcurry munchers\b|\bjungle bunny\b|\bjungle bunnies\b|\bcoon ass\b|\bcoon asses\b|\bnewfie\b|\bnewfies\b|\bhouse nigger\b|\bhouse niggers\b|\blimey\b|\blimies\b|\bred bone\b|\bred bones\b|\bguala\b|\bgualas\b|\bplastic paddy\b|\bplastic paddies\b|\bwhigger\b|\bwhiggers\b|\bjigaboo\b|\bjigaboos\b|\bnig\b|\bnigs\b|\bZionazi\b|\bZionazis\b|\bspear chucker\b|\bspear chuckers\b|\bniggress\b|\bniggresses\b|\byobbo\b|\byobbos\b|\bborder jumper\b|\bborder jumpers\b|\bsperg\b|\bspergs\b|\bpommy\b|\bpommies\b|\bmunter\b|\bmunters\b|\btar baby\b|\btar babies\b|\bpommie\b|\bpommies\b|\bgyp\b|\bgyps\b|\banchor baby\b|\banchor babies\b|\btwat\b|\btwats\b|\bborder hopper\b|\bborder hoppers\b|\bqueer\b|\bqueers\b|\bdarky\b|\bdarkies\b|\bching chong\b|\bching chongs\b|\bkhazar\b|\bkhazars\b|\bgippo\b|\bgippos\b|\bskanger\b|\bskangers\b|\bbeaner\b|\bbeaners\b|\bquadroon\b|\bquadroons\b|\bgator bait\b|\bgator baits\b|\bCushite\b|\bCushites\b|\bmud shark\b|\bmud sharks\b|\bcracker\b|\bcrackers\b|\bdune coon\b|\bdune coons\b|\bpickaninny\b|\bpickaninnies\b|\bslant eye\b|\bslant eyes\b|\bsideways vagina\b|\bsideways vaginas\b|\bhick\b|\bhicks\b|\bcamel fucker\b|\bcamel fuckers\b|\bredneck\b|\brednecks\b|\bspiv\b|\bspivs\b|\bzipperhead\b|\bzipperheads\b|\bKushite\b|\bKushites\b|\bShylock\b|\bShylocks\b|\bgook\b|\bgooks\b|\bpapist\b|\bpapists\b|\bhymie\b|\bhymies\b|\bwog\b|\bwogs\b|\bscally\b|\bscallies\b|\bcoon\b|\bcoons\b|\bwhitey\b|\bwhities\b|\bnigette\b|\bnigettes\b|\bpaki\b|\bpakis\b|\btowel head\b|\btowel heads\b|\bArgie\b|\bArgies\b|\bwexican\b|\bwexicans\b|\bjigger\b|\bjiggers\b|\binjun\b|\binjuns\b|\bocker\b|\bockers\b|\bpolack\b|\bpolacks\b|\bmoulie\b|\bmoulies\b|\bniggor\b|\bniggors\b|\bscanger\b|\bscangers\b|\bofay\b|\bofaies\b|\bjigga\b|\bjiggas\b|\bredskin\b|\bredskins\b|\bchonky\b|\bchonkies\b|\bhebro\b|\bhebros\b|\bwop\b|\bwops\b|\bchink\b|\bchinks\b|\bsideways pussy\b|\bsideways pussies\b|\bpaleface\b|\bpalefaces\b|\bwagon burner\b|\bwagon burners\b|\bnigra\b|\bnigras\b|\bspic\b|\bspics\b|\bspics\b|\bjocky\b|\bjockies\b|\bkraut\b|\bkrauts\b|\bsteek\b|\bsteeks\b|\bcoolie\b|\bcoolies\b|\bgooky\b|\bgookies\b|\boctaroon\b|\boctaroons\b|\bbint\b|\bbints\b|\bshit heel\b|\bshit heels\b|\bsquaw\b|\bsquaws\b|\bbog trotter\b|\bbog trotters\b|\bOriental\b|\bOrientals\b|\bhalfrican\b|\bhalfricans\b|\bpaddy\b|\bpaddies\b|\bgroid\b|\bgroids\b|\bjiggabo\b|\bjiggabos\b|\bjigg\b|\bjiggs\b|\bjant\b|\bjants\b|\bspide\b|\bspides\b|\bcamel humper\b|\bcamel humpers\b|\bwhite nigger\b|\bwhite niggers\b|\bZOG\b|\bZOGs\b|\bdiaper head\b|\bdiaper heads\b|\bheeb\b|\bheebs\b|\bChrist killer\b|\bChrist killers\b|\bpiker\b|\bpikers\b|\bhigger\b|\bhiggers\b|\blemonhead\b|\blemonheads\b|\bHun\b|\bHuns\b|\bpopolo\b|\bpopolos\b|\bcowboy killer\b|\bcowboy killers\b|\bjhant\b|\bjhants\b|\beyetie\b|\beyeties\b|\bmockey\b|\bmockies\b|\balligator bait\b|\balligator baits\b|\bJap\b|\bJaps\b|\bshanty Irish\b|\bshanty Irishes\b|\bredlegs\b|\bmulignan\b|\bmulignans\b|\bjockie\b|\bjockies\b|\bmangia cake\b|\bmangia cakes\b|\bmoulinyan\b|\bmoulinyans\b|\bnigar\b|\bnigars\b|\bdarkey\b|\bdarkies\b|\bgurrier\b|\bgurriers\b|\blubra\b|\blubras\b|\bBuckwheat\b|\bBuckwheats\b|\bmulato\b|\bmulatos\b|\bprairie nigger\b|\bprairie niggers\b|\bkyke\b|\bkykes\b|\bboonie\b|\bboonies\b|\bmick\b|\bmicks\b|\bbluegum\b|\bbluegums\b|\bspigger\b|\bspiggers\b|\bborder bunny\b|\bborder bunnies\b|\bkike\b|\bkikes\b|\bmoulignon\b|\bmoulignons\b|\broundeye\b|\broundeyes\b|\bginzo\b|\bginzos\b|\bJewbacca\b|\bJewbaccas\b|\bbooner\b|\bbooners\b|\bnigre\b|\bnigres\b|\bscallie\b|\bscallies\b|\bniger\b|\bnigers\b|\bdinge\b|\bdinges\b|\bLeb\b|\bLebs\b|\bLebbo\b|\bLebbos\b|\bsambo\b|\bsambos\b|\bAfricoon\b|\bAfricoons\b|\bling ling\b|\bling lings\b|\bgub\b|\bgubs\b|\bbanana bender\b|\bbanana benders\b|\bjapie\b|\bjapies\b|\bisland nigger\b|\bisland niggers\b|\bhairyback\b|\bhairybacks\b|\blugan\b|\blugans\b|\bBog Irish\b|\bBog Irishes\b|\bblaxican\b|\bblaxicans\b|\bmoke\b|\bmokes\b|\bnigor\b|\bnigors\b|\bbix nood\b|\bbix noods\b|\bKushi\b|\bKushis\b|\bguala guala\b|\bguala gualas\b|\bhoosier\b|\bhoosiers\b|\bthicklips\b|\bmook\b|\bmooks\b|\bmuk\b|\bmuks\b|\bsoup taker\b|\bsoup takers\b|\bsenga\b|\bsengas\b|\bCushi\b|\bCushis\b|\bpogue\b|\bpogues\b|\babo\b|\babos\b|\bping pang\b|\bping pangs\b|\bproddy dog\b|\bproddy dogs\b|\bboong\b|\bboongs\b|\bdago\b|\bdagos\b|\bdogun\b|\bdoguns\b|\bmocky\b|\bmockies\b|\bpoppadom\b|\bpoppadoms\b|\bGwat\b|\bGwats\b|\bice nigger\b|\bice niggers\b|\bspook\b|\bspooks\b|\bAfro-Saxon\b|\bAfro-Saxons\b|\bguido\b|\bguidos\b|\blatrino\b|\blatrinos\b|\blowlander\b|\blowlanders\b|\bmockie\b|\bmockies\b|\bmoky\b|\bmokies\b|\bmosshead\b|\bmossheads\b|\bAfrican catfish\b|\bAfrican catfishes\b|\bgyppy\b|\bgyppies\b|\btimber nigger\b|\btimber niggers\b|\bAmericoon\b|\bAmericoons\b|\bcamel cowboy\b|\bcamel cowboies\b|\beh hole\b|\beh holes\b|\bHunyak\b|\bHunyaks\b|\bslopehead\b|\bslopeheads\b|\bteabagger\b|\bteabaggers\b|\bArmo\b|\bArmos\b|\bbitch\b|\bbitches\b|\bgreaser\b|\bgreasers\b|\bHonyock\b|\bHonyocks\b|\bmud person\b|\bmud persons\b|\bpineapple nigger\b|\bpineapple niggers\b|\bretarded\b|\bsemihole\b|\bsemiholes\b|\bAmo\b|\bAmos\b|\bborder nigger\b|\bborder niggers\b|\bbuckra\b|\bbuckras\b|\bburrhead\b|\bburrheads\b|\bcab nigger\b|\bcab niggers\b|\bcarpet pilot\b|\bcarpet pilots\b|\bpancake face\b|\bpancake faces\b|\bspigotty\b|\bspigotties\b|\bcarrot snapper\b|\bcarrot snappers\b|\bchili shitter\b|\bchili shitters\b|\bcurry slurper\b|\bcurry slurpers\b|\bghetto hamster\b|\bghetto hamsters\b|\bice monkey\b|\bice monkies\b|\broofucker\b|\broofuckers\b|\bVelcro head\b|\bVelcro heads\b|\bwiggerette\b|\bwiggerettes\b|\bbeach nigger\b|\bbeach niggers\b|\bbean dipper\b|\bbean dippers\b|\bbog hopper\b|\bbog hoppers\b|\bBuddhahead\b|\bBuddhaheads\b|\bcamel jacker\b|\bcamel jackers\b|\bCaublasian\b|\bCaublasians\b|\bcave nigger\b|\bcave niggers\b|\bcow kisser\b|\bcow kissers\b|\bdune nigger\b|\bdune niggers\b|\bfour by two\b|\bfour by twos\b|\bfresh off the boat\b|\bfresh off the boats\b|\bgin jockey\b|\bgin jockies\b|\bgolliwog\b|\bgolliwogs\b|\bguinea\b|\bguineas\b|\bJim Fish\b|\bJim Fishes\b|\bmackerel snapper\b|\bmackerel snappers\b|\boctroon\b|\boctroons\b|\bpohm\b|\bpohms\b|\bpussy\b|\bpussies\b|\bRussellite\b|\bRussellites\b|\bspice nigger\b|\bspice niggers\b|\buncivilized\b|\bWhipped\b|\balbino\b|\balbinos\b|\bape\b|\bapes\b|\bAunt Jemima\b|\bAunt Jemimas\b|\bbuckethead\b|\bbucketheads\b|\bChinese wetback\b|\bChinese wetbacks\b|\bchug\b|\bchugs\b|\bcurry stinker\b|\bcurry stinkers\b|\bdyke jumper\b|\bdyke jumpers\b|\beight ball\b|\beight balls\b|\bgun burglar\b|\bgun burglars\b|\bikey mo\b|\bikey mos\b|\blawn jockey\b|\blawn jockies\b|\bleprechaun\b|\bleprechauns\b|\bmutt\b|\bmutts\b|\bnegro\b|\bnegros\b|\bnegroes\b|\bnitchee\b|\bnitchees\b|\bsooty\b|\bsooties\b|\bspick\b|\bspicks\b|\btinkard\b|\btinkards\b|\buncircumcised baboon\b|\buncircumcised baboons\b|\bzigabo\b|\bzigabos\b|\babbo\b|\babbos\b|\bAnglo\b|\bAnglos\b|\bAunt Jane\b|\bAunt Janes\b|\bAunt Mary\b|\bAunt Maries\b|\bAunt Sally\b|\bAunt Sallies\b|\bazn\b|\bazns\b|\bbamboo coon\b|\bbamboo coons\b|\bbanana lander\b|\bbanana landers\b|\bbanjo lips\b|\bbans and cans\b|\bbeaner shnitzel\b|\bbeaner shnitzels\b|\bbeaney\b|\bbeanies\b|\bBengali\b|\bBengalis\b|\bbhrempti\b|\bbhremptis\b|\bbird\b|\bbirds\b|\bbitter clinger\b|\bbitter clingers\b|\bblack Barbie\b|\bblack Barbies\b|\bblack dago\b|\bblack dagos\b|\bblockhead\b|\bblockheads\b|\bbog jumper\b|\bbog jumpers\b|\bboon\b|\bboons\b|\bboonga\b|\bboongas\b|\bBounty bar\b|\bBounty bars\b|\bboxhead\b|\bboxheads\b|\bbrass ankle\b|\bbrass ankles\b|\bbrownie\b|\bbrownies\b|\bbuffie\b|\bbuffies\b|\bbug eater\b|\bbug eaters\b|\bbuk buk\b|\bbuk buks\b|\bbumblebee\b|\bbumblebees\b|\bbung\b|\bbungs\b|\bbunga\b|\bbungas\b|\bbutterhead\b|\bbutterheads\b|\bcan eater\b|\bcan eaters\b|\bcelestial\b|\bcelestials\b|\bCharlie\b|\bCharlies\b|\bchee chee\b|\bchee chees\b|\bchi chi\b|\bchi chis\b|\bchigger\b|\bchiggers\b|\bchinig\b|\bchinigs\b|\bchink a billy\b|\bchink a billies\b|\bchunky\b|\bchunkies\b|\bclam\b|\bclams\b|\bclamhead\b|\bclamheads\b|\bcolored\b|\bcoloured\b|\bcrow\b|\bcrows\b|\bdego\b|\bdegos\b|\bdink\b|\bdinks\b|\bdogan\b|\bdogans\b|\bdomes\b|\bdot head\b|\bdot heads\b|\beggplant\b|\beggplants\b|\bFairy\b|\bFairies\b|\bfez\b|\bfezs\b|\bFOB\b|\bFOBs\b|\bfog nigger\b|\bfog niggers\b|\bfuzzy\b|\bfuzzies\b|\bfuzzy wuzzy\b|\bfuzzy wuzzies\b|\bgable\b|\bgables\b|\bGerudo\b|\bGerudos\b|\bgew\b|\bgews\b|\bghetto\b|\bghettos\b|\bgipp\b|\bgipps\b|\bgook eye\b|\bgook eyes\b|\bgyppie\b|\bgyppies\b|\bheinie\b|\bheinies\b|\bho\b|\bhos\b|\bhoe\b|\bhoes\b|\bHonyak\b|\bHonyaks\b|\bHunkie\b|\bHunkies\b|\bHunky\b|\bHunkies\b|\bHunyock\b|\bHunyocks\b|\bike\b|\bikes\b|\bikey\b|\bikies\b|\biky\b|\bikies\b|\bjig\b|\bjigs\b|\bjigarooni\b|\bjigaroonis\b|\bjijjiboo\b|\bjijjiboos\b|\bkotiya\b|\bkotiyas\b|\bmickey\b|\bmickies\b|\bmoch\b|\bmoches\b|\bmock\b|\bmocks\b|\bmong\b|\bmongs\b|\bmonkey\b|\bmonkies\b|\bMoor\b|\bMoors\b|\bmoss eater\b|\bmoss eaters\b|\bmoxy\b|\bmoxies\b|\bmuktuk\b|\bmuktuks\b|\bmung\b|\bmungs\b|\bmunt\b|\bmunts\b|\bned\b|\bnet head\b|\bnet heads\b|\bnichi\b|\bnichis\b|\bnichiwa\b|\bnichiwas\b|\bnidge\b|\bnidges\b|\bnip\b|\bnips\b|\bnitchie\b|\bnitchies\b|\bnitchy\b|\bnitchies\b|\bOrangie\b|\bOrangies\b|\bOreo\b|\bOreos\b|\bpapoose\b|\bpapooses\b|\bpiky\b|\bpikies\b|\bpinto\b|\bpintos\b|\bpointy head\b|\bpointy heads\b|\bpollo\b|\bpollos\b|\bpom\b|\bpoms\b|\bpommie grant\b|\bpommie grants\b|\bPunjab\b|\bPunjabs\b|\brube\b|\brubes\b|\bsawney\b|\bsawnies\b|\bscag\b|\bscags\b|\bseppo\b|\bseppos\b|\bseptic\b|\bseptics\b|\bshant\b|\bshants\b|\bsheeny\b|\bsheenies\b|\bsheepfucker\b|\bsheepfuckers\b|\bShelta\b|\bSheltas\b|\bshiner\b|\bshiners\b|\bshit kicker\b|\bshit kickers\b|\bShy\b|\bShies\b|\bsideways cooter\b|\bsideways cooters\b|\bskag\b|\bskags\b|\bSkippy\b|\bSkippies\b|\bslag\b|\bslags\b|\bslant\b|\bslants\b|\bslit\b|\bslits\b|\bslope\b|\bslopes\b|\bslopey\b|\bslopies\b|\bslopy\b|\bslopies\b|\bsmoke jumper\b|\bsmoke jumpers\b|\bsmoked Irish\b|\bsmoked Irishes\b|\bsmoked Irishman\b|\bsmoked Irishmans\b|\bsole\b|\bsoles\b|\bspickaboo\b|\bspickaboos\b|\bspig\b|\bspigs\b|\bspik\b|\bspiks\b|\bspink\b|\bspinks\b|\bsquarehead\b|\bsquareheads\b|\bsquinty\b|\bsquinties\b|\bstovepipe\b|\bstovepipes\b|\bsub human\b|\bsub humans\b|\bsucker fish\b|\bsucker fishes\b|\bTaffy\b|\bTaffies\b|\bteapot\b|\bteapots\b|\btenker\b|\btenkers\b|\btincker\b|\btinckers\b|\btinkar\b|\btinkars\b|\btinker\b|\btinkers\b|\btinkere\b|\btinkeres\b|\btrash\b|\btrashes\b|\btree jumper\b|\btree jumpers\b|\btunnel digger\b|\btunnel diggers\b|\bTwinkie\b|\bTwinkies\b|\btyncar\b|\btyncars\b|\btynekere\b|\btynekeres\b|\btynkard\b|\btynkards\b|\btynkare\b|\btynkares\b|\btynker\b|\btynkers\b|\btynkere\b|\btynkeres\b|\bWASP\b|\bWASPs\b|\bYank\b|\bYanks\b|\bYankee\b|\bYankees\b|\byellow\b|\byellows\b|\byid\b|\byids\b|\byob\b|\byobs\b|\bzebra\b|\bzebras\b|\bzippohead\b|\bzippoheads\b|\bZOG lover\b|\bZOG lovers\b|\bknacker\b|\bknackers\b|\bshyster\b|\bshysters\b|\bbogan\b|\bbogans\b|\bhayseed\b|\bmoon cricket\b|\bmoon crickets\b|\bmud duck\b|\bmud ducks\b|\bsurrender monkey\b|\bsurrender monkies\b|\bbludger\b|\bbludgers\b|\bcharver\b|\bcharvers\b|\bdole bludger\b|\bdole bludgers\b|\bchav\b|\bchavs\b|\bsheister\b|\bsheisters\b|\bcharva\b|\bcharvas\b|\btouch of the tar brush\b|\btouch of the tar brushes\b|\bNorthern monkey\b|\bNorthern monkies\b|\bSouthern fairy\b|\bSouthern fairies\b|\bgubba\b|\bgubbas\b|\bstump jumper\b|\bstump jumpers\b|\bhebe\b|\bhebes\b|\bmillie\b|\bmillies\b|\bquashie\b|\bquashies\b|\bdingo fucker\b|\bdingo fuckers\b|\bmil bag\b|\bmil bags\b|\bconspiracy theorist\b|\bconspiracy theorists\b|\bwhore from Fife\b|\bwhore from Fifes\b|\bboojie\b|\bboojies\b|\bbook book\b|\bbook books\b|\bcheese eating surrender monkey\b|\bcheese eating surrender monkies\b|\bidiot\b|\bidiots\b|\bjock\b|\bjocks\b|\bmack\b|\bmacks\b|\bMerkin\b|\bMerkins\b|\bneche\b|\bneches\b|\bneejee\b|\bneejees\b|\bneechee\b|\bneechees\b|\bpowderburn\b|\bpowderburns\b|\bproddywhoddy\b|\bproddywhoddies\b|\bproddywoddy\b|\bproddywoddies\b|\bRhine monkey\b|\bRhine monkies\b/i
  end

  def self.stop_words
/[.,\/!\^&\*;:{}=\-_`~()\?]|\[\[PHOTO\]\]|\bain’t\b|\bain't\b|\baren’t\b|\baren't\b|\ba’s\b|\ba's\b|\bcan’t\b|\bcan't\b|\bcouldn’t\b|\bcouldn't\b|\bc’mon\b|\bc'mon\b|\bc’s\b|\bc's\b|\bdidn’t\b|\bdidn't\b|\bdoesn’t\b|\bdoesn't\b|\bdon’t\b|\bdon't\b|\bhadn’t\b|\bhadn't\b|\bhasn’t\b|\bhasn't\b|\bhaven’t\b|\bhaven't\b|\bhere’s\b|\bhere's\b|\bhe’s\b|\bhe's\b|\bisn’t\b|\bisn't\b|\bit’d\b|\bit'd\b|\bit’ll\b|\bit'll\b|\bit’s\b|\bit's\b|\bi’d\b|\bi'd\b|\bi’ll\b|\bi'll\b|\bi’m\b|\bi'm\b|\bi’ve\b|\bi've\b|\blet’s\b|\blet's\b|\bshouldn’t\b|\bshouldn't\b|\bthat’s\b|\bthat's\b|\bthere’s\b|\bthere's\b|\bthey’d\b|\bthey'd\b|\bthey’ll\b|\bthey'll\b|\bthey’re\b|\bthey're\b|\bthey’ve\b|\bthey've\b|\bt’s\b|\bt's\b|\bwasn’t\b|\bwasn't\b|\bweren’t\b|\bweren't\b|\bwe’d\b|\bwe'd\b|\bwe’ll\b|\bwe'll\b|\bwe’re\b|\bwe're\b|\bwe’ve\b|\bwe've\b|\bwhat’s\b|\bwhat's\b|\bwhere’s\b|\bwhere's\b|\bwho’s\b|\bwho's\b|\bwon’t\b|\bwon't\b|\bwouldn’t\b|\bwouldn't\b|\byou’d\b|\byou'd\b|\byou’ll\b|\byou'll\b|\byou’re\b|\byou're\b|\byou’ve\b|\byou've\b|\ba\b|\bable\b|\babout\b|\babove\b|\baccording\b|\baccordingly\b|\bacross\b|\bactually\b|\bafter\b|\bafterwards\b|\bagain\b|\bagainst\b|\ball\b|\ballow\b|\ballows\b|\balmost\b|\balone\b|\balong\b|\balready\b|\balso\b|\balthough\b|\balways\b|\bam\b|\bamong\b|\bamongst\b|\bamoungst\b|\bamount\b|\ban\b|\band\b|\banother\b|\bany\b|\banybody\b|\banyhow\b|\banyone\b|\banything\b|\banyway\b|\banyways\b|\banywhere\b|\bapart\b|\bappear\b|\bappreciate\b|\bappropriate\b|\bare\b|\baround\b|\bas\b|\baside\b|\bask\b|\basking\b|\bassociated\b|\bat\b|\bavailable\b|\baway\b|\bawfully\b|\bback\b|\bbe\b|\bbecame\b|\bbecause\b|\bbecome\b|\bbecomes\b|\bbecoming\b|\bbeen\b|\bbefore\b|\bbeforehand\b|\bbehind\b|\bbeing\b|\bbelieve\b|\bbelow\b|\bbeside\b|\bbesides\b|\bbest\b|\bbetter\b|\bbetween\b|\bbeyond\b|\bbill\b|\bboth\b|\bbottom\b|\bbrief\b|\bbut\b|\bby\b|\bcall\b|\bcame\b|\bcan\b|\bcannot\b|\bcant\b|\bcause\b|\bcauses\b|\bcertain\b|\bcertainly\b|\bchanges\b|\bclearly\b|\bco\b|\bcom\b|\bcome\b|\bcomes\b|\bcomputer\b|\bcon\b|\bconcerning\b|\bconsequently\b|\bconsider\b|\bconsidering\b|\bcontain\b|\bcontaining\b|\bcontains\b|\bcorresponding\b|\bcould\b|\bcouldnt\b|\bcourse\b|\bcry\b|\bcurrently\b|\bde\b|\bdefinitely\b|\bdescribe\b|\bdescribed\b|\bdespite\b|\bdetail\b|\bdid\b|\bdifferent\b|\bdo\b|\bdoes\b|\bdoing\b|\bdone\b|\bdown\b|\bdownwards\b|\bdue\b|\bduring\b|\beach\b|\bedu\b|\beg\b|\beight\b|\beither\b|\beleven\b|\belse\b|\belsewhere\b|\bempty\b|\benough\b|\bentirely\b|\bespecially\b|\bet\b|\betc\b|\beven\b|\bever\b|\bevery\b|\beverybody\b|\beveryone\b|\beverything\b|\beverywhere\b|\bex\b|\bexactly\b|\bexample\b|\bexcept\b|\bfar\b|\bfew\b|\bfifteen\b|\bfifth\b|\bfify\b|\bfill\b|\bfind\b|\bfire\b|\bfirst\b|\bfive\b|\bfollowed\b|\bfollowing\b|\bfollows\b|\bfor\b|\bformer\b|\bformerly\b|\bforth\b|\bforty\b|\bfound\b|\bfour\b|\bfrom\b|\bfront\b|\bfull\b|\bfurther\b|\bfurthermore\b|\bget\b|\bgets\b|\bgetting\b|\bgive\b|\bgiven\b|\bgives\b|\bgo\b|\bgoes\b|\bgoing\b|\bgone\b|\bgot\b|\bgotten\b|\bgreetings\b|\bhad\b|\bhappens\b|\bhardly\b|\bhas\b|\bhasnt\b|\bhave\b|\bhaving\b|\bhe\b|\bhello\b|\bhelp\b|\bhence\b|\bher\b|\bhere\b|\bhereafter\b|\bhereby\b|\bherein\b|\bhereupon\b|\bhers\b|\bherself\b|\bhi\b|\bhim\b|\bhimself\b|\bhis\b|\bhither\b|\bhopefully\b|\bhow\b|\bhowbeit\b|\bhowever\b|\bhundred\b|\bi\b|\bie\b|\bif\b|\bignored\b|\bimmediate\b|\bin\b|\binasmuch\b|\binc\b|\bindeed\b|\bindicate\b|\bindicated\b|\bindicates\b|\binner\b|\binsofar\b|\binstead\b|\binterest\b|\binto\b|\binward\b|\bis\b|\bit\b|\bits\b|\bitself\b|\bjust\b|\bkeep\b|\bkeeps\b|\bkept\b|\bknow\b|\bknown\b|\bknows\b|\blast\b|\blately\b|\blater\b|\blatter\b|\blatterly\b|\bleast\b|\bless\b|\blest\b|\blet\b|\blike\b|\bliked\b|\blikely\b|\blittle\b|\blook\b|\blooking\b|\blooks\b|\bltd\b|\bmade\b|\bmainly\b|\bmany\b|\bmay\b|\bmaybe\b|\bme\b|\bmean\b|\bmeanwhile\b|\bmerely\b|\bmight\b|\bmill\b|\bmine\b|\bmore\b|\bmoreover\b|\bmost\b|\bmostly\b|\bmove\b|\bmuch\b|\bmust\b|\bmy\b|\bmyself\b|\bname\b|\bnamely\b|\bnd\b|\bnear\b|\bnearly\b|\bnecessary\b|\bneed\b|\bneeds\b|\bneither\b|\bnever\b|\bnevertheless\b|\bnew\b|\bnext\b|\bnine\b|\bno\b|\bnobody\b|\bnon\b|\bnone\b|\bnoone\b|\bnor\b|\bnormally\b|\bnot\b|\bnothing\b|\bnovel\b|\bnow\b|\bnowhere\b|\bobviously\b|\bof\b|\boff\b|\boften\b|\boh\b|\bok\b|\bokay\b|\bold\b|\bon\b|\bonce\b|\bone\b|\bones\b|\bonly\b|\bonto\b|\bor\b|\bother\b|\bothers\b|\botherwise\b|\bought\b|\bour\b|\bours\b|\bourselves\b|\bout\b|\boutside\b|\bover\b|\boverall\b|\bown\b|\bpart\b|\bparticular\b|\bparticularly\b|\bper\b|\bperhaps\b|\bplaced\b|\bplease\b|\bplus\b|\bpossible\b|\bpresumably\b|\bprobably\b|\bprovides\b|\bput\b|\bque\b|\bquite\b|\bqv\b|\brather\b|\brd\b|\bre\b|\breally\b|\breasonably\b|\bregarding\b|\bregardless\b|\bregards\b|\brelatively\b|\brespectively\b|\bright\b|\bsaid\b|\bsame\b|\bsaw\b|\bsay\b|\bsaying\b|\bsays\b|\bsecond\b|\bsecondly\b|\bsee\b|\bseeing\b|\bseem\b|\bseemed\b|\bseeming\b|\bseems\b|\bseen\b|\bself\b|\bselves\b|\bsensible\b|\bsent\b|\bserious\b|\bseriously\b|\bseven\b|\bseveral\b|\bshall\b|\bshe\b|\bshould\b|\bshow\b|\bside\b|\bsince\b|\bsincere\b|\bsix\b|\bsixty\b|\bso\b|\bsome\b|\bsomebody\b|\bsomehow\b|\bsomeone\b|\bsomething\b|\bsometime\b|\bsometimes\b|\bsomewhat\b|\bsomewhere\b|\bsoon\b|\bsorry\b|\bspecified\b|\bspecify\b|\bspecifying\b|\bstill\b|\bsub\b|\bsuch\b|\bsup\b|\bsure\b|\bsystem\b|\btake\b|\btaken\b|\btell\b|\bten\b|\btends\b|\bth\b|\bthan\b|\bthank\b|\bthanks\b|\bthanx\b|\bthat\b|\bthats\b|\bthe\b|\btheir\b|\btheirs\b|\bthem\b|\bthemselves\b|\bthen\b|\bthence\b|\bthere\b|\bthereafter\b|\bthereby\b|\btherefore\b|\btherein\b|\btheres\b|\bthereupon\b|\bthese\b|\bthey\b|\bthick\b|\bthin\b|\bthink\b|\bthird\b|\bthis\b|\bthorough\b|\bthoroughly\b|\bthose\b|\bthough\b|\bthree\b|\bthrough\b|\bthroughout\b|\bthru\b|\bthus\b|\bto\b|\btogether\b|\btoo\b|\btook\b|\btop\b|\btoward\b|\btowards\b|\btried\b|\btries\b|\btruly\b|\btry\b|\btrying\b|\btwelve\b|\btwenty\b|\btwice\b|\btwo\b|\bun\b|\bunder\b|\bunfortunately\b|\bunless\b|\bunlikely\b|\buntil\b|\bunto\b|\bup\b|\bupon\b|\bus\b|\buse\b|\bused\b|\buseful\b|\buses\b|\busing\b|\busually\b|\bvalue\b|\bvarious\b|\bvery\b|\bvia\b|\bviz\b|\bvs\b|\bwant\b|\bwants\b|\bwas\b|\bway\b|\bwe\b|\bwelcome\b|\bwell\b|\bwent\b|\bwere\b|\bwhat\b|\bwhatever\b|\bwhen\b|\bwhence\b|\bwhenever\b|\bwhere\b|\bwhereafter\b|\bwhereas\b|\bwhereby\b|\bwherein\b|\bwhereupon\b|\bwherever\b|\bwhether\b|\bwhich\b|\bwhile\b|\bwhither\b|\bwho\b|\bwhoever\b|\bwhole\b|\bwhom\b|\bwhose\b|\bwhy\b|\bwill\b|\bwilling\b|\bwish\b|\bwith\b|\bwithin\b|\bwithout\b|\bwonder\b|\bwould\b|\byes\b|\byet\b|\byou\b|\byour\b|\byours\b|\byourself\b|\byourselves\b|\bzero\b/i
  end

  def detect_topic
    uri = URI('https://westus.api.cognitive.microsoft.com/text/analytics/v2.0/topics')
    #uri.query = URI.encode_www_form({
    #    # Request parameters
    #    'minDocumentsPerWord' => '{integer}',
    #    'maxDocumentsPerWord' => '{integer}'
    #})

    request = Net::HTTP::Post.new(uri.request_uri)
    # Request headers
    request['Content-Type'] = 'application/json'
    # Request headers
    request['Ocp-Apim-Subscription-Key'] = ENV['COGNITIVE_SERVICES_API_KEY']

    # Request body
    request.body = self.comment_message

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(request)
    end

    puts response.body
  end

  def key_phrase
    uri = URI('https://westus.api.cognitive.microsoft.com/text/analytics/v2.0/keyPhrases')
    uri.query = URI.encode_www_form({
    })

    request = Net::HTTP::Post.new(uri.request_uri)
    # Request headers
    request['Content-Type'] = 'application/json'
    # Request headers
    request['Ocp-Apim-Subscription-Key'] = ENV['COGNITIVE_SERVICES_API_KEY']
    # Request body
    request.body = self.comment_message

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(request)
    end

    puts response.body
  end

  def sentiment
    uri = URI('https://westus.api.cognitive.microsoft.com/text/analytics/v2.0/sentiment')
    uri.query = URI.encode_www_form({
    })

    request = Net::HTTP::Post.new(uri.request_uri)
    # Request headers
    request['Content-Type'] = 'application/json'
    # Request headers
    request['Ocp-Apim-Subscription-Key'] = ENV['COGNITIVE_SERVICES_API_KEY']
    # Request body
    request.body = self.comment_message

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(request)
    end

    puts response.body
  end

  CSV::Converters[:int] = lambda{|s| 
    begin 
      Integer(s)
    rescue ArgumentError
      s
    end
  }

  #def self.train
  #  csv_text = File.read(Rails.root.join('ml', 'labeled_data.csv'))
  #  csv = CSV.parse(csv_text, :headers => true, :encoding => 'ISO-8859-1', :converters => [:int])#
  #
  #  # Define class of each training data:
  #  labels = [1, -1]
  #  #labels = csv.headers
  #  puts csv.headers
  #
  #  # Training data is Array of Array:
  #  examples = csv.to_a[1..-1]
  #
  #  puts examples[0]
  #  #Next, set the bias (this corresponds to -B option on command line):
  #
  #  bias = 0.5 # default -1
  #  #Then, specify parameters and execute Liblinear.train to get the instance of Liblinear::Model.
  #
  #  model = Liblinear.train({ solver_type: Liblinear::L2R_LR }, labels, examples, bias)
  #  model.save('trained_model')
  #end

  def self.train percent = 0.8
    #prediction_column = 'class'
    prediction_column = 'insult'
    #comment_column = 'tweet'
    comment_column = 'comment'
    #desired_prediction = 0
    desired_prediction = 1
    #classes = [0,1,2]
    classes = [0,1]
    input_file = 'labeled_data.csv'
    input_file = 'kaggle_insult.csv'
    #hate_speech,offensive_language,neither,class,tweet
    #result_map = {0 => :hate, 1 => :offensive, 2 => :neutral}
    csv_text = File.read(Rails.root.join('ml', input_file))
    csv = CSV.parse(csv_text, encoding: 'ISO-8859-1', converters: [:int])
    headers = csv.shift
    rows = csv.map {|a| Hash[ headers.zip(a) ]}

    partition_index = rows.count * percent
    train, test = rows.partition.with_index { |_, index| index <= partition_index }
    puts train.count
    puts test.count
    classifier = ClassifierReborn::Bayes.new classes

    train.each do |row|
      classifier.train row[prediction_column], row[comment_column]
    end

    distribution = Hash.new(0)
    rows.each do |row|
      distribution[(classifier.classify row[comment_column])] += 1
    end

    correct_count = 0
    total_count = 0
    false_positive_count = 0
    true_negative_count = 0
    test.each do |row|
      prediction = classifier.classify(row[comment_column]).to_i
      if row[prediction_column] == desired_prediction || prediction == desired_prediction
        if prediction == row[prediction_column]
          correct_count += 1
        elsif row[prediction_column] == desired_prediction
          true_negative_count += 1
        else
          false_positive_count += 1
        end
        total_count += 1
      end
    end
    puts correct_count

    File.write(Rails.root.join('ml', 'classifier_data.zip'), (Marshal.dump classifier).force_encoding('UTF-8'))

    puts "Accuracy"
    puts correct_count.to_f/total_count
    puts "True negative"
    puts true_negative_count.to_f/total_count
    puts "False positive"
    puts false_positive_count.to_f/total_count
    puts distribution
  end

  def self.test_model input
    model = File.read(Rails.root.join('ml', 'classifier_data.zip'))
    classifier = Marshal.load(model)
    #result_map = {'0' => "Hate", '1' => 'Offensive', '2' => 'Neutral'}
    result_map = {'0' => "Not insulting", '1' => 'Insult'}
    prediction = classifier.classify(input)
    puts prediction
    puts result_map[classifier.classify(input)]
  end

  def self.combine_files 
    comments = File.readlines Rails.root.join('ml', "fb_data.txt")
    labels = File.readlines Rails.root.join('ml', "fb_label.txt")
    CSV.open(Rails.root.join('ml', "fb_sentiment.csv"), "w") do |csv|
      csv << ['comment', 'sentiment']
      comments.each_with_index do |comment, index|
        csv << [comment.strip, labels[index].strip]
      end
    end
  end
end