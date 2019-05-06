FROM semcon/sc-base
MAINTAINER "Christoph Fabianek" christoph@ownyourdata.eu

WORKDIR /usr/src/app
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
		gdal-bin \
		python-pip \
		python-gdal && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY . .
CMD ["./script/init.sh"]

EXPOSE 3000