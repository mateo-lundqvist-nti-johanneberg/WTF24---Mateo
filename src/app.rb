class App < Sinatra::Base

    enable :sessions

    def db
        if @db == nil
            @db = SQLite3::Database.new('./db/db.db')
            @db.results_as_hash = true
        end
        return @db
    end

    get '/' do
        session[:user_id] = 1
        @items = db.execute("SELECT * FROM items")
        erb :index
    end

    get '/login' do 
        error_message = session.delete(:error_message)

        erb :login, locals: { error_message: error_message }
    end

    post '/login' do 
        username = params["username"]
        password = params["password"]
    
        user = db.execute('SELECT * FROM users WHERE name = ?', username).first

        if user.nil?
            session[:error_message] = "User is not found"
            redirect "/login"
        end
    
        stored_password_hash = user['pass']
    
        if BCrypt::Password.new(stored_password_hash) == password
            session[:id] = user['id'] 
            session[:username] = username
            session[:role] = user['role']

            redirect "/"

        else 
            session[:error_message] = "Password is incorrect"
            redirect '/login'        
        end

        
    end

    post '/logout' do
        session.clear
        redirect "/"
    end

    get '/register' do
        error_message = session.delete(:error_message)
        erb :register, locals: { error_message: error_message }
    end

    post '/register' do

        username = params["username"]
        password = params["password"]
        password_confirm = params["confirm_password"]
        mail = params["mail"]
        phone = params["phone"]
        address = params["address"]

        if password != password_confirm
            session[:error_message] = "Passwords do not match"
            redirect '/register'
        end

        password_hash = BCrypt::Password.create(password)

        role = "admin"

        begin
            query = 'INSERT INTO users (name, mail, address, phone, pass, role) VALUES (?, ?, ?, ?, ?, ?)'
            result = db.execute(query, username, mail, address, phone, password_hash, role).first
        rescue SQLite3::ConstraintException => e
            session[:error_message] = "Mail is already taken"
            redirect '/register'

        rescue => e
            session[:error_message] = "An error occurred while processing your request"
            redirect '/register'
        end
        session[:id] = db.last_insert_row_id
        session[:role] = role
        session[:username] = username

        puts(session[:id])

        redirect "/"

    end

    get '/admin' do

    end

    get '/item/:id' do |id|
        query = "SELECT * FROM items 
                 INNER JOIN stock_size
                 ON stock_size.item_id = items.id 
                 INNER JOIN size_id 
                 ON stock_size.size_id = size_id.id 
                 WHERE items.id = ?"
        @items = db.execute(query, id)
        erb :info
    end

    post '/info/:id' do |itemid|
        size_picked = params["size"].to_i
        userid = session[:id]
        query = "INSERT INTO order_info (item_id, size) VALUES (?,?) RETURNING order_id"
        @itemselected = db.execute(query, itemid, size_picked).first
        p @itemselected
        createorder = db.execute("INSERT INTO orders (id, timestamp, user_id) VALUES (?,?,?)", @itemselected["order_id"], 1, userid)
        redirect "/cart/#{userid}"
    end

    get '/cart/:id' do |id|
        erb :cart
    end
end