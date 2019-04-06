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
			# start_date = Date.parse("2018-07-01")
			# end_date = Date.parse("2018-07-06")

			if lat.nil? or long.nil? or start_date.nil? or end_date.nil?
				@ap.update_attributes(status: -2)
			else
				lat = 47.6089
				long = 13.78267
				cmd = "python script/eomex_dl.py -c " + lat.to_s + " " + long.to_s + " -begin " + start_date.to_s + " -end " + end_date.to_s + " -o /data/" + rid.to_s + " -skipifexist"
				if system(cmd)
					generateHash = "cd /data/" + rid.to_s + " && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | head -c 64"
					retVal = `#{generateHash}`
					@ap.update_attributes(status: 2, file_hash: retVal.to_s)
				else
					@ap.update_attributes(status: -1)
				end
			end
		end

	end
end
