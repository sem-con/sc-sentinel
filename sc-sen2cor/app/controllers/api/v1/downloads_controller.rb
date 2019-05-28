module Api
    module V1
        class DownloadsController < ApiController
            def download
                file_list = []
                Store.pluck(:item).map{|x| file_list << JSON(x)["file"]}
                if file_list.include?(params[:id].to_s)
                    send_file("/data/sen2cor/" + params[:id].to_s,
                              filename: params[:id].to_s,
                              type: "image/jp2")
                else
                    render json: { "error": "not found" },
                           status: 404
                end
            end
        end
    end
end