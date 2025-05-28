class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :name
      t.string :price
      t.string :link
      t.string :image

      t.timestamps
    end
  end
end
