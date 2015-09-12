class CreateUploads < ActiveRecord::Migration
  def change
    create_table :uploads do |t|
      t.string :identifier, :null => false, :unique => true
      t.string :owner, :null => false
      t.datetime :expires
      t.integer :filesize, :null => false
      t.string :filehash, :null => false
      t.string :filename, :null => false
      t.string :content_type, :null => false

      t.timestamps null: false
    end
  end
end
