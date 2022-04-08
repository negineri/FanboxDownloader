require 'net/http'
require 'json'
require 'uri'
require './escape'
require 'optparse'
require 'fileutils'

class FanboxItems
  def initialize(user_id,cookies)
    @user_id = user_id
    @cookies = cookies
    @query_parameters = {"userId"=>user_id, "maxPublishedDatetime"=>Time.now.strftime("%Y-%m-%d %H:%M:%S"), "maxId"=>9999999, "limit"=>10}
    @savedataDir = "data"
    @random = Random.new
  end
  def get_all
    postlist = JSON.parse(get_raw("https://api.fanbox.cc/post.listCreator?creatorId=#{@user_id}&limit=10"))
    while loop
      sleep(@random.rand(1.0)+1)
      postlist['body']["items"].each do |item|
        savedataDirPath = "#{@savedataDir}/#{@user_id}/posts/#{item['id']}_#{FSEscape.escape(item['title'])}/"
        next unless Dir.glob("#{savedataDirPath}").empty?
        sleep(@random.rand(1.0)+1)
        savedataDirPath = savedataDirPath.byteslice(0, 250).scrub('')
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
            when "header"
              article = "#{article}## #{data['text']}  \n"
            when "image"
              image_data = item['body']['imageMap'][data['imageId']]
              article = "#{article}#{sprintf("<img src=\"%04d.%s\"><br>\n",i,image_data['extension'])}"
              open(sprintf("%s/%04d.%s",savedataDirPath,i,image_data['extension']),'wb') do |output|
                output.write(get_raw(image_data['originalUrl']))
              end
            when "file"
              file_data = item['body']['fileMap'][data['fileId']]
              article = "#{article}#{sprintf("[%s](\"%s.%s\")  \n",file_data['name'],file_data['name'],file_data['extension'])}"
              open(sprintf("%s/%s.%s",savedataDirPath,file_data['name'],file_data['extension']),'wb') do |output|
                output.write(get_raw(file_data['url']))
              end
            when "url_embed"
              case item['body']['urlEmbedMap'][data['urlEmbedId']]['type']
              when 'fanbox.post'
                url_embed_postinfo = item['body']['urlEmbedMap'][data['urlEmbedId']]['postInfo']
                article = "#{article}[#{url_embed_postinfo['title']}](https://fanbox.cc/@#{url_embed_postinfo['creatorId']}/posts/#{url_embed_postinfo['id']}))  \n"
              when 'default'
                url_embed_url = item['body']['urlEmbedMap'][data['urlEmbedId']]['url']
                article = "#{article}[#{url_embed_url}](#{url_embed_url}))  \n"
              when 'html.card'
                url_embed_html = item['body']['urlEmbedMap'][data['urlEmbedId']]['html']
                article = "#{article}#{url_embed_html}  \n"
              when 'html'
                url_embed_html = item['body']['urlEmbedMap'][data['urlEmbedId']]['html']
                article = "#{article}#{url_embed_html}  \n"
              else
                p "ERROR: undefined url_embed data type \"#{item['body']['urlEmbedMap'][data['urlEmbedId']]['type']}\" (#{item['id']})"
              end
            when "embed"
              case item['body']['embedMap'][data['embedId']]['serviceProvider']
              when 'fanbox'
                # TODO
                embed_content_info = item['body']['embedMap'][data['embedId']]['contentId'].split('/')
                article = "#{article}#{embed_content_info = item['body']['embedMap'][data['embedId']]['contentId']}  \n"
              when 'twitter'
                # TODO
                p "IGNORE: undefined embed data type \"#{item['body']['embedMap'][data['embedId']]['serviceProvider']}\" (#{item['id']})"
              when 'youtube'
                # TODO
                embed_content_info = item['body']['embedMap'][data['embedId']]['contentId']
                article = "#{article}[https://youtu.be/#{embed_content_info}](https://youtu.be/#{embed_content_info}))  \n"
              else
                p "ERROR: undefined embed data type \"#{item['body']['embedMap'][data['embedId']]['serviceProvider']}\" (#{item['id']})"
              end
            else
              p "ERROR: undefined article data type \"#{data['type']}\" (#{item['id']})"
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
          p "ERROR: undefined post type \"#{item['type']}\" (#{item['id']})"
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
    req['origin'] = 'https://www.fanbox.cc'
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
    puts "target creator id?"
    user_id = STDIN.gets.chomp
else
    user_id = option[:id]
end
if option[:session] == nil then
    puts "your FANBOXSESSID?"
    phpsessid = STDIN.gets.chomp
else
    phpsessid = option[:session]
end
cookies={
  #'personalization_id' => '"v1_hKYXzwe8wclGl/P4VPRwPw=="',
  'FANBOXSESSID' => phpsessid
}

fi = FanboxItems.new(user_id,cookies)
fi.get_all