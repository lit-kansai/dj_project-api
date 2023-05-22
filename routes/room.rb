class RoomRouter < Base
  # ルームIDが必要なURIの場合 @env["room"] にルーム情報を入れる
  before "/:room_id*" do
    @env["room"] = Room.find_by(display_id: params[:room_id])
    halt not_found_error("Room not found") if @env["room"].nil?
  end

  # ルーム情報取得
  get "/:room_id" do
    send_json id: @env["room"]["display_id"], name: @env["room"]["name"], description: @env["room"]["description"],room_cooltime: @env["room"]["room_cooltime"]
  end

  #人気topリストを取得
  get "/:room_id/music/top" do
    if params[:limit].nil?
      limit_tracks = '12'
    else
      limit_tracks = params[:limit]
    end

    case @env["room"].provider
    when 'spotify'
      token = @env["room"].master.access_tokens.find_by(provider: 'spotify')
      return forbidden("provider is not linked") unless token
      spotify = MusicApi::SpotifyApi.new(token.access_token, token.refresh_token)
      res = spotify.get_top_music("37i9dQZEVXbKXQ4mDTEBXq",limit_tracks)
      send_json res
    when 'applemusic'
      token = @env["room"].master.access_tokens.find_by(provider: 'applemusic')
      return forbidden("provider is not linked") unless token
      applemusic = MusicApi::AppleMusicApi.new(token.access_token, token.music_user_token)
      res = applemusic.get_top_music("pl.043a2c9876114d95a4659988497567be",limit_tracks)
      send_json res
    else
      return not_found_error("playlist not found")
    end
  end

  # 楽曲検索
  get "/:room_id/music/search" do
    return bad_request("invalid parameters") unless has_params?(params, [:q])
    
    case @env["room"].provider
    when 'spotify'
      search_name = params[:q]
      token = @env["room"].master.access_tokens.find_by(provider: 'spotify')
      return forbidden("provider is not linked") unless token
      spotify = MusicApi::SpotifyApi.new(token.access_token, token.refresh_token)
      music_list = spotify.search(search_name)
      send_json music_list
    when 'applemusic'
      search_name = params[:q]
      token = @env["room"].master.access_tokens.find_by(provider: 'applemusic')
      return forbidden("provider is not linked") unless token
      applemusic = MusicApi::AppleMusicApi.new(token.access_token, token.music_user_token)
      music_list = applemusic.search(search_name)
      send_json music_list
    else
      forbidden("provider is not linked")
    end
  end

  # リクエスト送信
  post "/:room_id/request" do
    return bad_request("invalid parameters") unless has_params?(params, [:musics])

    letter = @env["room"].letters.build(
      radio_name: params[:radio_name] || "",
      message: params[:message] || "",
    )
    return internal_server_error("Failed to save") unless letter.save

    params[:musics].each do |music|
      token = @env["room"].master.access_tokens.find_by(provider: @env["room"].provider)
      next unless token

      case @env["room"].provider
      when 'spotify'
        spotify = MusicApi::SpotifyApi.new(token.access_token, token.refresh_token)
        track = spotify.get_track(music)
        next unless track
        m = letter.musics.build(
          provided_music_id: track[:id],
          name: track[:name],
          artist: track[:artists],
          album: track[:album],
          thumbnail: track[:thumbnail],
          duration: track[:duration],
        )
        m.save
        spotify.add_track_to_playlist(@env["room"].playlist_id, music)
      when 'applemusic'
        applemusic = MusicApi::AppleMusicApi.new(token.access_token, token.music_user_token)
        track = applemusic.get_track(music)
        next unless track
        m = letter.musics.build(
          provided_music_id: track[:id],
          name: track[:name],
          artist: track[:artists],
          album: track[:album],
          thumbnail: track[:thumbnail],
          duration: track[:duration],
        )
        m.save
        applemusic.add_track_to_playlist(@env["room"].playlist_id, music)
      else
        forbidden("provider is not linked")
      end
    end
    cool_time = @env["room"].room_cooltime
    response.headers["Retry-After"] = cool_time.to_s
    send_json(ok: true)
  end
end
