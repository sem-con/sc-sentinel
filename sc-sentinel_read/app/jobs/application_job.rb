class ApplicationJob < ActiveJob::Base
	require "cgi"
	require "date"
	queue_as :default
 
	def perform(rid)
		@ap = AsyncProcess.find_by_rid(rid)
		if !@ap.nil?
			@ap.update_attributes(status: 1)

			lat = CGI::parse(@ap.request)["lat"].first.to_f rescue nil
			long = CGI::parse(@ap.request)["long"].first.to_f rescue nil
			start_date = Date.parse(CGI::parse(@ap.request)["start"].first) rescue nil
			end_date = Date.parse(CGI::parse(@ap.request)["end"].first) rescue nil

			if lat.nil? or long.nil? or start_date.nil? or end_date.nil?
				@ap.update_attributes(status: -3)
			else
				# get list of files
				cmd = "python script/eomex_list.py -c " + lat.to_s + " " + long.to_s + " -begin " + start_date.to_s + " -end " + end_date.to_s
				retVal = `#{cmd}`
				file_list = JSON.parse(retVal.split("\n").last)["filelist"].map{ |x| x.split("/").last }
				@ap.update_attributes(file_list: file_list.to_json)

				cmd = "python script/eomex_download.py -c " + lat.to_s + " " + long.to_s + " -begin " + start_date.to_s + " -end " + end_date.to_s + " -o /data/sentinel_read -skipifexist"
				if system(cmd)
					all_files = Store.pluck(:item).map{|x| JSON.parse(x)["file"]}
					for my_file in file_list
						if all_files.include?(my_file)
							@my_store = Store.where("item like ?", "%#{my_file}")
							if @my_store.count == 1
								retVal = `sha256sum /data/sentinel_read/#{my_file} | head -c 64`
								if retVal.to_s != ""
									@my_store.first.update_attributes(item: {"file": my_file, "hash": retVal.to_s}.to_json)
								end
							end
						else
							retVal = `sha256sum /data/sentinel_read/#{my_file} | head -c 64`
							if retVal.to_s != ""
								@my_store = Store.new(item: {"file": my_file, "hash": retVal.to_s}.to_json)
								@my_store.save
							end
						end
					end
					@ap.update_attributes(status: 2)
				else
					@ap.update_attributes(status: -2)
				end
			end
		end

	end
end
