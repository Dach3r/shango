namespace :shango do
  namespace :encryption do
    desc "Print the encryption keys currently derived from secret_key_base, to pin them in the environment"
    task derived_keys: :environment do
      derive = ->(purpose) { Rails.application.key_generator.generate_key("shango/active_record_encryption/#{purpose}", 32).unpack1("H*") }
      Shango::EncryptionKeys::VARIABLES.each { |name, variable| puts "#{variable}=#{derive.call(name.to_s)}" }
    end

    desc "Re-encrypt every stored secret with the current primary key (append the new key after the old ones in ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY)"
    task rotate: :environment do
      count = 0
      [Variable, Collection, Folder, ApiRequest].each do |model|
        model.find_each(batch_size: 200) do |record|
          record.encrypt
          count += 1
        end
      end
      puts "Re-encrypted #{count} records."
    end
  end
end
