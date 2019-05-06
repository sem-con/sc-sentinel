class ApplicationJob < ActiveJob::Base
	require "cgi"
	require 'securerandom'
	queue_as :default
 
	def perform(rid)
        @ap = AsyncProcess.find_by_rid(rid)
        if !@ap.nil?
            @ap.update_attributes(status: 1)

            lat = CGI::parse(@ap.request)["lat"].first.to_s rescue nil
            long = CGI::parse(@ap.request)["long"].first.to_s rescue nil
            dir = CGI::parse(@ap.request)["directory"].first.to_s rescue nil
            prov_id = CGI::parse(@ap.request)["prov_id"].first.to_s rescue nil

            if lat.to_s == "" or long.to_s == "" or dir.to_s == "" or prov_id.to_s == ""
                @ap.update_attributes(status: -3)
                return
            end

            # check if directory exists
            if !File.directory?("/data/" + dir.to_s)
                @ap.update_attributes(status: -4)
                return
            end

            error_list = []
            # iterate over all files
            JSON.parse(@ap.file_list).each do |item|
                my_file = item["file"]
                my_hash = item["hash"]

                # check if hash value is valid
                cmd = "sha256sum /data/" + dir.to_s + "/" + my_file.to_s + " | head -c 64"
                current_hash = `#{cmd}`
                if current_hash != my_hash
                    error_list += [{"file": my_file, "error": "hash does not match"}]
                    next
                end

                # clip file
                clip_cmd = "python script/clip.py"
                clip_cmd += " -center " + lat.to_f.to_s + " " + long.to_f.to_s
                clip_cmd += " -infile /data/" + dir.to_s + "/" + my_file
                clip_cmd += " -outdir /data/sentinel_clip"
puts "CMD: " + clip_cmd.to_s
                if !system(clip_cmd)
                    error_list += [{"file": my_file, "error": "failed to clip image '" + my_file + "'"}]
                    next
                end

                new_file = my_file[0..-5] + ".png"
puts "NEW: " + new_file.to_s

                # create hash of clipped image
                cmd = "sha256sum /data/sentinel_clip/" + new_file.to_s + " | head -c 64"
                new_hash = `#{cmd}`
                if new_hash.to_s == ""
                    error_list += [{"file": new_file.to_s, "error": "failed to create hash from clipped image"}]
                    next
                end

                # write into Store
                @my_store = Store.new(item: {"file": new_file.to_s, "hash": new_hash.to_s}.to_json, prov_id: prov_id)
                @my_store.save
            end
            if error_list.count > 0
                @ap.update_attributes(status: -2, error_list: error_list.to_json)
            else
                @ap.update_attributes(status: 2)
            end
        end

	end
end
