//
//  rayTrace.m
//  shapeSignaturesX
//
//  Created by Randy Zauhar on 9/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "rayTrace.h"
#include <math.h>
#include <stdlib.h>


@implementation rayTrace

- (id) initWithSurface:(flatSurface *)surf andNumSegments:(int)nSeg cullingEnabled:(BOOL)cull
skipSelfIntersectingSurface:(BOOL)ss insideTrace:(BOOL)inside randomizationAngle:(double)randAngle scaleFactor:(double)sf
	{
		self = [ super init ] ;
		
		theSurface = surf ;
	
		scaleFactor = sf ;
		
		unsigned long int divisor = 2147483648 ;
		
		int i ;
		
		BOOL needsInitialized = YES ;
		
		int badIntersectCount = 0 ;
		int nSelfIntSkipIntersect = 0 ;
		
		int nCull = 0 ;
		
		int theElem, intersectElem ;
		
		double startPoint[3], intersectPoint[3] ;
		
		double direction[3], reflectDirect[3] ;
		
		double r, s, mep ;
		
		minMEP = 1.e12 ;
		maxMEP = -1.e12 ;
		
		double minMEPX, minMEPY, minMEPZ ;
		int minMEPElement ;
		
		
		maxSegmentLength = 0. ;
		maxTwoSegmentLength = 0. ;
		
		
		nAlloc = nSeg ;
		
		reflectX = (double *) malloc( nAlloc * sizeof( double ) ) ;
		reflectY = (double *) malloc( nAlloc * sizeof( double ) ) ;
		reflectZ = (double *) malloc( nAlloc * sizeof( double ) ) ;
		
		reflectMEP = (double *) malloc( nAlloc * sizeof( double ) ) ;
		
		reflectPartition = (int *) malloc( nAlloc * sizeof( int ) ) ;
		
		reflectAtStart = (BOOL *) malloc( nAlloc * sizeof( BOOL ) ) ;
		
		[ flatSurface resizeTestIntersect:surf->nElements ] ;
		
		nReflections = 0 ;
		nSegments = 0 ;
		
		nInterFragmentSegments = 0 ;
		nIntraFragmentSegments = 0 ;
		
		double prevSegmentLength = 0. ;
		
		while( nSegments < nSeg )
			{
				if( needsInitialized )
					{
						// Pick element
						
						// If no "dead surface" just use all first nContact elements; if dead surface
						// need to pick from the siteElements (not just contact elements, as that has proved restrictive)
						
						if( surf->haveDeadSurface == YES )
							{
								i = (int) (((double)random()/divisor) * surf->nSiteElems ) ;
								theElem = surf->siteElems[i] ;
							}
						else
							{
								// DO I need to ever restrict to contact
								theElem = (int) (((double)random()/divisor) * surf->nContact ) ;
							}
							
						r = s = 0.25 ;
						
						[ surf position:startPoint andMEP:&mep inElement:theElem forR:r S:s ] ;
						
						if( mep < minMEP ) minMEP = mep ;
						if( mep > maxMEP ) maxMEP = mep ;
						
						// Add this reflection 
						
						[ self addReflectionAtPosition:startPoint withMEP:mep inPartition:surf->partitionForElement[theElem]
									atStart:YES ] ;
									
						direction[0] = surf->normX[theElem] ;
						direction[1] = surf->normY[theElem] ;
						direction[2] = surf->normZ[theElem] ;
						
						if( inside == YES )
							{
								direction[0] = -direction[0] ;
								direction[1] = -direction[1] ;
								direction[2] = -direction[2] ;
							}
							
						needsInitialized = NO ;
						
						prevSegmentLength = 0. ;
					}
					
				// Get next intersection
				
				[ surf assignNearestIntersectionToElem:&intersectElem 
					andPoint:intersectPoint andR:&r andS:&s andMEP:&mep
					usingStart:startPoint 
					andDirection:direction fromElementWithIndex:theElem
					withRayTraceType:inside ] ;
					
				if( mep < minMEP ) 
				{
					minMEP = mep ;
					minMEPX = intersectPoint[0] ;
					minMEPY = intersectPoint[1] ;
					minMEPZ = intersectPoint[2] ;
					minMEPElement = intersectElem ;
				}
					
				if( mep > maxMEP ) maxMEP = mep ;

				if( intersectElem < 0 )
						{
							needsInitialized = TRUE ;
							//fprintf( stderr, "MISS INTERSECTION, count = %d\n", count ) ;
							++badIntersectCount ;
							continue ;
						}
			
				// If exterior trace, assume site in effect - we can only intersect an active element
			
				if ( inside == NO ) {
					if ( surf->elemActive[intersectElem] == NO ) {
						needsInitialized = TRUE ;
						++badIntersectCount ;
						continue ;
					}
				}
						
				// Check for startPoint and intersectPoint too close together - may be 
				// caused by "needle-like" element
				
				double dx = startPoint[0] - intersectPoint[0] ;
				double dy = startPoint[1] - intersectPoint[1] ;
				double dz = startPoint[2] - intersectPoint[2] ;
				
				double d = sqrt( dx*dx + dy*dy + dz*dz ) ;
				
				if( d < 0.001 )
					{
						needsInitialized = TRUE ;
						++badIntersectCount ;
						continue ;
					}
				
				/* Take this out for now
				if( ss == YES && surf->elemSelfIntersecting[intersectElem] == YES )
						{
							needsInitialized = TRUE ;
							//fprintf( stderr, "MISS INTERSECTION, count = %d\n", count ) ;
							++nSelfIntSkipIntersect ;
							continue ;
						}
				*/
			
				// If culling enabled... only allowed for interior trace

				if( inside == YES && cull == YES )
					{
						// Check if theElem and intersectElem share atoms
						
						BOOL disagree = NO ;
						int nAtomsMin ;
						
						if( surf->nAtomsForElement[theElem] < surf->nAtomsForElement[intersectElem] )
							{
								nAtomsMin = surf->nAtomsForElement[theElem] ;
							}
						else
							{
								nAtomsMin = surf->nAtomsForElement[intersectElem] ;
							}
							
						int jAtom ;
						
						for( jAtom = 0 ; jAtom < nAtomsMin ; ++jAtom )
							{
								if( surf->elementAtoms[theElem][jAtom] != surf->elementAtoms[intersectElem][jAtom] )
									{
										disagree = YES ;
										break ;
									}
							}
						
						if( disagree == NO )
								{
									needsInitialized = TRUE ;
									//fprintf( stderr, "Culling, count = %d\n", count ) ;
									++nCull ;
									continue ;
								}
					}
						

				// Get new reflection direction (with randomization)

				[ surf assignReflectionDirectionTo:reflectDirect
					usingDirection:direction andRandomization:randAngle atIntersectElem:intersectElem ] ;
					
				if( reflectPartition[nReflections - 1] == surf->partitionForElement[intersectElem] )
					{
						++nIntraFragmentSegments ;
					}
				else
					{
						++nInterFragmentSegments ;
					}
					
				direction[0] = reflectDirect[0] ;
				direction[1] = reflectDirect[1] ;
				direction[2] = reflectDirect[2] ;
				
				startPoint[0] = intersectPoint[0] ;
				startPoint[1] = intersectPoint[1] ;
				startPoint[2] = intersectPoint[2] ;
				
				theElem = intersectElem ;
				
				// Add this reflection
				
				double length = [ self addReflectionAtPosition:startPoint withMEP:mep inPartition:surf->partitionForElement[intersectElem]
									atStart:NO ] ;
			
				double scaledLength = scaleFactor * length ;
									
				if( scaledLength > maxSegmentLength ) maxSegmentLength = scaledLength ;
				
				double twoLength = prevSegmentLength + scaledLength ;
				
				if( twoLength > maxTwoSegmentLength ) maxTwoSegmentLength = twoLength ;
			
				prevSegmentLength = scaledLength ;
			
				++nSegments ;
			}
			
		printf( "\t%d %d, %d, %d %d = segments, reflections, bad intersects, self-int skipped, culls\n", 
			nSegments, nReflections,   badIntersectCount, 
			nSelfIntSkipIntersect, nCull ) ;
		printf( "\t%d, %d = intrafragment segments, interfragment segments\n", nIntraFragmentSegments, nInterFragmentSegments ) ;
		
		
		return self ;

	}
	
- (void) dealloc
	{
		free( reflectX )  ;
		free( reflectY )  ;
		free( reflectZ )  ;
		
		free( reflectMEP ) ;
	
		free( reflectPartition ) ;
	
		free( reflectAtStart ) ;
		
		[ super dealloc ] ;
		
		return ;
	} 

	
- (double) addReflectionAtPosition:(double [])pos withMEP:(double)m inPartition:(int)p atStart:(BOOL)strt
	{
		double returnLength = 0. ;
		
		if( nReflections == nAlloc )
			{
				nAlloc += 10000 ;
				
				reflectX = (double *) realloc( reflectX, nAlloc * sizeof( double ) ) ;
				reflectY = (double *) realloc( reflectY, nAlloc * sizeof( double ) ) ;
				reflectZ = (double *) realloc( reflectZ, nAlloc * sizeof( double ) ) ;
				
				reflectMEP = (double *) realloc( reflectMEP, nAlloc * sizeof( double ) ) ;
				
				reflectPartition = (int *) realloc( reflectPartition, nAlloc * sizeof( int ) ) ;
				
				reflectAtStart = (BOOL *) realloc( reflectAtStart, nAlloc * sizeof( BOOL ) ) ;
			}
			
		reflectX[nReflections] = pos[0] ;
		reflectY[nReflections] = pos[1] ;
		reflectZ[nReflections] = pos[2] ;
		
		reflectMEP[nReflections] = m ;
		
		reflectPartition[nReflections] = p ;
		
		reflectAtStart[nReflections] = strt ;
		
		if( strt == NO )
			{
				double dx = reflectX[nReflections] - reflectX[nReflections - 1] ;
				double dy = reflectY[nReflections] - reflectY[nReflections - 1] ;
				double dz = reflectZ[nReflections] - reflectZ[nReflections - 1] ;
				
				returnLength = sqrt( dx*dx + dy*dy + dz*dz ) ;
			}
				
		
		++nReflections ;
		
		return returnLength ;
	}
		
- (void) printRaytraceToFile:(NSString *)path
	{
		// Log raytrace to a file. We will use our MolMon "import" display format
		
		int i ;
		FILE *output ;
		
		int nFragments = theSurface->theTree->nFragments ;
		
		// We will use the same color scheme for fragmentation employed in MolMon - 
		// Interpolate betweem blue and red by fragment index (assumed to start at 1), with
		// constant green intensity = 0.25
		
		if( ! ( output = fopen( [ path cString ], "w" ) ) )
			{
				printf( "COULD NOT OPEN RAYTRACE LOG FILE!\n" ) ;
				return ;
			}
		
		for( i = 0 ; i < nReflections - 1 ; ++i )
			{
				if( reflectAtStart[i + 1] == YES ) 
					{
						continue ;
					}
				
				double x1 = reflectX[i] ;
				double y1 = reflectY[i] ;
				double z1 = reflectZ[i] ;
				
				double x2 = reflectX[i+1] ;
				double y2 = reflectY[i+1] ;
				double z2 = reflectZ[i+1] ;
				
				double r1 = ((double)(reflectPartition[i] - 1))/nFragments ;
				double b1 = 1. - r1 ;
				
				double r2 = ((double)(reflectPartition[i+1] - 1))/nFragments ;
				double b2 = 1. - r2 ;
				
				fprintf( output, "L %f %f %f %f %f %f %f %f %f %f %f %f\n",
					x1, y1, z1, x2, y2, z2, r1, 0.25, b1, r2, 0.25, b2 ) ;
			}
			
		fclose( output ) ;
			
		return ;

	}
		
		
		

@end
