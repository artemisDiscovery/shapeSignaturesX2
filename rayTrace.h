//
//  rayTrace.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "flatSurface.h"


@interface rayTrace : NSObject 
{
	// This class represents a single raytrace, including reflection positions, MEP at each reflection, 
	// and a "restart flag" indicating initiation of the trace at that reflection
@public
	
	int nAlloc ;
	int nReflections ;
	
	int nSegments ;
	
	int nInterFragmentSegments ;
	int nIntraFragmentSegments ;
	
	double *reflectX, *reflectY, *reflectZ ;
	double *reflectMEP ;
	
	int *reflectPartition ;
	
	BOOL *reflectAtStart ;
	
	flatSurface *theSurface ;
	
	// For convenience sake:
	
	double minMEP, maxMEP  ;
	
	double maxSegmentLength ;
	
	double maxTwoSegmentLength ;
	
}

- (id) initWithSurface:(flatSurface *)surf andNumSegments:(int)nSegments cullingEnabled:(BOOL)cull
		skipSelfIntersectingSurface:(BOOL)ss insideTrace:(BOOL)inside randomizationAngle:(double)randAngle ;
		
- (double) addReflectionAtPosition:(double [])pos withMEP:(double)m inPartition:(int)p atStart:(BOOL)strt ;


//- (NSArray *) partition2DHistogramsWithLengthDelta:(double)ldel andMEPDelta:(double)mepDel ; 
//- (NSArray *) partition1DHistogramsWithLengthDelta:(double)ldel ;

- (void) printRaytraceToFile:(NSString *)path ;



@end
