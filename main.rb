require 'sinatra'
require 'json'
require 'securerandom'
require 'net/http'

# Настройки
enable :sessions
set :session_secret, SecureRandom.hex(64)

USERS = []
POSTS = []

# --- ФУНКЦИЯ РЕАЛЬНОЙ ПОГОДЫ ---
def get_real_weather(city_name)
  api_key = "bc93a95f3484a2080884c08da724b368"

  url = "https://api.openweathermap.org/data/2.5/weather?q=#{city_name}&appid=#{api_key}&units=metric&lang=ru"

  begin
    uri = URI(url)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    if data["cod"] == 200
      {
        city: data["name"],
        temp: data["main"]["temp"].round,
        condition: data["weather"][0]["description"],
        wind: data["wind"]["speed"]
      }
    else
      nil
    end
  rescue
    nil
  end
end

helpers do
  def current_user
    session[:user_id]
  end

  def logged_in?
    !current_user.nil?
  end

  def find_user(username)
    USERS.find { |u| u[:username] == username }
  end
end

# --- КОНТРОЛЛЕРЫ ---

get '/' do
  redirect '/login' unless logged_in?

  @user = find_user(current_user)
  @posts = POSTS.reverse

  if @user[:token]
    @weather = get_real_weather("Rostov-On-Don")
  else
    @weather = nil
  end

  erb :index
end

get '/login' do
  erb :login
end

post '/register' do
  username = params[:username]
  password = params[:password]

  if find_user(username)
    @error = "Пользователь уже существует"
    erb :login
  else
    token = SecureRandom.hex(16)
    USERS << { username: username, password: password, token: token }
    session[:user_id] = username
    redirect '/'
  end
end

post '/login' do
  user = USERS.find { |u| u[:username] == params[:username] && u[:password] == params[:password] }
  if user
    session[:user_id] = user[:username]
    redirect '/'
  else
    @error = "Неверные данные"
    erb :login
  end
end

get '/logout' do
  session.clear
  redirect '/login'
end

post '/posts' do
  redirect '/login' unless logged_in?
  POSTS << {
    id: POSTS.size + 1,
    author: current_user,
    content: params[:content],
    likes: [],
    comments: [],
    time: Time.now
  }
  redirect '/'
end

post '/posts/:id/like' do
  return unless logged_in?
  post = POSTS.find { |p| p[:id] == params[:id].to_i }
  if post
    if post[:likes].include?(current_user)
      post[:likes].delete(current_user)
    else
      post[:likes] << current_user
    end
  end
  redirect '/'
end

post '/posts/:id/comment' do
  return unless logged_in?
  post = POSTS.find { |p| p[:id] == params[:id].to_i }
  if post && !params[:body].strip.empty?
    post[:comments] << { author: current_user, body: params[:body] }
  end
  redirect '/'
end

__END__

@@ layout
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <title>Блог + Real Weather</title>
  <style>
    body { font-family: 'Segoe UI', sans-serif; background: #e9ecef; margin: 0; padding: 20px; }
    .main-wrapper { display: flex; gap: 20px; max-width: 900px; margin: 0 auto; align-items: flex-start; }
    .sidebar { flex: 1; min-width: 250px; display: flex; flex-direction: column; gap: 20px; }
    .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
    .weather-widget { background: linear-gradient(135deg, #74b9ff, #0984e3); color: white; text-align: center; }
    .weather-temp { font-size: 3em; font-weight: bold; margin: 10px 0; }
    .feed { flex: 2; }
    .post { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.05); margin-bottom: 20px; }
    .post-header { display: flex; justify-content: space-between; color: #888; font-size: 0.9em; margin-bottom: 10px; }
    .actions { margin-top: 15px; border-top: 1px solid #eee; padding-top: 10px; }
    button { cursor: pointer; border: none; border-radius: 5px; padding: 8px 12px; }
    .btn-like { background: #f1f2f6; color: #555; }
    .btn-like.liked { background: #ff7675; color: white; }
    .btn-primary { background: #00cec9; color: white; font-weight: bold; }
    input, textarea { width: 100%; padding: 10px; border: 1px solid #dfe6e9; border-radius: 5px; box-sizing: border-box; margin-bottom: 10px; }
    .comment { background: #f8f9fa; padding: 8px 12px; border-radius: 8px; margin-top: 8px; font-size: 0.95em; }
    .login-container { max-width: 400px; margin: 50px auto; background: white; padding: 30px; border-radius: 10px; text-align: center; }
  </style>
</head>
<body>
  <%= yield %>
</body>
</html>

@@ login
<div class="login-container">
  <h1>Вход</h1>
  <% if @error %><p style="color:red"><%= @error %></p><% end %>
  <form action="/login" method="POST">
     <input type="text" name="username" placeholder="Логин" required>
     <input type="password" name="password" placeholder="Пароль" required>
     <button class="btn-primary" style="width:100%">Войти</button>
  </form>
  <p>или</p>
  <form action="/register" method="POST">
    <input type="text" name="username" placeholder="Новый логин" required>
    <input type="password" name="password" placeholder="Новый пароль" required>
    <button class="btn-primary" style="width:100%; background:#0984e3">Регистрация</button>
  </form>
</div>

@@ index
<div class="main-wrapper">
  <div class="sidebar">
    <div class="card">
      <h3>👤 <%= @user[:username] %></h3>
      <a href="/logout">Выйти</a>
    </div>

    <% if @weather %>
    <div class="card weather-widget">
      <h3>Погода сейчас</h3>
      <div style="font-size: 1.2em; opacity: 0.9;"><%= @weather[:city] %></div>
      <div class="weather-temp"><%= @weather[:temp] %>°C</div>
      <div style="font-size: 1.1em; text-transform: capitalize;"><%= @weather[:condition] %></div>
      <div style="margin-top: 10px; font-size: 0.9em; opacity: 0.8;">
        Ветер: <%= @weather[:wind] %> м/с
      </div>
    </div>
    <% else %>
      <div class="card" style="color: red;">Не удалось загрузить погоду (проверьте API ключ)</div>
    <% end %>
  </div>

  <div class="feed">
    <div class="card">
      <form action="/posts" method="POST">
        <textarea name="content" rows="3" placeholder="Что нового?" required></textarea>
        <div style="text-align: right;"><button class="btn-primary">Опубликовать</button></div>
      </form>
    </div>

    <% @posts.each do |post| %>
      <div class="post">
        <div class="post-header">
          <span><strong>@<%= post[:author] %></strong></span>
          <span><%= post[:time].strftime("%H:%M") %></span>
        </div>
        <div><%= post[:content] %></div>
        <div class="actions">
          <form action="/posts/<%= post[:id] %>/like" method="POST" style="display:inline;">
             <% is_liked = post[:likes].include?(current_user) %>
             <button class="btn-like <%= 'liked' if is_liked %>">❤ <%= post[:likes].size %></button>
          </form>
        </div>
        <% post[:comments].each do |c| %>
          <div class="comment"><b><%= c[:author] %></b>: <%= c[:body] %></div>
        <% end %>
        <form action="/posts/<%= post[:id] %>/comment" method="POST" style="margin-top:10px; display:flex; gap:5px;">
           <input type="text" name="body" placeholder="Коммент..." required style="margin:0;">
           <button class="btn-primary">OK</button>
        </form>
      </div>
    <% end %>
  </div>
</div>
