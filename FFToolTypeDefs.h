/*
 *  FFToolTypeDefs.h
 *  FFTool
 *
 *  Created by zauhar on 28/1/09.
 *  Copyright 2009 ArtemisDiscovery LLC. All rights reserved.
 *
 */

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif


typedef enum { LINEAR, TRIGONAL, RESONANT, TETRAHEDRAL, SQUARE_PLANAR, TRIGONAL_BIPYRAMIDAL, OCTAHEDRAL, UNKNOWN } geometryType ;

typedef enum { SINGLE, DOUBLE, TRIPLE, AROMATIC, AMIDE, COORDINATION, ANY, UNDEFINED }  bondType ;


