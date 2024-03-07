class App < Sinatra::Base

    def db
        if @db == nil
            @db = SQLite3::Database.new('./db/db.db')
            @db.results_as_hash = true
        end
        return @db
    end

    get '/' do
        @items = db.execute("SELECT * FROM items")
        erb :index
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

    post '/info/:id' do |id|
        size_picked = params["size"]
        userid = 1
        item = 
    end
end