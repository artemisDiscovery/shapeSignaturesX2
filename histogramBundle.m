//
//  histogramBundle.m
//  ShapeSignaturesX2
//
//  Created by Randy Zauhar on 2/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "histogramBundle.h"
#import "fragment.h"
#include <math.h>

//#define MIN(a,b) (((a) < (b)) ? (a) : (b))
//#define MAX(a,b) (((a) > (b)) ? (a) : (b))

int MIN3( int a , int b, int c )
	{
		if( a <= b && a <= c ) return a ;
		if( b <= a && b <= c ) return b ;
		if( c <= a && c <= b ) return c ;
	}
	
int MAX3( int a, int b, int c )
	{
		if( a >= b && a >= c ) return a ;
		if( b >= a && b >= c ) return b ;
		if( c >= a && c >= b ) return c ;
	}
	
int MED3( int a, int b, int c )
	{
		if( a <= b && b <= c ) return b ;
		if( c <= b && b <= a ) return b ;
		
		if( a <= c && c <= b ) return c ;
		if( b <= c && c <= a ) return c ;
		
		if( b <= a && a <= c ) return a ;
		if( c <= a && a <= b ) return a ;
	}

@implementation histogramBundle

- (id) initWithRayTrace:(rayTrace *)rt tag:(NSString *)tg style:(histogramStyle)st inSignature:(X2Signature *)sig ;
	{
	
		self = [ super init ] ;
		
		sourceTree = rt->theSurface->theTree ;
		
		sourceSignature = sig ;
		
		lengthDelta = st.lengthDelta ;
		MEPDelta = st.MEPDelta ;
		 
		// We will use the tag to adjust the class
		
		if( [ [ histogram recognizedTags ] containsObject:tg ] == NO )
			{
				printf( "ERROR - UNRECOGNIZED HISTOGRAM TAG\n" ) ;
				return nil ;
			}
			
		tag = [ [ NSString alloc ] initWithString:tg ] ;
			
		int histoTagIndex = [ [ histogram recognizedTags ] indexOfObject:tg ] ;
		
		type = (histogramClass) [ [ [ histogram classByRecognizedTag ] objectAtIndex:histoTagIndex ] intValue ] ;
		
		// Length bins - 
		
		if( type == TWO_DIMENSIONAL )
			{
				nLengthBins = ( (int) floor( rt->maxTwoSegmentLength / lengthDelta ) ) + 1 ;
			}
		else
			{
				nLengthBins = ( (int) floor( rt->maxSegmentLength / lengthDelta ) ) + 1 ;
			}
		
		if( type == TWO_DIMENSIONAL )
			{
				if( ([tg rangeOfString:@"REDUCED"]).location == NSNotFound )
					{
						// Make minMEP a multiple of MEPDelta
						
						if( rt->minMEP < 0. )
							{
								minMEP = (((int) floor( rt->minMEP / MEPDelta )))*MEPDelta ;
							}
						else
							{
								minMEP = (((int) floor( rt->minMEP / MEPDelta )) - 1)*MEPDelta ; 
							}
							
						nMEPBins = ( (int) floor( ( rt->maxMEP - minMEP ) / MEPDelta ) ) + 1  ;
					}
				else
					{
						// minMEP doesn't matter
						
						nMEPBins = 2 ;
					}
				
			}
		else
			{
				// All length bins belong to the same MEP bin
				
				nMEPBins = 1 ;
			}
			
		nBins = nLengthBins * nMEPBins ;
		
		// To map fragment keys to histograms
		
		int nFragments = sourceTree->nFragments ;
		
		sortedFragmentsToHistogram = [ [ NSMutableDictionary alloc ] 
			initWithCapacity:( nFragments * nFragments ) ] ;
			
		// This is sort of a kludge to rapidly map fragment indices to a histogram
		// If 1D histo, we will always set first index to 0
		
		histogram ****fragmentIndicesToHistogram = ( histogram ****) malloc( 
			( nFragments + 1 ) * sizeof( histogram *** ) ) ;
			
		int i, j, k ;
		
		for( i = 0 ; i <= nFragments ; ++i )
			{
				fragmentIndicesToHistogram[i] = ( histogram *** ) malloc(
					( nFragments + 1 ) * sizeof( histogram ** ) ) ;
				
				for( j = 0 ; j <= nFragments ; ++j )
					{
						fragmentIndicesToHistogram[i][j] = ( histogram ** ) malloc(
							( nFragments + 1 ) * sizeof( histogram * ) ) ;
							
						for( k = 0 ; k <= nFragments ; ++k )
							{
								fragmentIndicesToHistogram[i][j][k] = nil ;
							}
					}
			}
			
		// Start processing ray segments - allocate histograms as needed 
		
		int iReflect ;
		
		double *xCoord = rt->reflectX ;
		double *yCoord = rt->reflectY ;
		double *zCoord = rt->reflectZ ;
		
		double *mep = rt->reflectMEP ;
		
		BOOL *start = rt->reflectAtStart ;
		
		int *frag = rt->reflectPartition ;
		
		int frag1, frag2, frag3, fragPass[3] ;
		
		NSMutableArray *allHistograms = [ [ NSMutableArray alloc ] 
			initWithCapacity:( nFragments * nFragments ) ] ;
			
		// Separate handling for each tag type
		
		histogram *currentHistogram ;
		
		if( ([ tag rangeOfString:@"1DHISTO" ]).location == 0 )
			{
				// Simple shape-only histogram
				
				histogram *globalHistogram = [ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:nil ] ;
										
				[ globalHistogram setSortedFragmentKey:@"GLOBAL" ] ;
				
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 1 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						
						frag1 = frag[iReflect] ;
						frag2 = frag[iReflect + 1] ;
						
						if( ! ( currentHistogram = fragmentIndicesToHistogram[0][frag1][frag2] ) )
							{
								fragPass[0] = MIN( frag1, frag2 ) ;
								fragPass[1] = MAX( frag1, frag2 ) ;
								fragPass[2] = 0 ;
								
								fragmentIndicesToHistogram[0][frag1][frag2] = 
									[ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:fragPass ] ;
									
								fragmentIndicesToHistogram[0][frag2][frag1] =
									fragmentIndicesToHistogram[0][frag1][frag2] ;
									
								[ allHistograms 
									addObject:fragmentIndicesToHistogram[0][frag1][frag2] ] ;
									
								currentHistogram = fragmentIndicesToHistogram[0][frag1][frag2] ;
							}
									
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						
						int iBin = (int) floor( d / lengthDelta ) ;
					
						if( iBin < 0 || iBin >= nBins )
							{
								printf("ERROR - ILLEGAL BIN IN 1D\n");
								return nil ;
							}
					
						[ currentHistogram add1DSegmentAtLengthBin:iBin ] ;
						[ globalHistogram add1DSegmentAtLengthBin:iBin ] ;
								
					}
					
				// Get normalized probs
				
				NSEnumerator *histogramEnumerator = [ allHistograms objectEnumerator ] ;
				histogram *nextHisto ;
				
				while( ( nextHisto = [ histogramEnumerator nextObject ] ) )
					{
						[ nextHisto normalize ] ;
						
						// Make key
						
						NSString *histoKey = [ NSString 
							stringWithFormat:@"%d_%d",nextHisto->fragments[0], nextHisto->fragments[1], nil ] ;
							
						[ nextHisto setSortedFragmentKey:histoKey ] ;
							
						[ sortedFragmentsToHistogram setObject:nextHisto forKey:histoKey ] ;
						
						[ nextHisto release ] ;
					}
					
				[ globalHistogram normalize ] ;
				
				[ sortedFragmentsToHistogram setObject:globalHistogram forKey:@"GLOBAL" ] ; 
					
			}
		else if( ([ tg rangeOfString:@"2DMEPHISTO" ]).location == 0 )
			{
				// Have a basic 2D MEP-based histogram
				
				// To have a contribution to a global histogram, must have a chain of two segments that includes
				// no internal starts
				
				// To have a contribution to a fragment, must satisfy "no start" condition, AND all reflections 
				// must belong to the same fragment
				
				histogram *globalHistogram = [ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:nil ] ;
										
				[ globalHistogram setSortedFragmentKey:@"GLOBAL" ] ;
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 2 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						if( start[iReflect + 2] == YES ) continue ;
						
						frag1 = frag[iReflect] ;
						frag2 = frag[iReflect + 1] ;
						frag3 = frag[iReflect + 2] ;
						
						if( ! ( currentHistogram = fragmentIndicesToHistogram[frag1][frag2][frag3] ) )
							{
								fragPass[0] = MIN3( frag1, frag2, frag3 ) ;
								fragPass[1] = MED3( frag1, frag2, frag3 ) ;
								fragPass[2] = MAX3( frag1, frag2, frag3 ) ;
								
								fragmentIndicesToHistogram[frag1][frag2][frag3] = 
									[ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:fragPass ] ;
										
								currentHistogram = fragmentIndicesToHistogram[frag1][frag2][frag3] ;
								
								// All  combos
								
								fragmentIndicesToHistogram[frag1][frag3][frag2] = currentHistogram ;
								
								fragmentIndicesToHistogram[frag2][frag1][frag3] = currentHistogram ;
								fragmentIndicesToHistogram[frag2][frag3][frag1] = currentHistogram ;
								fragmentIndicesToHistogram[frag3][frag1][frag2] = currentHistogram ;
								fragmentIndicesToHistogram[frag3][frag2][frag1] = currentHistogram ;
								
								[ allHistograms 
									addObject:currentHistogram ] ;
									
							}
									
						// Do this the inefficient but simple and safe way
						
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d1 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						dx = xCoord[iReflect + 2] - xCoord[iReflect + 1] ;
						dy = yCoord[iReflect + 2] - yCoord[iReflect + 1] ;
						dz = zCoord[iReflect + 2] - zCoord[iReflect + 1] ;
						
						double d2 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						int lenBin = (int) floor( ( d1 + d2 ) / lengthDelta ) ;
						int MEPBin = (int) floor( ( mep[iReflect + 1] - minMEP ) / MEPDelta ) ;
						
						
						
						int iBin = ( MEPBin * nLengthBins ) + lenBin ;
					
						if( iBin < 0 || iBin >= nBins )
							{
							
								printf("ERROR - ILLEGAL BIN IN 2DMEP\n");
							}
							
						[ currentHistogram add2DSegmentPairAtLengthBin:lenBin MEPBin:MEPBin ] ;
						[ globalHistogram add2DSegmentPairAtLengthBin:lenBin MEPBin:MEPBin ] ;
						
					}
		
				
				// Get normalized probs
				
				NSEnumerator *histogramEnumerator = [ allHistograms objectEnumerator ] ;
				histogram *nextHisto ;
				
				while( ( nextHisto = [ histogramEnumerator nextObject ] ) )
					{
						[ nextHisto normalize ] ;
						
						// Make key
						
						NSString *histoKey = [ NSString 
							stringWithFormat:@"%d_%d_%d",nextHisto->fragments[0], nextHisto->fragments[1], 
								nextHisto->fragments[2], nil ] ;
								
						[ nextHisto setSortedFragmentKey:histoKey ] ;
							
						[ sortedFragmentsToHistogram setObject:nextHisto forKey:histoKey ] ;
						
						[ nextHisto release ] ;
					}
					
				[ globalHistogram normalize ] ;
				
				[ sortedFragmentsToHistogram setObject:globalHistogram forKey:@"GLOBAL" ] ;
			}
		else if( ([ tg rangeOfString:@"2DMEPREDUCEDHISTO" ]).location == 0 )
			{
				// Have a reduced 2D MEP-based histogram (only two classes of
				// potential, negative (0) and positive (1)
				
				// To have a contribution to a global histogram, must have a chain of two segments that includes
				// no internal starts
				
				// To have a contribution to a fragment, must satisfy "no start" condition, AND all reflections 
				// must belong to the same fragment
				
				histogram *globalHistogram = [ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:nil ] ;
										
				[ globalHistogram setSortedFragmentKey:@"GLOBAL" ] ;
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 2 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						if( start[iReflect + 2] == YES ) continue ;
						
						frag1 = frag[iReflect] ;
						frag2 = frag[iReflect + 1] ;
						frag3 = frag[iReflect + 2] ;
						
						if( ! ( currentHistogram = fragmentIndicesToHistogram[frag1][frag2][frag3] ) )
							{
								fragPass[0] = MIN3( frag1, frag2, frag3 ) ;
								fragPass[1] = MED3( frag1, frag2, frag3 ) ;
								fragPass[2] = MAX3( frag1, frag2, frag3 ) ;
								
								fragmentIndicesToHistogram[frag1][frag2][frag3] = 
									[ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:fragPass ] ;
										
								currentHistogram = fragmentIndicesToHistogram[frag1][frag2][frag3] ;
								
								// All  combos
								
								fragmentIndicesToHistogram[frag1][frag3][frag2] = currentHistogram ;
								
								fragmentIndicesToHistogram[frag2][frag1][frag3] = currentHistogram ;
								fragmentIndicesToHistogram[frag2][frag3][frag1] = currentHistogram ;
								fragmentIndicesToHistogram[frag3][frag1][frag2] = currentHistogram ;
								fragmentIndicesToHistogram[frag3][frag2][frag1] = currentHistogram ;
								
								[ allHistograms 
									addObject:currentHistogram ] ;
									
							}
						
						
						// Do this the inefficient but simple and safe way
						
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d1 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						dx = xCoord[iReflect + 2] - xCoord[iReflect + 1] ;
						dy = yCoord[iReflect + 2] - yCoord[iReflect + 1] ;
						dz = zCoord[iReflect + 2] - zCoord[iReflect + 1] ;
						
						double d2 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						int lenBin = (int) floor( ( d1 + d2 ) / lengthDelta ) ;
						
						int MEPBin ;
						
						if( mep[iReflect + 1] < 0 )
							{
								MEPBin = 0 ;
							}
						else 
							{
								MEPBin = 1 ;
							}
						
						int iBin = ( MEPBin * nLengthBins ) + lenBin ;
					
						if( iBin < 0 || iBin >= nBins )
							{
							
								printf("ERROR - ILLEGAL BIN IN 2DMEPREDUCED\n");
							}
						
						[ currentHistogram add2DSegmentPairAtLengthBin:lenBin MEPBin:MEPBin ] ;
						[ globalHistogram add2DSegmentPairAtLengthBin:lenBin MEPBin:MEPBin ] ;
						
					}
			
			
				// Get normalized probs
				
				NSEnumerator *histogramEnumerator = [ allHistograms objectEnumerator ] ;
				histogram *nextHisto ;
				
				while( ( nextHisto = [ histogramEnumerator nextObject ] ) )
					{
						[ nextHisto normalize ] ;
						
						// Make key
						
						NSString *histoKey = [ NSString 
							stringWithFormat:@"%d_%d_%d",nextHisto->fragments[0], nextHisto->fragments[1], 
								nextHisto->fragments[2], nil ] ;
								
						[ nextHisto setSortedFragmentKey:histoKey ] ;
							
						[ sortedFragmentsToHistogram setObject:nextHisto forKey:histoKey ] ;
						
						[ nextHisto release ] ;
					}
					
				[ globalHistogram normalize ] ;
				
				[ sortedFragmentsToHistogram setObject:globalHistogram forKey:@"GLOBAL" ] ;
			}
		else if( ([ tg rangeOfString:@"2DMEPREDUCEDINVERTEDHISTO" ]).location == 0 )
			{
				// Have an inverted reduced 2D MEP-based histogram
				
				// Negative potential contributions go in bin 1, positive
				// in 0 ; this is the inverse of the regular reduced case,
				// and is intended for receptor-based queries. 
				
				// To have a contribution to a global histogram, must have a chain of two segments that includes
				// no internal starts
				
				// To have a contribution to a fragment, must satisfy "no start" condition, AND all reflections 
				// must belong to the same fragment
				
				histogram *globalHistogram = [ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:nil ] ;
										
				[ globalHistogram setSortedFragmentKey:@"GLOBAL" ] ;
				
				for( iReflect = 0 ; iReflect < rt->nReflections - 2 ; ++iReflect )
					{
						if( start[iReflect + 1] == YES ) continue ;
						if( start[iReflect + 2] == YES ) continue ;
						
						frag1 = frag[iReflect] ;
						frag2 = frag[iReflect + 1] ;
						frag3 = frag[iReflect + 2] ;
						
						if( ! ( currentHistogram = fragmentIndicesToHistogram[frag1][frag2][frag3] ) )
							{
								fragPass[0] = MIN3( frag1, frag2, frag3 ) ;
								fragPass[1] = MED3( frag1, frag2, frag3 ) ;
								fragPass[2] = MAX3( frag1, frag2, frag3 ) ;
								
								fragmentIndicesToHistogram[frag1][frag2][frag3] = 
									[ [ histogram alloc ] initWithBundle:self 
										fragmentIndices:fragPass ] ;
										
								currentHistogram = fragmentIndicesToHistogram[frag1][frag2][frag3] ;
								
								// All  combos
								
								fragmentIndicesToHistogram[frag1][frag3][frag2] = currentHistogram ;
								
								fragmentIndicesToHistogram[frag2][frag1][frag3] = currentHistogram ;
								fragmentIndicesToHistogram[frag2][frag3][frag1] = currentHistogram ;
								fragmentIndicesToHistogram[frag3][frag1][frag2] = currentHistogram ;
								fragmentIndicesToHistogram[frag3][frag2][frag1] = currentHistogram ;
								
								[ allHistograms 
									addObject:currentHistogram ] ;
									
							}
						
						// Do this the inefficient but simple and safe way
						
						double dx = xCoord[iReflect + 1] - xCoord[iReflect] ;
						double dy = yCoord[iReflect + 1] - yCoord[iReflect] ;
						double dz = zCoord[iReflect + 1] - zCoord[iReflect] ;
						
						double d1 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						dx = xCoord[iReflect + 2] - xCoord[iReflect + 1] ;
						dy = yCoord[iReflect + 2] - yCoord[iReflect + 1] ;
						dz = zCoord[iReflect + 2] - zCoord[iReflect + 1] ;
						
						double d2 = sqrt( dx*dx + dy*dy + dz*dz ) ;
						
						int lenBin = (int) floor( ( d1 + d2 ) / lengthDelta ) ;
						
						int MEPBin ;
						
						if( mep[iReflect + 1] < 0 )
							{
								MEPBin = 1 ;
							}
						else 
							{
								MEPBin = 0 ;
							}
						
						int iBin = ( MEPBin * nLengthBins ) + lenBin ;
					
						if( iBin < 0 || iBin >= nBins )
							{
							
								printf("ERROR - ILLEGAL BIN IN 2DMEPREDUCEDINVERTED\n");
							}
						
						[ currentHistogram add2DSegmentPairAtLengthBin:lenBin MEPBin:MEPBin ] ;
						[ globalHistogram add2DSegmentPairAtLengthBin:lenBin MEPBin:MEPBin ] ;
					
					}
				
				
				// Get normalized probs
				
				NSEnumerator *histogramEnumerator = [ allHistograms objectEnumerator ] ;
				histogram *nextHisto ;
				
				while( ( nextHisto = [ histogramEnumerator nextObject ] ) )
					{
						[ nextHisto normalize ] ;
						
						// Make key
						
						NSString *histoKey = [ NSString 
							stringWithFormat:@"%d_%d_%d",nextHisto->fragments[0], nextHisto->fragments[1], 
								nextHisto->fragments[2], nil ] ;
								
						[ nextHisto setSortedFragmentKey:histoKey ] ;
							
						[ sortedFragmentsToHistogram setObject:nextHisto forKey:histoKey ] ;
						
						[ nextHisto release ] ;
					}
					
				[ globalHistogram normalize ] ;
				
				[ sortedFragmentsToHistogram setObject:globalHistogram forKey:@"GLOBAL" ] ;
			}
				
		for( i = 0 ; i <= nFragments ; ++i )
			{				
				for( j = 0 ; j <= nFragments ; ++j )
					{
						free( fragmentIndicesToHistogram[i][j] ) ;
					}
					
				free( fragmentIndicesToHistogram[i] ) ;
			}
			
		free( fragmentIndicesToHistogram ) ;
		
		[ allHistograms release ] ;
		
				
		
		return self ;
	}
		
- (void) dealloc
	{
		[ sortedFragmentsToHistogram release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}
	
- ( NSString *) keyStringsForBundleWithIncrement:(double) inc
	{
		NSMutableString *returnString = [ [ NSMutableString alloc ] initWithCapacity:100 ] ;
		
		// For now only do 1DHISTO
		
		if( [ tag isEqualToString:@"1DHISTO" ] == NO ) return nil ;
		
		// Go through all keys, only use type "x_x" 
		
		NSEnumerator *fragmentKeyEnumerator = [ [ sortedFragmentsToHistogram allKeys ] objectEnumerator ] ;
		
		NSString *nextFragmentKey ;
		
		while( ( nextFragmentKey = [ fragmentKeyEnumerator nextObject ] ) )
			{
				if( [ nextFragmentKey isEqualToString:@"GLOBAL" ] ) continue ;
				
				NSArray *fragmentComponents = [ nextFragmentKey componentsSeparatedByString:@"_" ] ;
				
				// Must be two
				
				NSString *fragmentString = [ fragmentComponents objectAtIndex:0 ] ;
				
				if( [ fragmentString isEqualToString:[fragmentComponents objectAtIndex:1 ] ] == NO )
					{
						continue ;
					}
					
				int fragmentIndex = [ fragmentString intValue ] - 1 ;
				
				fragment *theFragment = [ sourceTree->treeFragments objectAtIndex:fragmentIndex ] ;
					
				histogram *theHisto = [ sortedFragmentsToHistogram objectForKey:nextFragmentKey ] ;
				
				[ returnString appendString:@"@frag:" ] ;
				[ returnString appendString:fragmentString ] ;
				[ returnString appendString:@"\n@size:" ] ;
				[ returnString appendString:[ NSString stringWithFormat:@"%d", [ theFragment->fragmentNodes count ] ] ] ;
				[ returnString appendString:@"\n@key:" ] ;
				[ returnString appendString:[ theHisto keyStringWithIncrement:inc ] ] ;
				[ returnString appendString:@"\n" ] ;
			}
			
		return returnString ;
	}
				
				

- (void) encodeWithCoder:(NSCoder *)coder
	{
		[ coder encodeValueOfObjCType:@encode(histogramClass) at:&type ] ;
		
		[ coder encodeObject:tag ] ;
		
		// Source tree set from X2Signature decode
		//[ coder encodeObject:sourceTree ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&nBins ] ;
		[ coder encodeValueOfObjCType:@encode(int) at:&nLengthBins ] ;
		[ coder encodeValueOfObjCType:@encode(double) at:&lengthDelta ] ;
		[ coder encodeValueOfObjCType:@encode(int) at:&nMEPBins ] ;
		
		[ coder encodeValueOfObjCType:@encode(double) at:&minMEP ] ;
		[ coder encodeValueOfObjCType:@encode(double) at:&MEPDelta ] ;
	
		[ coder encodeObject:sortedFragmentsToHistogram ] ;
		
		return ;
	}
		
- (id) initWithCoder:(NSCoder *)coder
	{
		self = [ super init ] ;
		
		[ coder decodeValueOfObjCType:@encode(histogramClass) at:&type ] ;
		
		tag = [ [ coder decodeObject ] retain ] ;
		// sourceTree = [ [ coder decodeObject ] retain ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&nBins ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&nLengthBins ] ;
		[ coder decodeValueOfObjCType:@encode(double) at:&lengthDelta ] ;
		[ coder decodeValueOfObjCType:@encode(int) at:&nMEPBins ] ;
		
		[ coder decodeValueOfObjCType:@encode(double) at:&minMEP ] ;
		[ coder decodeValueOfObjCType:@encode(double) at:&MEPDelta ] ;
		
		sortedFragmentsToHistogram = [ [ coder decodeObject ] retain ] ;
		
		// Need to set the parent bundle ID in all the child histograms
		
		NSEnumerator *histogramEnumerator = [ [ sortedFragmentsToHistogram allValues ] objectEnumerator ] ;
		histogram *nextHisto ;
		
		while( ( nextHisto = [ histogramEnumerator nextObject ] ) )
			{
				nextHisto->hostBundle = self ;
			}
		
		
		return self ;
	}
		

		
					
@end
