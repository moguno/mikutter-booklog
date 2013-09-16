# -*- coding: utf-8 -*-

require 'net/http'
require 'uri'
require 'json'

Plugin.create :booklog do
  tab :booklog, "ブクログ" do
    set_icon "http://booklog.jp/favicon.ico"
    timeline :booklog
  end


  settings "ブクログ" do
    input "ユーザ名", :booklog_user
  end


  filter_message_background_color do |message, color|
    if message.message[:booklog]
      if color != UserConfig[:mumble_selected_bg]
        color = UserConfig[:mumble_basic_bg]
      end
    end

    [message, color]
  end


  def get_books
    def get(name, req)
      uri = URI.parse("http://api.booklog.jp/json/#{name}/?count=300&status=#{req}")
      json = Net::HTTP.get(uri)
      tmp = JSON.parse(json)
      tmp["books"].select { |book| book != [] }.each { |book| book["status"] = req }
    end

    result = []

    [2, 4, 1, 3].each { |req|
      result += get(UserConfig[:booklog_user], req)
    }

    result = get(UserConfig[:booklog_user], 0).select { |a| !(result.any? { |b| a["title"] == b["title"] }) } + result
  end


  def draw_books
    begin
      puts timeline(:booklog).clear

      books = get_books()
      status = {0 => "未分類", 2 => "読んでる", 4 => "積読", 1 => "読みたい", 3 => "読み終わった"}

      delta = 0

      books.reverse.each { |book|
        message = Message.new(:message => "[#{status[book["status"]]}]\n#{book["title"]}\n#{book["url"]}" , :system => true)
        message[:user] = User.new(:id => -3939,
                              :idname => "",
                              :name => "ブクログ本棚",
                              :profile_image_url => book["image"])
        message[:created] = Time.now + delta
        message[:modified] = Time.now + delta

        delta += 1

        message[:booklog] = true

        timeline(:booklog) << message
      }
    rescue => e
      message = Message.new(:message => e.to_s, :system => true)
      timeline(:booklog) << message

      Reserver.new(10) {
        draw_books
      }
    end
  end

  on_boot do |service|
    UserConfig.connect(:booklog_user) { |key, val, before_val, id|
      draw_books
    }

    if UserConfig[:booklog_user]
      begin
        draw_books
      rescue => e 
        error = e.to_s
      end
    else
      message = Message.new(:message => "設定画面でユーザ名を指定してください。", :system => true)
      timeline(:booklog) << message
    end
  end
end
