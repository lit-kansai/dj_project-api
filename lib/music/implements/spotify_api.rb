require 'base64'

module MusicApi
  class SpotifyApi < ApiInterface
    API_ENDPOINT = 'https://api.spotify.com/v1/'

    SCOPES = ['playlist-read-private', 'playlist-read-collaborative', 'playlist-modify-public', 'playlist-modify-private']
    @@client_access_token=nil
    
    def initialize(access_token, refresh_token)
      @access_token = access_token
      @refresh_token = refresh_token

      @spotify_api = Faraday.new(:url => API_ENDPOINT)
      @spotify_api.headers['Authorization'] = "Bearer #{access_token}"
      @spotify_api.headers['Content-Type'] = 'application/json'
      @spotify_api.headers['Accept-Language'] = 'ja'
    end

    def me()
      res = @spotify_api.get 'me'
      if res.status == 401
        refresh_access_token
        res = @spotify_api.get 'me'
      end
      return nil unless res.status >= 200 && res.status < 300
      JSON.parse(res.body)
    end

    def search(query)
      res = @spotify_api.get 'search', { q: query, type: 'track' }
      if res.status == 401
        refresh_access_token
        res = @spotify_api.get 'search', { q: query, type: 'track' }
      end
      return nil unless res.status >= 200 && res.status < 300
      body = JSON.parse(res.body)
      body['tracks']['items'].map { |track|
        {
          id: track['uri'],
          artists: track['artists'].map { |artist| artist['name'] }.join(', '),
          album: track['album']['name'],
          thumbnail: track['album']['images'].first['url'],
          name: track['name'],
          duration: (track['duration_ms'] / 1000).ceil,
        }
      }
    end

    def get_track(track_id)
      res = @spotify_api.get "tracks/#{track_id.gsub('spotify:track:', '')}"
      if res.status == 401
        refresh_access_token
        res = @spotify_api.get "tracks/#{track_id.gsub('spotify:track:', '')}"
      end
      return nil unless res.status >= 200 && res.status < 300
      track = JSON.parse(res.body)
      {
        id: track['uri'],
        artists: track['artists'].map { |artist| artist['name'] }.join(', '),
        album: track['album']['name'],
        thumbnail: track['album']['images'].first['url'],
        name: track['name'],
        duration: (track['duration_ms'] / 1000).ceil,
      }
    end

    def get_playlists()
      @id = self.me()['id'] unless @id
      res = @spotify_api.get 'me/playlists'
      if res.status == 401
        refresh_access_token
        res = @spotify_api.get 'me/playlists'
      end
      return nil unless res.status >= 200 && res.status < 300
      body = JSON.parse(res.body)
      body['items'].select { |playlist|
        playlist['owner']['id'] == @id
      }.map { |playlist|
        image_url = playlist['images'].first['url'] if playlist['images'].first != nil
        {
          id: playlist['id'],
          name: playlist['name'],
          image_url: image_url,
          description: playlist['description'],
          provider: 'spotify'
        }
      }
    end

    def get_playlist(playlist_id)
      res = @spotify_api.get "playlists/#{playlist_id}"
      if res.status == 401
        refresh_access_token
        res = @spotify_api.get "playlists/#{playlist_id}"
      end
      return nil unless res.status >= 200 && res.status < 300
      body = JSON.parse(res.body)
      image_url = body['images'].first['url'] if body['images'].first != nil
      {
        id: body['id'],
        name: body['name'],
        description: body['description'],
        image_url: image_url,
        provider: 'spotify'
      }
    end

    def get_playlist_tracks(playlist_id)
      res = @spotify_api.get "playlists/#{playlist_id}/tracks"
      if res.status == 401
        refresh_access_token
        res = @spotify_api.get "playlists/#{playlist_id}/tracks"
      end
      body = JSON.parse(res.body)
      return nil unless res.status >= 200 && res.status < 300
      body['items'].map { |item|
        track = item['track']
        {
          id: track['uri'],
          artists: track['artists'].map { |artist| artist['name'] }.join(', '),
          album: track['album']['name'],
          thumbnail: track['album']['images'].first['url'],
          name: track['name'],
          duration: (track['duration_ms'] / 1000).ceil,
        }
      }
    end

    def get_top_music(playlist_id,limit_tracks)
      res = @spotify_api.get "playlists/#{playlist_id}/tracks?limit=#{limit_tracks}"
      if res.status == 401
        refresh_access_token
        res = @spotify_api.get "playlists/#{playlist_id}/tracks?limit=#{limit_tracks}"
      end
      body = JSON.parse(res.body)
      return nil unless res.status >= 200 && res.status < 300
      body['items'].map { |item|
        track = item['track']
        {
          id: track['uri'],
          artists: track['artists'].map { |artist| artist['name'] }.join(', '),
          album: track['album']['name'],
          thumbnail: track['album']['images'].first['url'],
          name: track['name'],
          duration: (track['duration_ms'] / 1000).ceil,
        }
      }
    end

    def create_playlist(name, description)
      id = me()["id"]
      data = {
        name: name,
        description: description ? description + " - Generated by DJ Gassi" : "Generated by DJ Gassi",
        public: false
      }
      res = @spotify_api.post "users/#{id}/playlists", JSON.generate(data)
      if res.status == 401
        refresh_access_token
        res = @spotify_api.post "users/#{id}/playlists", JSON.generate(data)
      end
      return nil unless res.status >= 200 && res.status < 300
      body = JSON.parse(res.body)
    end

    def add_track_to_playlist(playlist_id, track_id)
      data = {
        uris: [
          track_id
        ]
      }
      playlist_tracks = get_playlist_tracks(playlist_id)
      unless playlist_tracks.all? {|t| t[:id] != track_id }
        return nil
      end
      res = @spotify_api.post "playlists/#{playlist_id}/tracks", JSON.generate(data)
      if res.status == 401
        refresh_access_token
        res = @spotify_api.post "playlists/#{playlist_id}/tracks", JSON.generate(data)
      end
      return nil unless res.status >= 200 && res.status < 300
      body = JSON.parse(res.body)
    end

    def remove_track_from_playlist(playlist_id, track_id)
      data = {
        tracks: [
          {
            uri: track_id
          }
        ]
      }
      res = @spotify_api.run_request :delete, "playlists/#{playlist_id}/tracks", JSON.generate(data), {}
      if res.status == 401
        refresh_access_token
        res = @spotify_api.run_request :delete, "playlists/#{playlist_id}/tracks", JSON.generate(data), {}
      end
      return nil unless res.status >= 200 && res.status < 300
      body = JSON.parse(res.body)
    end

    def refresh_access_token()
      params = {
        grant_type: "refresh_token",
        refresh_token: @refresh_token
      }

      res = Faraday.new.post do |req|
        req.headers["Authorization"] = 'Basic ' + Base64.strict_encode64(ENV['SPOTIFY_API_CLIENT_ID'] + ':' + ENV['SPOTIFY_API_CLIENT_SECRET'])
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.url 'https://accounts.spotify.com/api/token'
        req.body = params.to_query
      end
      
      body = JSON.parse(res.body)
      @access_token = body['access_token']
      @spotify_api.headers['Authorization'] = "Bearer #{@access_token}"
    end

    class << self
      def get_oauth_url(redirect_uri)
        query = {
          response_type: 'code',
          client_id: ENV['SPOTIFY_API_CLIENT_ID'],
          scope: SCOPES.join(' '),
          redirect_uri: redirect_uri,
          state: SecureRandom.hex(16)
        }
        
        'https://accounts.spotify.com/authorize?' + query.to_param
      end

      def get_token_by_code(code, redirect_uri)
        if code === nil || code === ""
          raise ArgumentError, "invalid code"
        end

        params = {
          code: code,
          redirect_uri: redirect_uri,
          grant_type: 'authorization_code'
        }

        res = Faraday.new.post do |req|
          req.headers["Authorization"] = 'Basic ' + Base64.strict_encode64(ENV['SPOTIFY_API_CLIENT_ID'] + ':' + ENV['SPOTIFY_API_CLIENT_SECRET'])
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.url 'https://accounts.spotify.com/api/token'
          req.body = params.to_query
        end

        return JSON.parse(res.body)
      end
      
      def get_access_token()
        res = Faraday.new.post do |req|
          req.headers["Authorization"] = 'Basic ' + Base64.strict_encode64(ENV['SPOTIFY_API_CLIENT_ID'] + ':' + ENV['SPOTIFY_API_CLIENT_SECRET'])
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.url 'https://accounts.spotify.com/api/token'
          req.body = {:grant_type => :client_credentials}
        end
        body = JSON.parse(res.body)
        @@client_access_token = body["access_token"]
      end

      def search(search_keyword)

        if @@client_access_token.nil?||@@client_access_token===""
          get_access_token()
        end
        http1=Faraday.new(url: API_ENDPOINT)
        res = http1.get  do |req|
          req.params[:q] = search_keyword
          req.params[:type] = 'track'
          req.url 'search'
          req.headers['Content-Type'] = "application/json"
          req.headers['Authorization'] = "Bearer #{@@client_access_token}"
        end
        music_list = []
        music_text = JSON.parse(res.body)
        if music_text.dig("tracks","total").nil? || music_text.dig("tracks","total") == 0
          return music_list
        else
          music_text["tracks"]["items"].each do |music|
            music_list.push({
              "id" => music.dig("uri").to_s,
              "artists" => music.dig("album","artists",0,"name").to_s,
              "album" => music.dig("album","name").to_s,
              "thumbnail" => music.dig("album","images",0,"url").to_s,
              "name" => music.dig("name").to_s,
              "duration" => (music.dig("duration_ms")/1000).to_s,
              })
          end
        end
        return music_list
      end

      def get_track(track_id)
        if @@client_access_token.nil?||@@client_access_token===""
          get_access_token()
        end
        http1=Faraday.new(url: API_ENDPOINT)
        res = http1.get  do |req|
          req.url "tracks/#{track_id.gsub('spotify:track:', '')}"
          req.headers['Content-Type'] = "application/json"
          req.headers['Authorization'] = "Bearer #{@@client_access_token}"
        end
        return nil unless res.status >= 200 && res.status < 300
        track = JSON.parse(res.body)
        {
          id: track['uri'],
          artists: track['artists'].map { |artist| artist['name'] }.join(', '),
          album: track['album']['name'],
          thumbnail: track['album']['images'].first['url'],
          name: track['name'],
          duration: (track['duration_ms'] / 1000).ceil,
        }
      end
    end
  end
end
