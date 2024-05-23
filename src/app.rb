require 'time'
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

    get '/item/:id' do |id|
        query = "SELECT * FROM items 
                 WHERE id = ?"
        @item = db.execute(query, id).first
        query = "SELECT * FROM stock_size
        INNER JOIN size_id 
        ON stock_size.size_id = size_id.id WHERE stock_size.item_id = ?"
        @sizes = db.execute(query, id)
        erb :info
    end

    get '/item/:id/edit' do |id|
        query1 = "SELECT * FROM items WHERE id = ?"
        query2 = "SELECT * FROM stock_size WHERE item_id = ?"
        @item = db.execute(query1, id)
        @iteminfo = db.execute(query2, id)
        erb :edit
    end

    post '/edititem/:id' do |id|
        name = params["name"]
        price = params["price"]
        amountS = params["amountS"]
        amountM = params["amountM"]
        amountL = params["amountL"]
        query1 = "UPDATE items SET name = ?, price = ? WHERE id = ?"
        queryS = "UPDATE stock_size SET item_count = ? WHERE item_id = ? AND size_id = 1"
        queryM = "UPDATE stock_size SET item_count = ? WHERE item_id = ? AND size_id = 2"
        queryL = "UPDATE stock_size SET item_count = ? WHERE item_id = ? AND size_id = 3"
        db.execute(query1, name, price, id)
        db.execute(queryS, amountS, id)
        db.execute(queryM, amountM, id)
        db.execute(queryL, amountL, id)
        redirect "/item/#{id}/edit"
    end

    post '/item/:id/delete' do |id|
        db.execute("DELETE FROM items WHERE id = ?", id)
        db.execute("DELETE FROM stock_size WHERE item_id = ?", id)
        redirect "/"
    end

    post '/info/:id' do |itemid|
        size_picked = params["size"].to_i
        userid = session[:id]
        query = "INSERT INTO order_info (item_id, size) VALUES (?,?) RETURNING order_id"
        itemselected = db.execute(query, itemid, size_picked).first
        time = Time.now.to_s
        createorder = db.execute("INSERT INTO orders (id, timestamp, user_id) VALUES (?,?,?) RETURNING id", itemselected["order_id"], time, userid)
        redirect "/cart/#{createorder.first["id"]}"
    end

    get '/create' do
        erb :create
    end

    post '/createitem' do
        name = params["name"]
        price = params["price"]
        artwork_file = params["file"]
        File.open('public/img/' + artwork_file[:filename], "w") do |f|
            f.write(artwork_file[:tempfile].read)
        end

        image_path = "/img/" + artwork_file[:filename]

        itemid = db.execute("INSERT INTO items (name, price, image) VALUES (?, ?, ?) RETURNING id", name, price, image_path)
        db.execute("INSERT INTO stock_size VALUES (?, 1, 0)", itemid.first["id"])
        db.execute("INSERT INTO stock_size VALUES (?, 2, 0)", itemid.first["id"])
        db.execute("INSERT INTO stock_size VALUES (?, 3, 0)", itemid.first["id"])
        redirect '/'
    end

    get '/cart/:id' do |id|
        @order = db.execute("SELECT * FROM orders INNER JOIN order_info ON orders.id = order_info.order_id WHERE orders.id = ? ", id)
        erb :cart
    end
end