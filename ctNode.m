//
//  ctNode.m
//  fftool
//
//  Created by Randy Zauhar on 5/11/09.
//  Copyright 2009 ArtemisDiscovery LLC. All rights reserved.
//

#import "ctNode.h"
#include <ctype.h>

static NSDictionary *atomicNumberForElement ;
static NSDictionary *atomicWeightForElement ;

@implementation ctNode

+ (void) initialize
	{
		// Set up the default color dictionary ; these are taken from JMOL
		
		NSArray *elemKeys = [ NSArray arrayWithObjects:
			@"C", @"N", @"O", @"H", @"S", @"P",
			@"F", @"CL", @"BR", @"I",
			@"LI", @"NA", @"K", @"MG", @"CA", 
			@"MN", @"FE", @"CO", @"NI", @"CU", @"ZN",
			@"B", nil ] ;
			
		// Following data from http://www.chemicalelements.com (yeah, that's being lazy)
		
		NSArray *atNumValues = [ NSArray arrayWithObjects:
			// C, N, O, H, S, P
			[ NSNumber numberWithInt:6 ] ,
			[ NSNumber numberWithInt:7 ],
			[ NSNumber numberWithInt:8 ],
			[ NSNumber numberWithInt:1 ],
			[ NSNumber numberWithInt:16 ],
			[ NSNumber numberWithInt:15 ],
			// F, Cl, Br, I
			[ NSNumber numberWithInt:9 ],
			[ NSNumber numberWithInt:17 ],
			[ NSNumber numberWithInt:35 ],
			[ NSNumber numberWithInt:53 ],
			// Li, Na, K, Mg, Ca
			[ NSNumber numberWithInt:3 ],
			[ NSNumber numberWithInt:11 ],
			[ NSNumber numberWithInt:19 ],
			[ NSNumber numberWithInt:12 ],
			[ NSNumber numberWithInt:20 ],
			// Mn, Fe, Co, Ni, Cu, Zn
			[ NSNumber numberWithInt:25 ],
			[ NSNumber numberWithInt:26 ],
			[ NSNumber numberWithInt:27 ],
			[ NSNumber numberWithInt:28 ],
			[ NSNumber numberWithInt:29 ],
			[ NSNumber numberWithInt:30 ],
			// B
			[ NSNumber numberWithInt:5 ], nil ] ;

		atomicNumberForElement = [ [ NSDictionary alloc ] initWithObjects:atNumValues 
												forKeys:elemKeys ] ;
													
		NSArray *atWtValues = [ NSArray arrayWithObjects:
			// C, N, O, H, S, P
			[ NSNumber numberWithDouble:12.0107 ] ,
			[ NSNumber numberWithDouble:14.00674 ],
			[ NSNumber numberWithDouble:15.9994 ],
			[ NSNumber numberWithDouble:1.00794 ],
			[ NSNumber numberWithDouble:32.066 ],
			[ NSNumber numberWithDouble:30.973761 ],
			// F, Cl, Br, I
			[ NSNumber numberWithDouble:18.9984032 ],
			[ NSNumber numberWithDouble:35.4527 ],
			[ NSNumber numberWithDouble:79.904 ],
			[ NSNumber numberWithDouble:126.90447 ],
			// Li, Na, K, Mg, Ca
			[ NSNumber numberWithDouble:6.941 ],
			[ NSNumber numberWithDouble:22.989770 ],
			[ NSNumber numberWithDouble:39.0983 ],
			[ NSNumber numberWithDouble:24.3050 ],
			[ NSNumber numberWithDouble:40.078 ],
			// Mn, Fe, Co, Ni, Cu, Zn
			[ NSNumber numberWithDouble:54.938049 ],
			[ NSNumber numberWithDouble:55.845 ],
			[ NSNumber numberWithDouble:58.933200 ],
			[ NSNumber numberWithDouble:58.6934 ],
			[ NSNumber numberWithDouble:63.546 ],
			[ NSNumber numberWithDouble:65.39 ],
			// B
			[ NSNumber numberWithDouble:10.811 ], nil ] ;

		atomicWeightForElement = [ [ NSDictionary alloc ] initWithObjects:atWtValues 
												forKeys:elemKeys ] ;
												
		return ;
	}
										
			
			
			
- (id) initWithElement:(char *)e andIndex:(int)idx
	{
		self = [ super init ] ;
		
		element = (char *) malloc( ( strlen(e) + 1 ) * sizeof( char ) ) ;
		
		index = idx ;
		
		// Convert to uppercase?? YES, for ctNode
		
		strcpy( element, e ) ;
		
		int i ;
		
		for( i = 0 ; i < strlen(element) ; ++i )
			{
				element[i] = toupper( element[i] ) ;
			}
		
		nBondAlloc = 4 ;
		
		bonds = (ctBond **) malloc( nBondAlloc * sizeof( ctBond *) ) ;
		atBondStart = (BOOL *) malloc( nBondAlloc * sizeof( BOOL ) ) ;
		
		nBonds = 0 ;
		
		properties = [ NSMutableDictionary dictionaryWithCapacity:5 ] ;
		[ properties retain ] ;
		
		charge = 0. ;
		
		coord[0] = coord[1] = coord[2] = 0. ;
		
		pathIndex = -1 ;
		
		fragmentIndex = -1 ;
		fragmentTree = nil ;
		
		NSString *key = [ [ NSString alloc ] initWithCString:element ] ;
		
		atomicNumber = [ [ atomicNumberForElement objectForKey:key ] intValue ] ;
		atomicWeight = [ [ atomicWeightForElement objectForKey:key ] doubleValue ] ;
	
		[ key release ] ;
		
		return self ;
	}
	
- (void) dealloc
	{
		[ properties release ] ;
		
		// NOTE that I do NOT release the bonds we point at - that can only be done by the tree
		
		free( bonds ) ;
	
		free( element ) ;
	
		free( atBondStart ) ;
		
		[ super dealloc ] ;
		
		return ;
	}
		
		
	
- (void) addBond:(ctBond *)b 
	{
		// This bond is added to the parent tree as well
		
		if( nBonds == nBondAlloc )
			{
				nBondAlloc += 4 ;
				
				bonds = (ctBond **) realloc( bonds, nBondAlloc * sizeof( ctBond * ) ) ;
				atBondStart = (BOOL *) realloc( atBondStart, nBondAlloc * sizeof( BOOL ) ) ;

			}
		
		bonds[nBonds] = b ;
		
		if( [ b startNode ] == self )
			{
				atBondStart[nBonds] = YES ;
			}
		else
			{
				atBondStart[nBonds] = NO ;
			}
		
		
		++nBonds ;
		
		return ;
	}

- (void) setCharge:(double)q
	{
		charge = q ;
		return ;
	}

- (void) addPropertyValue:(char *)v forKey:(char *)k
	{
		[ properties setObject:[ NSString stringWithCString:v ] forKey:[ NSString stringWithCString:k ] ] ;
		
		return ;
	}
	
- (char *) elementName
	{
		return element ;
	}

- (ctBond *) returnBondWithNode:(ctNode *)n
	{
		int i ;
		
		for( i = 0 ; i < nBonds ; ++i )
			{
				if( atBondStart[i] == YES )
					{
						if( bonds[i]->node2 == n )
							{
								return bonds[i] ;
							}
					}
				else
					{
						if( bonds[i]->node1 == n )
							{
								return bonds[i] ;
							}
					}
			}
			
		return nil ;
	}


- (NSArray *) neighborsWithPathIndexOtherThan:(int)excludePath
	{
		int i ;
		
		ctNode *neighbor ;
		
		NSMutableArray *returnNodes = [ [ NSMutableArray alloc ] initWithCapacity:2 ] ;
		
		
		for( i = 0 ; i < nBonds ; ++i )
			{
				if( atBondStart[i] == YES )
					{
						neighbor = bonds[i]->node2 ;
					}
				else
					{
						neighbor = bonds[i]->node1 ;
					}
					
				// Hydrogens are not in paths 
				
				if( strcasecmp( [ neighbor elementName ], "H" ) == 0 ) continue ;
				
				if( neighbor->pathIndex >= 0 && neighbor->pathIndex != excludePath )
					{
						[ returnNodes addObject:neighbor ] ;
					}
			}
			
		if( [ returnNodes count ] == 0 )
			{
				[ returnNodes release ] ;
				return nil ;
			}
			
		return returnNodes ;
		
	}
	
- (NSArray *) neighborsWithDifferentFragmentIndex
	{
		int i ;
		
		ctNode *neighbor ;
		
		NSMutableArray *returnNodes = [ [ NSMutableArray alloc ] initWithCapacity:2 ] ;
		
		
		for( i = 0 ; i < nBonds ; ++i )
			{
				if( atBondStart[i] == YES )
					{
						neighbor = bonds[i]->node2 ;
					}
				else
					{
						neighbor = bonds[i]->node1 ;
					}
					
				
				if( neighbor->fragmentIndex !=  fragmentIndex )
					{
						[ returnNodes addObject:neighbor ] ;
					}
			}
			
		if( [ returnNodes count ] == 0 )
			{
				[ returnNodes release ] ;
				return nil ;
			}
			
		return returnNodes ;
		
	}
	
- (NSArray *) neighbors
	{
		int i ;
		
		ctNode *neighbor ;
		
		NSMutableArray *returnNodes = [ [ NSMutableArray alloc ] initWithCapacity:2 ] ;
		
		
		for( i = 0 ; i < nBonds ; ++i )
			{
				if( atBondStart[i] == YES )
					{
						neighbor = bonds[i]->node2 ;
					}
				else
					{
						neighbor = bonds[i]->node1 ;
					}
					
				if( strcasecmp(neighbor->element, "H") == 0 ) continue ;
				
				[ returnNodes addObject:neighbor ] ;
			}
			
		if( [ returnNodes count ] == 0 )
			{
				[ returnNodes release ] ;
				return nil ;
			}
			
		return returnNodes ;
		
	}

- (NSArray *) neighborsExcludeBond:(ctBond *)excl
	{
		int i ;
		
		ctNode *neighbor ;
		
		NSMutableArray *returnNodes = [ [ NSMutableArray alloc ] initWithCapacity:2 ] ;
		
		
		for( i = 0 ; i < nBonds ; ++i )
			{
				if( bonds[i] == excl ) continue ;
				
				if( atBondStart[i] == YES )
					{
						neighbor = bonds[i]->node2 ;
					}
				else
					{
						neighbor = bonds[i]->node1 ;
					}
					
				if( strcasecmp(neighbor->element, "H") == 0 ) continue ;
				
				[ returnNodes addObject:neighbor ] ;
			}
			
		if( [ returnNodes count ] == 0 )
			{
				[ returnNodes release ] ;
				return nil ;
			}
			
		return returnNodes ;
		
	}

- (NSArray *) neighborsWithPathIndex:(int)includePath
	{
		int i ;
		
		ctNode *neighbor ;
		
		NSMutableArray *returnNodes = [ [ NSMutableArray alloc ] initWithCapacity:2 ] ;
		
		
		for( i = 0 ; i < nBonds ; ++i )
			{
				if( atBondStart[i] == YES )
					{
						neighbor = bonds[i]->node2 ;
					}
				else
					{
						neighbor = bonds[i]->node1 ;
					}
					
				// Hydrogens are not in paths 
				
				if( strcasecmp( [ neighbor elementName ], "H" ) == 0 ) continue ;
				
				if( neighbor->pathIndex == includePath )
					{
						[ returnNodes addObject:neighbor ] ;
					}
			}
			
		if( [ returnNodes count ] == 0 )
			{
				[ returnNodes release ] ;
				return nil ;
			}
			
		return returnNodes ;
		
	}
	
- (void) setX:(double)x Y:(double)y Z:(double)z
	{
		coord[0] = x ;
		coord[1] = y ;
		coord[2] = z ;
		
		return ;
	}

- (void) assignToFragmentIndex:(int)f withFragmentType:(const char *)t
	{
		fragmentIndex = f ;
		
		char label[10] ;
		
		sprintf( label, "%s%d", t, f ) ;
		
		[ self addPropertyValue:label forKey:"fragmentID" ] ;
		
		return ;
	}
	
- (void) adjustFragmentIndex:(int)idx
	{
		// Extract type
		
		NSString *myID = [ properties objectForKey:@"fragmentID" ] ;
		
		NSRange rng = [ myID rangeOfString:@"S" ] ;
		
		if( rng.location == 0 )
			{
				[ self assignToFragmentIndex:idx withFragmentType:"S" ] ;
				return ;
			}
			
		rng = [ myID rangeOfString:@"R" ] ;
		
		if( rng.location == 0 )
			{
				[ self assignToFragmentIndex:idx withFragmentType:"R" ] ;
				return ;
			}
			
		rng = [ myID rangeOfString:@"N" ] ;
		
		if( rng.location == 0 )
			{
				[ self assignToFragmentIndex:idx withFragmentType:"NR" ] ;
				return ;
			}
			
		// Should never reach this point
		
		return ;
	}
			
			
	
- (NSString *) returnPropertyForKey:(NSString *)k
	{
		// Normally this just returns based on key, unless the key is INDEX
		
		if( [ k isEqualToString:@"INDEX" ] )
			{
				return [ NSString stringWithFormat:@"%d",index ] ;
			}
		else
			{
				return [ properties objectForKey:k ] ;
			}
			
		return nil ;
	}
	
- (BOOL) isRingNode
	{
		NSString *fragID = [ properties objectForKey:@"fragmentID" ] ;
		
		NSRange rng = [ fragID rangeOfString:@"R" ] ;
		
		if( rng.location != 0 )
			{
				return NO ;
			}
		else
			{
				return YES ;
			}
			
		return NO ;
	}
	
- (NSDictionary *) properties
	{
		return properties ;
	}

- (void) encodeWithCoder:( NSCoder *)coder
	{
		[ coder encodeValueOfObjCType:@encode(int) at:&atomicNumber ] ;
		
		[ coder encodeValueOfObjCType:@encode(double) at:&atomicWeight ] ;
		
		int eLength = strlen(element) + 1 ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&eLength ] ;
		
		[ coder encodeArrayOfObjCType:@encode(char) count:eLength at:element ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&index ] ;
		
		[ coder encodeArrayOfObjCType:@encode(double) count:3 at:coord ] ;
		
		[ coder encodeObject:properties ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&currentAtomTypeIndex ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&hybridization ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&valence ] ;
		
		[ coder encodeValueOfObjCType:@encode(double) at:&charge ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&nBonds ] ;
		
		NSArray *bondArray = [ NSArray arrayWithObjects:bonds count:nBonds ] ;
		[ coder encodeObject:bondArray ] ;
		
		[ coder encodeArrayOfObjCType:@encode(BOOL) count:nBonds at:atBondStart ] ;
		
		// Skip coding matchNode
		
		[ coder encodeValueOfObjCType:@encode(int) at:&pathIndex ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&fragmentIndex ] ;
		
		return ;
		
	}
	
- (id) initWithCoder:(NSCoder *)coder 
	{
		self = [ super init ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&atomicNumber ] ;

		[ coder decodeValueOfObjCType:@encode(double) at:&atomicWeight ] ;
		
		int eLength ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&eLength ] ;
		
		element = (char *) malloc( eLength * sizeof( char ) ) ;
		
		[ coder decodeArrayOfObjCType:@encode(char) count:eLength at:element ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&index ] ;
		
		[ coder decodeArrayOfObjCType:@encode(double) count:3 at:coord ] ;
		
		properties = [ coder decodeObject ] ;
		
		[ properties retain ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&currentAtomTypeIndex ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&hybridization ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&valence ] ;
		
		[ coder decodeValueOfObjCType:@encode(double) at:&charge ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&nBonds ] ;
		
		nBondAlloc = nBonds ;
		
		bonds = (ctBond **) malloc( nBonds * sizeof( ctBond * ) ) ;
		
		atBondStart = (BOOL *) malloc( nBonds * sizeof( BOOL ) ) ;
		
		NSArray *bondArray = [ coder decodeObject ] ; // Remove retain of this
		
		NSRange rng = NSMakeRange(0, nBonds ) ;
		
		[ bondArray getObjects:bonds range:rng ] ;
		
		[ coder decodeArrayOfObjCType:@encode(BOOL) count:nBonds at:&atBondStart ] ; // From static analyzer
		
		matchNode = nil ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&pathIndex ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&fragmentIndex ] ;
		
		return self ;
	}
	
- (NSDictionary *) propertyListDict 
	{
		NSMutableDictionary *returnDictionary = [ NSMutableDictionary dictionaryWithCapacity:10 ] ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&atomicNumber length:sizeof(int) ] forKey:@"atomicNumber" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&atomicWeight length:sizeof(double) ] forKey:@"atomicWeight" ]  ;
		[ returnDictionary setObject:[ NSString stringWithCString:element ] forKey:@"elementAsString" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&index length:sizeof(int) ] forKey:@"index" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:coord length:( 3 * sizeof(double) ) ] forKey:@"coord" ]  ;
		
		[ returnDictionary setObject:properties forKey:@"properties" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&charge length:sizeof(double) ] forKey:@"charge" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&nBonds length:sizeof(int) ] forKey:@"nBonds" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:bonds length:(nBonds*sizeof( ctBond *)) ] 
			forKey:@"originalBondPtrs" ] ;
				
		[ returnDictionary setObject:[ NSData dataWithBytes:&atBondStart length:(nBonds*sizeof(BOOL)) ] forKey:@"atBondStart" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&pathIndex length:sizeof(int) ] forKey:@"pathIndex" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&fragmentIndex length:sizeof(int) ] forKey:@"fragmentIndex" ]  ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&fragmentTree length:sizeof(ctTree *) ] forKey:@"originalFragmentTreePtr" ]  ;
		
		
		return returnDictionary ;
		
		//return theData ;
	}
	
- (id) initWithPropertyListDict:(NSDictionary *)pListDict
	{
		self = [ super init ] ;
		
		NSData *theData ;
		
		theData = [ pListDict objectForKey:@"atomicNumber" ] ;
		[ theData getBytes:&atomicNumber length:sizeof(int) ] ;
		theData = [ pListDict objectForKey:@"atomicWeight" ] ;
		[ theData getBytes:&atomicWeight length:sizeof(double) ] ;
		
		NSString *elemAsString = [ pListDict objectForKey:@"elementAsString" ] ;
		
		element = (char *) malloc( ( [ elemAsString length ] + 1 ) * sizeof(char) ) ;
		strcpy(element, [ elemAsString cString ] ) ;
		
		theData = [ pListDict objectForKey:@"index" ] ;
		[ theData getBytes:&index length:sizeof(int) ] ;
		
		theData = [ pListDict objectForKey:@"coord" ] ;
		[ theData getBytes:coord length:3*sizeof(double) ] ;
		
		properties = [ [ NSMutableDictionary alloc ] 
			initWithDictionary:[ pListDict objectForKey:@"properties" ] ] ;
			
		theData = [ pListDict objectForKey:@"charge" ] ;
		[ theData getBytes:&charge length:sizeof(double) ] ;
		
		theData = [ pListDict objectForKey:@"nBonds" ] ;
		[ theData getBytes:&nBonds length:sizeof(int) ] ;

		bonds = (ctBond **) malloc( nBonds * sizeof( ctBond * ) ) ;
		
		theData = [ pListDict objectForKey:@"originalBondPtrs" ] ;
		
		if( [ theData length ] == 8 * nBonds )
		{
			// Uh oh
			
			int j ;
			
			for( j= 0 ; j < nBonds ; ++j )
			{
				[ theData getBytes:(bonds + j) range:NSMakeRange(8*j, sizeof( ctBond * ))  ] ;
				
			}
		}
		else
		{
			[ theData getBytes:bonds length:(nBonds*sizeof( ctBond *)) ] ;
		}
		
		
		
		atBondStart = (BOOL *) malloc( nBonds * sizeof( BOOL ) ) ;
		
		theData = [ pListDict objectForKey:@"atBondStart" ] ;
		[ theData getBytes:atBondStart length:(nBonds*sizeof(BOOL)) ] ;
		
		theData = [ pListDict objectForKey:@"pathIndex" ] ;
		[ theData getBytes:&pathIndex length:sizeof(int) ] ;
		
		theData = [ pListDict objectForKey:@"fragmentIndex" ] ;
		[ theData getBytes:&fragmentIndex length:sizeof(int) ] ;
		
		// The following should be OK in 64 bits - MSB bytes hold data
		theData = [ pListDict objectForKey:@"fragmentTree" ] ;
		[ theData getBytes:&fragmentTree length:sizeof(ctTree *) ] ;
		
		return self ;
	}
		
		
		
- (NSString *) description
	{
		NSString *returnString = [ NSString stringWithFormat:@"ctNode: %x %d %@",
			self, index, [ self returnPropertyForKey:@"atomName" ] ] ;
			
		return returnString ;
	}
	
@end
