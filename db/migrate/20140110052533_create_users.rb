class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :screen_name
      t.text :recent_tweets
      t.text :friends

      t.timestamps
    end
  end
end
