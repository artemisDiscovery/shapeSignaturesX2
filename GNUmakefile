include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = ShapeSignaturesX2
OBJC_LIBS = /usr/lib64/libcurl.so.4 /usr/lib64/libmysqlclient.so /usr/lib64/libobjc.so /lib64/libz.so
OBJCFLAGS = -lobjc -static -g -lz -lm  -I/usr/include/mysql -I/usr/include/curl  

ShapeSignaturesX2_OBJC_FILES = bondPath.m fragment.m rayTrace.m \
ctBond.m              histogramBundle.m       ShapeSignaturesX2.m \
ctNode.m              shapeSignatureX2.m \
ctTree.m              histogramGroupBundle.m  vector3.m \
elementCollection.m   histogramGroup.m        X2SignatureMapping.m \
flatSurface.m         histogram.m \
fragmentConnection.m  hitListItem.m libCURLUploader.m libCURLDownloader.m scoringScheme.m

include $(GNUSTEP_MAKEFILES)/tool.make



