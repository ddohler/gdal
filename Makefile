PROJ4 = proj4
GDAL = gdal
EMMAKE ?= emmake
EMCC ?= emcc
EMCONFIGURE ?= emconfigure
EMCONFIGURE_JS ?= 0
GDAL_EMCC_CFLAGS := -msse -Oz
PROJ_EMCC_CFLAGS := -msse -Oz
EXPORTED_FUNCTIONS = "[\
  '_GDALAllRegister',\
  '_GDALOpen',\
  '_GDALGetRasterXSize',\
  '_GDALGetRasterYSize',\
  '_GDALGetRasterCount',\
  '_GDALGetProjectionRef',\
  '_GDALGetGeoTransform',\
  '_OSRNewSpatialReference',\
  '_OCTNewCoordinateTransformation',\
  '_OCTTransform',\
  '_GDALTranslate',\
  '_GDALTranslateOptionsNew',\
  '_GDALTranslateOptionsFree'\
]"

export EMCONFIGURE_JS

include gdal-configure.opt

.PHONY: clean

########
# GDAL #
########
gdal: gdal.js

gdal.js: $(GDAL)/libgdal.a
	EMCC_CFLAGS="$(GDAL_EMCC_CFLAGS)" $(EMCC) $(GDAL)/libgdal.a $(PROJ4)/src/.libs/libproj.a -o gdal.js -s EXPORTED_FUNCTIONS=$(EXPORTED_FUNCTIONS)

$(GDAL)/libgdal.a: proj4 gdalconfig
	cd $(GDAL) && EMCC_CFLAGS="$(GDAL_EMCC_CFLAGS)" EMCC_DEBUG=1 $(EMMAKE) make lib-target

gdalconfig: $(GDAL)/config.status

# TODO: Pass the configure params more elegantly so that this uses the
# EMCONFIGURE variable
$(GDAL)/config.status: $(GDAL)/configure
	# PROJ4 needs to be built natively as part of the GDAL configuration process,
	# but we don't want to nuke the Emscripten build if it happens to have been
	# built first, so we need to copy it and then restore it once the GDAL
	# configuration process is complete.
	cp -R $(PROJ4) proj4_bak
	cd $(PROJ4) && git clean -X -d --force .
	cd $(PROJ4) && ./autogen.sh
	cd $(PROJ4) && ./configure
	cd $(PROJ4) && make
	cd $(GDAL) && emconfigure ./configure $(GDAL_CONFIG_OPTIONS)
	rm -rf $(PROJ4)
	mv proj4_bak $(PROJ4)

##########
# PROJ.4 #
##########
proj4: $(PROJ4)/src/.libs/libproj.a

$(PROJ4)/src/.libs/libproj.a: proj4config
	cd $(PROJ4) && EMCC_CFLAGS="$(PROJ_EMCC_CFLAGS)" $(EMMAKE) make

proj4config: $(PROJ4)/config.status

$(PROJ4)/config.status: $(PROJ4)/configure
	cd $(PROJ4) && $(EMCONFIGURE) ./configure --enable-shared=no --enable-static --without-mutex

$(PROJ4)/configure: $(PROJ4)/autogen.sh
	cd $(PROJ4) && ./autogen.sh

# There seems to be interference between a dependency on config.status specified
# in the original GDAL Makefile and the config.status rule above that causes
# `make clean` from the gdal folder to try to _build_ gdal before cleaning it.
clean:
	cd $(PROJ4) && git clean -X -d --force .
	cd $(GDAL) && git clean -X -d --force .
	rm -f gdal.js.mem
	rm -f gdal.js
