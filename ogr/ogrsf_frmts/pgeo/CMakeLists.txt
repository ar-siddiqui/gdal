add_gdal_driver(
  TARGET ogr_PGeo
  SOURCES ogr_pgeo.h ogrpgeodatasource.cpp ogrpgeodriver.cpp ogrpgeolayer.cpp ogrpgeotablelayer.cpp
          ogrpgeoselectlayer.cpp
  BUILTIN)
gdal_standard_includes(ogr_PGeo)
target_include_directories(ogr_PGeo PRIVATE ${GDAL_VECTOR_FORMAT_SOURCE_DIR}/openfilegdb)
gdal_target_link_libraries(ogr_PGeo PRIVATE ODBC::ODBC)
