//
//  flatSurface.h
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/19/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include "platform.h"

#ifdef LINUX
#import <Foundation/Foundation.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "ctTree.h"
#import "elementCollection.h" 
#include <math.h>
#include <stdlib.h>

typedef enum {CONTACT, REENTRANT, SADDLE } elemType ;

@interface flatSurface : NSObject 
{
	// This class represents a surface of flat elements
	
	// I'll try to make this simple and keep everything together (i.e. I won't define extra object classes
	// just for the sake of being object-y )
	
	// Source tree
	
@public
	
	ctTree *theTree ;
	
	int nVertices ;
	
	BOOL haveDeadSurface ;
	
	double *vertexX, *vertexY, *vertexZ, *vertexMEP ;
	
	// Elements 
	
	int nElements, nContact ;
	
	int *elemVertex0, *elemVertex1, *elemVertex2 ;
	
	double *normX, *normY, *normZ ;
	
	// Accessory data for raytrace computation
	
	double **axisU, **axisV ;
	
	elemType *type ;
	
	int *nAtomsForElement ;
	
	int **elementAtoms ;
	
	// Active? (only used if site atoms defined)
		
	BOOL *elemActive ;
	
	// Involved in potential self-intersection?
		
	BOOL *elemSelfIntersecting ;
	
	// We can use fragmentinformation to assign element to partition
	
	int *partitionForElement ;
	
	// I guess I need this
	
	int *siteElems ;
	int nSiteElems ;
	
	
	// To support overlay of grid
	
	int nX, nY, nZ ;

	double xMin, yMin, zMin ;
	
	double delta ;

	elementCollection ****gridToElem ;
	

}

- (id) initWithFlatFile: (NSString *)f andTree: (ctTree *) t haveFragmentFile:(BOOL) customFrag andGridSpacing:(double)d ;

- (void) position:(double [])p andMEP:(double *)mep inElement:(int)idx forR:(double)r S:(double)s ;

- (BOOL) assignNearestIntersectionToElem:(int *)interElem 
                andPoint:(double [])interPoint andR:(double *)R andS:(double *)S andMEP:(double *)m
                usingStart:(double [])start 
                andDirection:(double [])dir fromElementWithIndex:(int)index
                withRayTraceType:(BOOL)inner ;

- (void) assignReflectionDirectionTo:(double [])reflectDirect
					usingDirection:(double [])direction andRandomization:(double)randAngle 
					atIntersectElem:(int)elem ;
					
+ (void) clearPartitionsForVote ;
+ (void) addVoteForPartition:(int)p ;
+ (int) winningPartition ;

+ (double) determinant:(double *[3][3])mat ;

+ (void) resizeTestIntersect:(int)n ;

@end
