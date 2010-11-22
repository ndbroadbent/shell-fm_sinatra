#!/usr/bin/ruby
# Sinatra server for shell-fm. (Can be run on the same machine as shell-fm).
# by Nathan Broadbent, 2010
# Published under the terms of the GNU General Public License (GPL).

# Borrowed logic from shell-fm.php by Matthias Goebl <matthias.goebl@goebl.net>

require 'rubygems'
require 'sinatra'
require 'yaml'

# Load config.
config = YAML.load_file(File.join(File.dirname(__FILE__), "config.yml"))
Host   = config["host"]
Port   = config["port"]

# for the correct handling of different statuses.
$status = "playing"
# for detecting pause/play
$last_remain = 0

# Titles for each command, to be displayed as html interface link text for each command
CmdTitles = {"skip" => "Next",
             "love" => "Love Track",
             "ban" => "Ban Track",
             "pause" => "Pause",
             "stop" => "Stop",
             "start" => "Start shell-fm",
             "kill" => "Kill shell-fm process"}

# Get the shellfm config and parse out the username with a Regex
sfm_config = File.open("#{ENV["HOME"]}/.shell-fm/shell-fm.rc", "r").read
Username   = sfm_config[/username ?= ?(.*)$/,1]

# -------------------------------------

# Get the index. Displays data from shell.fm and has a few commands to control the stream.
get '/' do
  @client_ip = @env['REMOTE_ADDR']    # Displays clients Host
  @flash = nil  # initialize a '@flash' var to display flash messages on the generated html

  # Gets track info from shell.fm network interface. If successful, continues
  if i = get_info
    i[:image_url] = nil if i[:image_url] == ""
    @station_link = link_to(i[:station_url], i[:station])
    @artist_link  = link_to(i[:artist_url],  i[:artist])
    @title_link   = link_to(i[:title_url],   i[:title])
    @album_link   = link_to(i[:album_url],   i[:album])
    @album_image  = i[:image_url] ? "<img src='#{i[:image_url]}'>" :
                    "<div id=\"noimage\">No Album Image.</div>"
  end

  @track_info = i
  @status = $status

  return params[:format] if params[:format]
  erb :index
end

# AJAX refreshes page elements with json data
get '/info.json' do
  if i = get_info
    i[:image_url] = nil if i[:image_url] == ""
    @station_link = link_to(i[:station_url], i[:station])
    @artist_link  = link_to(i[:artist_url],  i[:artist])
    @title_link   = link_to(i[:title_url],   i[:title])
    @album_link   = link_to(i[:album_url],   i[:album])
    @album_image  = i[:image_url] ? "<img src='#{i[:image_url]}'>" :
                    "<div id=\\\"noimage\\\">No Album Image.</div>"
                    # Double \\\ escaping for json parsing.
  return %Q{
    {
    "artist": "#{i[:artist]}",
    "title": "#{i[:title]}",
    "station_link": "#{@station_link}",
    "artist_link": "#{@artist_link}",
    "title_link": "#{@title_link}",
    "album_link": "#{@album_link}",
    "album_image": "#{@album_image}",
    "remain_s": #{i[:remain_s].to_i},
    "total_s": #{i[:total_s].to_i},
    "volume": #{i[:volume].to_i},
    "status": "#{$status}",
    "current_time": "#{hk_time_fmt}"
    }
  }
  else
    return false
  end
end

get '/cmd/:cmd' do
  # Do something depending on the command given (if any).
  case params[:cmd]
  when "pause", "skip", "love", "ban", "stop"
    shellfmcmd(params[:cmd])
    @flash = "Sent command: '#{CmdTitles[params[:cmd]]}'"
  when "start"
    `sudo pkill shell-fm 2>/dev/null`
    `sudo shell-fm`
    @flash = "(Re)started shell.fm process."
  when "kill"
    `sudo pkill shell-fm 2>/dev/null`
    @flash = "Stopped shell.fm process."
  when "play"
    shellfmcmd("play lastfm://#{params[:station]}")
    @flash = "Changed station to: '#{params[:station]}'"
  when "volume"
    shellfmcmd("volume #{params[:vol]}")
    @flash = "Set volume to: #{params[:vol]}%"
  end

  toggle_pause_status if params[:cmd] == "pause"

  return @flash
end


# Shows a page containing shell-fm.rc. (with password removed, and "<BR>" instead of "\n")
get '/config' do
  config = File.open("#{ENV["HOME"]}/.shell-fm/shell-fm.rc", "r").read
  # Replaces password line with "{{PASSWORD HIDDEN}}"
  config.gsub(/password *= *.*$/, "{{PASSWORD HIDDEN}}").gsub("\n", "<BR>")
end

# Shows a simple form to edit the alarms.yml file for the shellfm_lcd_console
get '/alarms' do
  @filename = File.join(File.dirname(__FILE__), "..", "shell-fm_lcd_console", "alarms.yml")
  @data = File.open(@filename, "r").read

  erb :simple_edit_form
end
# Shows a simple form to edit the alarms.yml file for the shellfm_lcd_console
post '/alarms' do
  @filename = File.join(File.dirname(__FILE__), "..", "shell-fm_lcd_console", "alarms.yml")
  File.open(@filename, "w") do |f|
    f.puts params['data']
  end
  redirect '/'
end

# for lcd4linux to retrieve display info.
get '/lcd_text/:key' do
  case $status
  when "stopped"
    case params[:key]
    when "artist"
      return "[STOPPED]"
    else
      return "-"
    end
  else
    case params[:key]
    when "artist"
      # update cached values only on an 'artist' call.
      if i = get_info
        $cached_title = i[:title]
        $cached_album = i[:album]
        $cached_duration = i[:duration]
        return i[:artist]
      end
    when "title"
      return $cached_title
    when "album"
      return $cached_album
    when "duration"
      return "[PAUSED]" if $status == "paused"
      return $cached_duration
    end
  end
end


# Runs a cmd via the shellfm network interface.
def shellfmcmd(cmd)
  t = TCPSocket.new(Host, Port)
  t.print cmd + "\n"
  info = t.gets(nil)
  t.close
  return info
  rescue
    puts "TCP error!"
end

# Fetches shell.fm info.
def get_info
  info = []
  # Try to get track info 2 times. (just in case of a random TCP error on the first attempt)
  2.times do
    info = shellfmcmd("info %S||%s||%A||%a||%T||%t||%L||%l||%I||%r||%f||%v||%R||%d")
    break if info
  end
  return false unless info
  info = info.split("||")
  k = %w(station_url station artist_url artist title_url title
         album_url album image_url remaining duration volume remain_s total_s)
  info_hash = {}
  info.each_with_index {|v, i| info_hash[k[i].to_sym] = v}
  info_hash[:remain_s] = info_hash[:remain_s].to_i
  info_hash[:total_s] = info_hash[:total_s].to_i

  if info_hash[:total_s] > 0
    # Change the status to playing if it is currently stopped.
    # (not if it is currently paused, obviously)
    $status = "playing" if $status == "stopped"

    if $last_remain == info_hash[:remain_s]
      $status = "paused"
    else
      $status = "playing"
    end

  else
    $status = "stopped"
  end

  $last_remain = info_hash[:remain_s]

  # Don't let remaining seconds be a negative value. (After pause detection logic..)
  info_hash[:remain_s] = 0 if info_hash[:remain_s] < 0

  return info_hash
end

# Rails-like link generator
def link_to(link, text)
  "<a href='#{link}'>#{text}</a>"
end

def toggle_pause_status
  if $status == "playing"
    $status = "paused"
  else
    $status = "playing"
  end
end

# Returns a list of the users radio-history
def radio_history
  if File.exist?("#{ENV["HOME"]}/.shell-fm/radio-history")
    File.open("#{ENV["HOME"]}/.shell-fm/radio-history", "r").collect {|x| x.strip}.uniq
  else
    return []
  end
end

# Returns a list of the users bookmarked stations
def bookmarks
  if File.exist?("#{ENV["HOME"]}/.shell-fm/bookmarks")
    return File.open("#{ENV["HOME"]}/.shell-fm/bookmarks", "r").collect {|h|
      h.split("=").collect {|k| k.strip }
    }.uniq
  else
    return []
  end
end

# Evo T20 is synced to UTC. HK time is UTC +8
def hk_time
  Time.now + 8*60*60
end

def hk_time_fmt
  hk_time.strftime("%Y-%m-%d %H:%M:%S")
end

