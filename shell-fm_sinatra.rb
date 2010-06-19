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
Iface     = config["interface"]
PORT      = config["port"]

# Basically, I have a few different machines that I run this on. (some thin clients with wlan)
# So I wanted an easy way to specify which IP to bind to, and my approach
# was to specify the network interface, and parse out the IP with 'ifconfig'.
# IP override allows me to manually set the IP, and not use an interface.
if config["ip_override"]
  IP = config["ip_override"] # (for testing)
else
  addr = `ifconfig #{Iface}`[/inet addr:(([0-9]{1,3}.)+)/,1]
  IP = addr ? addr.strip : nil
end

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
  @client_ip = @env['REMOTE_ADDR']    # Displays clients IP
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

  puts @title_link
  @track_info = i

  return params[:format] if params[:format]
  erb :index
end


get '/info.json' do
  if i = get_info
    i[:image_url] = nil if i[:image_url] == ""
    @station_link = link_to(i[:station_url], i[:station])
    @artist_link  = link_to(i[:artist_url],  i[:artist])
    @title_link   = link_to(i[:title_url],   i[:title])
    @album_link   = link_to(i[:album_url],   i[:album])
    @album_image  = i[:image_url] ? "<img src='#{i[:image_url]}'>" :
                    "<div id=\"noimage\">No Album Image.</div>"
  return %Q{
    {
    "artist": "#{i[:artist]}",
    "title": "#{i[:title]}",
    "station_link": "#{@station_link}",
    "artist_link": "#{@artist_link}",
    "title_link": "#{@title_link}",
    "album_link": "#{@album_link}",
    "album_image": "#{@album_image}",
    "remain_s": #{i[:remain_s]},
    "total_s": #{i[:total_s]},
    "volume": #{i[:volume].to_i}
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
    @flash = "Sent shell.fm the '#{CmdTitles[params[:cmd]]}' command."
  when "start"
    `sudo pkill shell-fm 2>/dev/null`
    `sudo shell-fm`
    @flash = "(Re)started shell.fm process."
  when "kill"
    `sudo pkill shell-fm 2>/dev/null`
    @flash = "Stopped shell.fm process."
  when "play"
    shellfmcmd("play lastfm://#{params[:station]}")
    @flash = "Changed shell.fm station to: '#{params[:station]}'"
  end
  return @flash
end


# Shows a page containing shell-fm.rc. (with password removed, and "<BR>" instead of "\n")
get '/config' do
  config = File.open("#{ENV["HOME"]}/.shell-fm/shell-fm.rc", "r").read
  # Replaces password line with "{{PASSWORD HIDDEN}}"
  config.gsub(/password *= *.*$/, "{{PASSWORD HIDDEN}}").gsub("\n", "<BR>")
end

# Runs a cmd via the shellfm network interface.
def shellfmcmd(cmd)
  t = TCPSocket.new(IP, PORT)
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
  return info_hash
end

# Rails-like link generator
def link_to(link, text)
  "<a href='#{link}'>#{text}</a>"
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

