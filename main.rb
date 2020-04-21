require 'net/http'
require 'json'
require 'uri'
require './escape'
require 'optparse'

class FanboxItems
  def initialize(user_id,cookies)
    @user_id = user_id
    @cookies = cookies
    @query_parameters = {"userId"=>user_id, "maxPublishedDatetime"=>Time.now.strftime("%Y-%m-%d %H:%M:%S"), "maxId"=>9999999, "limit"=>10}
    @savedataDir = "data"
    @random = Random.new
  end
  def get_all
    postlist = JSON.parse(get_raw("https://fanbox.pixiv.net/api/post.listCreator?userId=#{@user_id}&limit=10"))
    while loop
      sleep(@random.rand(1.0)+1)
      postlist['body']["items"].each do |item|
        savedataDirPath = "#{@savedataDir}/#{@user_id}/posts/#{item['id']}_#{FSEscape.escape(item['title'])}/"
        next unless Dir.glob("#{savedataDirPath}").empty?
        sleep(@random.rand(1.0)+1)
        FileUtils.mkdir_p(savedataDirPath)
        next if item['body'] == nil
        case item['type']
        when "image"
          if item['body']['text'] != ""
            open("#{savedataDirPath}/article.txt", 'w') do |output|
              output.puts item['body']['text']
            end
          end
          if item['coverImageUrl']
            open("#{savedataDirPath}/cover.jpeg", 'wb') do |output|
              output.write(get_raw(item['coverImageUrl']))
            end
          end
          item['body']['images'].each_with_index do |filedata, i|
            open(sprintf("%s/%04d.%s",savedataDirPath,i,filedata['extension']), 'wb') do |output|
              output.write(get_raw(filedata['originalUrl']))
            end
          end
        when "article"
          if item['coverImageUrl']
            open("#{savedataDirPath}/cover.jpeg", 'wb') do |output|
              output.write(get_raw(item['coverImageUrl']))
            end
          end
          article = ""
          item['body']['blocks'].each_with_index do |data, i|
            case data['type']
            when "p"
              article = "#{article}#{data['text']}  \n"
            when "image"
              image_data = item['body']['imageMap'][data['imageId']]
              article = "#{article}#{sprintf("<img src=\"%04d.%s\" alt=\"\" width=\"%d\" height=\"%d\"><br>\n",i,image_data['extension'],image_data['width'],image_data['height'])}"
              open(sprintf("%s/%04d.%s",savedataDirPath,i,image_data['extension']),'wb') do |output|
                output.write(get_raw(image_data['originalUrl']))
              end
            else
              p "ERROR: undefined article data type (#{item['id']})"
            end
          end
          open("#{savedataDirPath}/article.md", 'w') do |output|
            output.puts article
          end
        when "text"
          if item['coverImageUrl']
            open("#{savedataDirPath}/cover.jpeg", 'wb') do |output|
              output.write(get_raw(item['coverImageUrl']))
            end
          end
          if item['body']['text'] != ""
            open("#{savedataDirPath}/article.txt", 'w') do |output|
              output.puts item['body']['text']
            end
          end
        when "file"
          if item['coverImageUrl']
            open("#{savedataDirPath}/cover.jpeg", 'wb') do |output|
              output.write(get_raw(item['coverImageUrl']))
            end
          end
          if item['body']['text'] != ""
            open("#{savedataDirPath}/article.txt", 'w') do |output|
              output.puts item['body']['text']
            end
          end
          item['body']['files'].each_with_index do |filedata, i|
            open(sprintf("%s/%s.%s",savedataDirPath,filedata['name'],filedata['extension']), 'wb') do |output|
              output.write(get_raw(filedata['url']))
            end
          end
        else
          p "ERROR: undefined post type (#{item['id']})"
        end
      end
      p postlist['body']['nextUrl']
      break unless postlist['body']['nextUrl']
      postlist = JSON.parse(get_raw(postlist['body']['nextUrl']))
    end
  end
  private
  def get_raw(url)
    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri.request_uri)
    req['origin'] = 'https://www.pixiv.net'
    req['cookie'] = @cookies.map{|k,v|
      "#{k}=#{v}"
    }.join(';')
    request_options = {
      use_ssl: uri.scheme
    }
    res = Net::HTTP.start(uri.host, uri.port, request_options) do |http|
      http.request(req)
    end
    res.body
  end
end

option={}
OptionParser.new do |opt|
    opt.on("-s", "--session=VALUE", "VALUE is PHPSESSID"){|v| option[:session] = v}
    opt.on("-i", "--id=VALUE", "Target User ID"){|v| option[:id] = v}
    opt.parse!(ARGV)
end

if option[:id] == nil then
    puts "target user id?"
    user_id = STDIN.gets.chomp
else
    user_id = option[:id]
end
if option[:session] == nil then
    puts "your PHPSESSID?"
    phpsessid = STDIN.gets.chomp
else
    phpsessid = option[:session]
end
cookies={
  #'personalization_id' => '"v1_hKYXzwe8wclGl/P4VPRwPw=="',
  'PHPSESSID' => phpsessid
}

fi = FanboxItems.new(user_id,cookies)
fi.get_all