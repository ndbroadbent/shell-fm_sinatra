#!/usr/bin/ruby
# Sinatra server for shell-fm. (Can be run on the same machine as shell-fm).
# by Nathan Broadbent, 2010
# Published under the terms of the GNU General Public License (GPL).

# Borrowed heavily from shell-fm.php by Matthias Goebl <matthias.goebl@goebl.net>

require 'rubygems'
require 'sinatra'
require 'yaml'

config = YAML.load_file(File.join(File.dirname(__FILE__), "config.yml"))
Iface     = config["interface"]
PORT      = config["port"]

if config["ip_override"]
  IP = config["ip_override"] # (for testing)
else
  addr = `ifconfig #{Iface}`[/inet addr:(([0-9]{1,3}.)+)/,1]
  IP = addr ? addr.strip : nil
end

CmdTitles = {"skip" => "Next",
             "love" => "Love Track",
             "ban" => "Ban Track",
             "pause" => "Pause",
             "stop" => "Stop",
             "start" => "Start shell-fm",
             "kill" => "Kill shell-fm process"}

sfm_config = File.open("#{ENV["HOME"]}/.shell-fm/shell-fm.rc", "r").read
Username   = sfm_config[/username ?= ?(.*)$/,1]

# -------------------------------------

get '/' do
  @client_ip = @env['REMOTE_ADDR']
  @flash = nil
 
  case params[:cmd]
  when "pause", "skip", "love", "ban", "stop"
    shellfmcmd(params[:cmd])
    @flash = "Sent shell.fm the '#{CmdTitles[params[:cmd]]}' command."
  when "start"
    `sudo pkill shell-fm 2>/dev/null`
    `sudo aterm -e shell-fm`
    @flash = "(Re)started shell.fm process."
  when "kill"
    `sudo pkill shell-fm 2>/dev/null`     
    @flash = "Stopped shell.fm process."
  when "play"
    # convert "" to nil
    [:stationselect, :bookmarkselect, :stationurl].each do |k|
      params[k] = nil if params[k] == ""
    end
    station = params[:stationselect] || 
              params[:bookmarkselect] || 
              params[:stationurl]
    shellfmcmd("play lastfm://#{station}")
    @flash = "Changed shell.fm station to: '#{station}'"
  end  
  
  # Pause for our changes to work.
  sleep 4 if params[:cmd]
  
  if i = get_info
    @station_link = link_to(i[:station_url], i[:station])
    @artist_link  = link_to(i[:artist_url],  i[:artist])
    @title_link   = link_to(i[:title_url],   i[:title])
    @album_link   = link_to(i[:album_url],   i[:album])
    @album_image   = "<img src='#{i[:image_url]}'>"
  end
  @track_info = i
  erb :index  
end

def shellfmcmd(cmd) 
  return `echo "#{cmd}" | nc -w 1 #{IP} #{PORT} 2>&1`
end

def get_info
  info = shellfmcmd("info %S||%s||%A||%a||%T||%t||%L||%l||%I||%r||%f").split("||")
  if info.size <= 2
    info_hash = false
  else
    k = %w(station_url station artist_url artist title_url title
           album_url album image_url remaining duration)
    info_hash = {}
    info.each_with_index {|v, i| info_hash[k[i].to_sym] = v}
  end
  return info_hash
end

def link_to(link, text)
  "<a href='#{link}'>#{text}</a>"
end

def radio_history
  if File.exist?("#{ENV["HOME"]}/.shell-fm/radio-history")
    File.open("#{ENV["HOME"]}/.shell-fm/radio-history", "r").collect {|x| x.strip}.uniq
  else
    return []
  end    
end

def bookmarks
  if File.exist?("#{ENV["HOME"]}/.shell-fm/bookmarks")
    return File.open("#{ENV["HOME"]}/.shell-fm/bookmarks", "r").collect {|h|
      h.split("=").collect {|k| k.strip }
    }.uniq
  else
    return []
  end
end
