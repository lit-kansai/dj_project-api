class McUserPlaylistRouter < Base
  before "/:provider_name" do
    halt not_found_error("provider not found") unless params[:provider_name]
  end

  # ユーザーのプレイリスト一覧
  get "/" do
    list = []
    @env["user"].access_tokens.each do |access_token|
      case access_token.provider
      when 'spotify'
        list.concat(@env["spotify"].get_playlists) if @env["spotify"]
      when 'applemusic'
        list.concat(@env["applemusic"].get_playlists) if @env["applemusic"]
      end
    end
    send_json list
  end

  # ユーザーのプレイリスト一覧（プロバイダ別）
  get "/:provider_name" do
    case params[:provider_name]
    when 'spotify'
      return forbidden("provider is not linked") unless @env["spotify"]
      send_json @env["spotify"].get_playlists
    when 'applemusic'
      return forbidden("provider is not linked") unless @env["applemusic"]
      send_json @env["applemusic"].get_playlists
    else
      return bad_request("unsupported provider")
    end
  end

  # プレイリストの楽曲一覧
  get "/:provider_name/:playlist_id" do
    case params[:provider_name]
    when 'spotify'
      return forbidden("provider is not linked") unless @env["spotify"]
      res = @env["spotify"].get_playlist_tracks(params[:playlist_id])
      return not_found_error("playlist not found") unless res
      return send_json res
    when 'applemusic'
      return forbidden("provider is not linked") unless @env["applemusic"]
      res = @env["applemusic"].get_playlist_tracks(params[:playlist_id])
      return not_found_error("playlist not found") unless res
      return send_json res
    else
      return bad_request("unsupported provider")
    end
  end

  # プレイリスト作成
  post "/:provider_name" do
    return bad_request("invalid parameters") unless has_params?(params, [:name])
    case params[:provider_name]
    when 'spotify'
      return forbidden("provider is not linked") unless @env["spotify"]
      res = @env["spotify"].create_playlist(params[:name], params[:description])
      return send_json(ok: true, id: res['id'])
    when 'applemusic'
      return forbidden("provider is not linked") unless @env["applemusic"]
      res = @env["applemusic"].create_playlist(params[:name], params[:description])
      return send_json(ok: true, id: res["data"][0]["id"])
    else
      return bad_request("unsupported provider")
    end
  end
end
