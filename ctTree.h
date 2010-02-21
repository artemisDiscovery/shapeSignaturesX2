//
//  ctTree.h
//  fftool
//
//  Created by Randy Zauhar on 5/11/09.
//  Copyright 2009 ArtemisDiscovery LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ctNode.h"
#import "ctBond.h"
#import "vector3.h"
 
#import "FFToolTypeDefs.h"
#import "bondPath.h"
#include <string.h>



//@class ctPath ;
@class fragment ;
// Here we define a complex tree

@interface ctTree : NSObject 
{
@public

		int nNodes, nNodeAlloc ;
		ctNode **nodes ;
		
		int nBonds, nBondAlloc ;
		ctBond **bonds ;
		
		NSMutableArray *maximalTreePaths ;
		
		int nFragments ;
		
		// I am going to "hardwire" ring closures, maximum of 99
		
		// The name "output" is due to copying from the stPath class - I will leave this for now. 
		
		BOOL haveRingClosures ;
		
		ctNode *outputRingClosure[100][2] ;
		int nOutputRingClosures ;
		
		// Some addtional machinery here - we will assign atoms (nodes) to fragments. This will 
		// be done by partitioning into ring systems, and the "remainder" pieces. Terminal pieces attached to 
		// rings will be grouped with the rings if there size falls below a specified threshold. 
		
		// The key/value pair "fragmentID" -> "R<#>" will be assigned to each ring system atom, 
		// ring substitutents will be asssigned key/value pair "fragmentID" -> "S<#>" where # matches th 
		// ring system, and the remainder will be assigned to non-Ring systems ("fragmentID" -> "NR<#>" ) .
		// We will also assign the property "InRing" as "YES/NO"
		
		// The fragments array will include pointers to ctTrees that correspond to all these pieces. 
		
		NSMutableArray *treeFragments ;
		
		
		NSString *treeName ;
		
		BOOL ring ;
		MMVector3 *normal, *center  ;


}

- (id) initTreeFromMOL2File:(char *)f ;

- (id) initEmptyTree ;

- (void) addBondBetweenNode:(ctNode *)n1 andNode:(ctNode *)n2 withType:(bondType)t ;

- (ctNode *) addNodeToTreeWithName:(char *)name  atNode:(ctNode *)nod withBondType:(bondType)bt ;

//- (ctPath *) extendPath:(ctPath *)p ;

//- (void) makeMaximalTree ;

- (void) makeRingClosures ;

- (int) ringClosureIndexForNode:(ctNode *)n1 andNode:(ctNode *)n2 ;

- (void) assignNodesToFragments ;

//- (ctTree *) subTreeWithNodes:(NSSet *)n ;

//- (ctTree *) extendSubTree:(ctTree *)t toIncludeSubstituentsNoBiggerThan:(int)max ;

//- (NSArray *) extendPathsFrom:(ctNode *)nS to:(ctNode *)nE excludeBond:(ctBond *)exclB ;

//- (NSArray *) extendPath:(ctPath *)p to:(ctNode *)e ;

//- (NSSet *) extendNewFragmentFromRoot:(ctNode *)r terminal:(BOOL *)term baseNode:(ctNode *)b ;

- (int) indexOfNode:(ctNode *) n ;

//- (void) assignTreeToFragmentIndex:(int)idx withFragmentType:(char *)t ;

- (void) printComplex ;

//- (double) dihedralBetweenFragment:(ctTree *)f1 andFragment:(ctTree *)f2  ;

- (int) heavyAtomCount ;

//- (void) addNormal ;

//- (void) adjustCoalescedTreeFragmentIndex:(int) idx ;

- (NSArray *) neighborFragmentsTo:(fragment *)f ;

+ (NSSet *) connectedSetFromBond:(ctBond *)seed usingBondSet:(NSMutableSet *)bSet excludeNodes:(NSSet *)excl ;


@end
