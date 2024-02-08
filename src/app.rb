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
        @iteminfo = db.execute("SELECT * FROM items WHERE id = ?", id).first
        @sizeinfo = db.execute("SELECT * FROM stock_size WHERE item_id = ?", id).first
        @sizelist = db.execute("SELECT * FROM size_id")
        erb :info
    end
    
end