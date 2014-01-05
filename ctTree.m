//
//  ctTree.m
//  fftool
//
//  Created by Randy Zauhar on 5/11/09.
//  Copyright 2009 ArtemisDiscovery LLC. All rights reserved.
//

#import "ctTree.h"
//#import "ctPath.h"
#include <math.h>
#include "fragment.h"
#include "fragmentConnection.h"

//#define FRAGMENT_DEBUG

@implementation ctTree

- (id) initTreeFromMOL2File:(char *)f
	{
		self = [ super init ] ;
		
		nNodes = 0 ;
		nBonds = 0 ;
		
		nNodeAlloc = 50 ;
		nBondAlloc = 50 ;
		
		nodes = (ctNode **) malloc( nNodeAlloc * sizeof( ctNode * ) ) ;
		bonds = (ctBond **) malloc( nBondAlloc * sizeof( ctBond * ) ) ;
		
		maximalTreePaths = nil ;
		
		treeFragments = nil ;
		fragmentToNeighborData = nil ;
		
		
		normal = nil ;
		center = nil ;
		ring = NO ;
		
		nOutputRingClosures = 0 ;
		haveRingClosures = NO ;
		
		//fragmentIndex = -1 ;
		
		NSCharacterSet *nonChargeCharacterSet = [ [ NSCharacterSet characterSetWithCharactersInString:@"0123456789.+-" ] invertedSet ] ;
		
		nFragments = 0 ;
		
		FILE *mol2File = fopen( f, "r" ) ;
		
		if( ! mol2File )
			{
				printf( "COULD NOT OPEN MOL2 FILE!\n" ) ;
				return nil ;
			}
			
		// Look for next MOLECULE tag
		
		char buffer[1000] ;
		
		// NOTE that we will put all molecules into the same tree - this is not the only choice available. We could make 
		// a separate tree for each molecule. Maybe a flag in the future?
		
		while( TRUE )
			{
				BOOL foundMol = NO ;
				
				while( ! feof(mol2File) ) 
					{
						fgets( buffer, 1000, mol2File ) ;
						
						if( strstr(buffer, "@<TRIPOS>MOLECULE" ) )
							{
								foundMol = YES ;
								break ;
							}
					}
					
				if( foundMol == NO )
					{
						// Done
						
						fclose( mol2File ) ;
						
						return self ;
					}
					
				// Load atoms and bonds 
				
				fgets( buffer, 1000, mol2File ) ;	// Get the name - eliminate the new line
				
				char *pos = strstr( buffer, "\n" ) ;
				
				*pos = '\0' ;
				
				treeName = [ [ NSString alloc ] initWithCString:buffer ] ;
				
				fgets( buffer, 1000, mol2File ) ;
				
				char *token ;
				
				token = strtok( buffer, " \t\n\r" ) ;
				
				int nMOL2Atoms = 0 ;
				int nMOL2Bonds = 0 ;
				
				// We may be loading multiple molecules - how many nodes already loaded?
				
				int nNodesAlreadyLoaded = nNodes ;
				
				if( strlen( token ) == 0 )
					{
						token = strtok( NULL, " \t\n\r" ) ;
					}
				
				nMOL2Atoms = atoi( token ) ;
				
				token = strtok( NULL, " \t\n\r" ) ;
				
				nMOL2Bonds = atoi( token ) ;
				
				// Find start of atoms 
				
				BOOL foundAtoms = FALSE ;
				
				while( ! feof(mol2File) ) 
					{
						fgets( buffer, 1000, mol2File ) ;
						
						if( strstr(buffer, "@<TRIPOS>ATOM" ) )
							{
								foundAtoms = TRUE ;
								break ;
							}
					}
				
				if( foundAtoms == NO )
					{
						// Quit, with warning -
						
						printf( "WARNING - PREMATURE END OF MOL2 FILE - ATOMS NOT FOUND!\n" ) ;
						
						return self ;
					}
				
				int iAtom, i ;
				double X, Y, Z ;
				char atomType[10], element[10], atomName[10], residueIndex[10], residueName[20], chargeString[20] ;
				BOOL haveResidueIndex, haveResidueName, haveChargeString ;
				
				
				for( iAtom = 0 ; iAtom < nMOL2Atoms ; ++iAtom ) 
					{
						haveResidueIndex = NO ;
						haveResidueName = NO ;
						haveChargeString = NO ;
						
						// Need to parse more flexibly, treat as NSString
						
						NSCharacterSet *nonWhiteSpace = [ [ NSCharacterSet whitespaceCharacterSet ] invertedSet ] ;
						
						fgets( buffer, 1000, mol2File ) ;
						
						NSString *theLine = [ [ NSString stringWithCString:buffer ] 
											 stringByTrimmingCharactersInSet:[ NSCharacterSet newlineCharacterSet ] ] ;
						
						NSMutableArray *tokens = [ NSMutableArray arrayWithCapacity:10  ] ;
						
						NSScanner *theScanner = [ NSScanner scannerWithString:theLine ] ;
						
						NSString *nextToken ;
						
						while( [ theScanner scanCharactersFromSet:nonWhiteSpace intoString:&nextToken ] )
						{
							[ tokens addObject:nextToken ] ;
						}
						
						if( [ [ tokens objectAtIndex:0 ] length ] == 0 )
						{
							tokens = [ tokens subarrayWithRange:NSMakeRange(1, [ tokens count ] - 1) ] ;
						}
						
						// Last string assumed to be charge, tokens at 
						// 1 = atom name
						// 2 = X
						// 3 = Y
						// 4 = Z
						// 5 = type
						// 6 = residue index or charge?
						// If 6 is the last field, we will assume charge;
						// If max index >= 8, assume 6 and 7 are res index and name, 
						// last is charge
						
						strcpy( atomName, [ [ tokens objectAtIndex:1 ] cString ] ) ;
						X = [ [ tokens objectAtIndex:2 ] doubleValue ] ;
						Y = [ [ tokens objectAtIndex:3 ] doubleValue ] ;
						Z = [ [ tokens objectAtIndex:4 ] doubleValue ] ;
							   
						strcpy( atomType, [[ tokens objectAtIndex:5 ] cString ] ) ;
						strcpy( element, [[ tokens objectAtIndex:5 ] cString ] ) ;
							   
						if( [ tokens count ] <= 7 )
							   {
								   haveResidueName = NO ;
								   haveResidueIndex = NO ;
							   }
						else if( [ tokens count ] >= 8 )
							   {
								   haveResidueIndex = YES ;
								   strcpy( residueIndex, [[ tokens objectAtIndex:6 ] cString ] ) ;
							   }
						else if( [ tokens count ] >= 9 ) 
							   {
								   haveResidueName = YES ;
								   strcpy( residueName, [[ tokens objectAtIndex:7 ] cString ] ) ;
							   }
							   
							   
						// Check for illegal characters in charge string
							   
						NSRange illegal = [ [ tokens lastObject ] rangeOfCharacterFromSet:nonChargeCharacterSet ] ;
					   
					   if( illegal.location == NSNotFound )
					   {
						   haveChargeString = YES ;
						   strcpy( chargeString, [ [ tokens lastObject ] cString ] ) ;
					   }
					   else {
						   haveChargeString = NO ;
					   }
								   
						
						
						// Assume a period separates element name from hybridization
						
						token = strtok(element, ". \t\n\r" ) ;
						
						ctNode *nextNode = [ [ ctNode alloc ] initWithElement:token andIndex:(iAtom + 1) ] ;
						
						[ nextNode setX:X Y:Y Z:Z ] ;
						
						[ nextNode addPropertyValue:atomType forKey:"importType" ] ;
						[ nextNode addPropertyValue:atomName forKey:"atomName" ] ;
						
						if( haveResidueIndex == YES )
							{
								[ nextNode addPropertyValue:residueIndex forKey:"residueIndex" ] ;
							}
							
						if( haveResidueName == YES )
							{
								[ nextNode addPropertyValue:residueName forKey:"residueName" ] ;
							}
							
						if( haveChargeString == YES )
							{
								[ nextNode addPropertyValue:chargeString forKey:"charge" ] ;
								[ nextNode setCharge:atof(chargeString) ] ;
							}
						
						if( nNodes == nNodeAlloc )
							{
								nNodeAlloc += 50 ;
								
								nodes = (ctNode **) realloc( nodes, nNodeAlloc * sizeof( ctNode * ) ) ;
							}
							
						nodes[nNodes] = nextNode ;
						
						++nNodes ;
					}
				
				// SHOULD be at the bond tag
				
				fgets( buffer, 1000, mol2File ) ;
				
				if( ! strstr(buffer, "@<TRIPOS>BOND" ) )
					{
						printf( "WARNING - MOL2 FILE FORMAT CORRUPT - DID NOT FIND BOND TAG!\n" ) ;
						return self ;
					}
					
				int iBond ;
				
				for( iBond = 0 ; iBond < nMOL2Bonds ; ++iBond )
					{
						fgets( buffer, 1000, mol2File ) ;
						
						token = strtok(buffer, " \t\n\r" ) ;
						
						if( strlen( token ) == 0 )
							{
								token = strtok(NULL, " \t\n\r" ) ;
							}
							
						// Skip bond number
						
						token = strtok(NULL, " \t\n\r" ) ;
						
						int atom1 = atoi( token ) ;
						
						token = strtok(NULL, " \t\n\r" ) ;
						
						int atom2 = atoi( token ) ;
						
						int index1, index2 ;
						
						index1 = atom1 - nNodesAlreadyLoaded - 1 ;
						index2 = atom2 - nNodesAlreadyLoaded - 1 ;
						
						// Bond type 
						
						token = strtok(NULL, " \t\n\r" ) ;
						
						bondType nextType ;
						
						if( ! strcasecmp( token, "1" ) )
							{
								nextType = SINGLE ;
							}
						else if( ! strcasecmp( token, "2" ) )
							{
								nextType = DOUBLE ;
							}
						else if( ! strcasecmp( token, "3" ) )
							{
								nextType = TRIPLE ;
							}
						else if( ! strcasecmp( token, "ar" ) )
							{
								nextType = AROMATIC ;
							}
						else if( ! strcasecmp( token, "am" ) )
							{
								nextType = AMIDE ;	// Use the separate type, or just set to SINGLE?
							}
						else
							{
								nextType = UNKNOWN ;
							}
							
						// Add the node to the tree
						
						[ self addBondBetweenNode:nodes[index1] andNode:nodes[index2] withType:nextType ] ;
							
					}
					
				// Done with this molecule
		
			}
			
		fclose( mol2File ) ;
		
		return self ;
	}

- (id) initEmptyTree
	{
		self = [ super init ] ;
		
		nNodes = 0 ;
		nBonds = 0 ;
		
		nNodeAlloc = 50 ;
		nBondAlloc = 50 ;
		
		nodes = (ctNode **) malloc( nNodeAlloc * sizeof( ctNode * ) ) ;
		bonds = (ctBond **) malloc( nBondAlloc * sizeof( ctBond * ) ) ;
		
		maximalTreePaths = nil ;
		
		treeFragments = nil ;
		
		
		normal = nil ;
		center = nil ;
		ring = NO ;
		
		nOutputRingClosures = 0 ;
		haveRingClosures = NO ;
		
		//fragmentIndex = -1 ;
		
		nFragments = 0 ;
		
		return self ;
	}
	
- (void) dealloc
	{
		int i ;
		
		if( treeFragments )
			{
				if( fragmentToNeighborData ) [ fragmentToNeighborData release ] ;
				[ treeFragments release ] ;
			}
		

								
		
		for( i = 0 ; i < nNodes ; ++i )
			{
				[ nodes[i] release ] ;
			}
		
		for( i = 0 ; i < nBonds ; ++i )
			{
				[ bonds[i] release ] ;
			}
			
		free( nodes ) ;
		free( bonds ) ;
		
		if( fragmentConnections ) [ fragmentConnections release ] ;
		
		[ treeName release ] ;
		
		[ super dealloc ] ;
		
		return ;
	}


- (void) addBondBetweenNode:(ctNode *)n1 andNode:(ctNode *)n2 withType:(bondType)t
	{
		ctBond *newBond = [ [ ctBond alloc ] initWithNode1:n1 andNode2:n2 andType:t ] ;
		
		if( nBondAlloc == nBonds )
			{
				nBondAlloc += 50 ;
				bonds = (ctBond **) realloc( bonds, nBondAlloc * sizeof( ctBond * ) );
			}
		
		bonds[nBonds] = newBond ;
		++nBonds ;
		
		[ n1 addBond:newBond ] ;
		[ n2 addBond:newBond ] ;
		
		return ;
		
	}
		
- (ctNode *) addNodeToTreeWithName:(char *)name  atNode:(ctNode *)nod withBondType:(bondType)bt
	{
		ctNode *newNode = [ [ ctNode alloc ] initWithElement:name andIndex:(nNodes + 1) ] ;
		
		if( nNodes == nNodeAlloc )
			{
				nNodeAlloc += 50 ;
				nodes = (ctNode **) realloc( nodes, nNodeAlloc * sizeof( ctNode * ) ) ;
			}
		
		nodes[nNodes] = newNode ;
		++nNodes ;
		
		if( nod )
			{
				[ self addBondBetweenNode:newNode andNode:nod withType:bt ] ;
			}
		
		return newNode ;
	}

/*
- (ctPath *) extendPath:(ctPath *)p 
	{
		
		ctNode *lastNode = [ p lastNodeInPath ] ;
		
		ctPath *longestPath = [ [ ctPath alloc ] initWithCTPath:p ] ;
		
		int i ;
		
		for( i = 0 ; i < lastNode->nBonds ; ++i )
			{
				ctNode *nextChild ;
				ctBond *nextBond ;
				
				nextBond = lastNode->bonds[i] ;
				
				if( lastNode->atBondStart[i] == YES )
					{
						nextChild = nextBond->node2 ;
					}
				else
					{
						nextChild = nextBond->node1 ;
					}
					
				// Do not include hydrogen in path 
				
				if( strcasecmp( [ nextChild elementName ], "H" ) == 0 ) continue ;
				
				// I think that for efficiency we will terminate at any node already in a path
				
				if( nextChild->pathIndex >= 0 ) continue ;
				
				if( [ p pathIncludesNode:nextChild ] == YES ) continue ;
								
				// Try to extend ----
				
				ctPath *nextPath = [ [ ctPath alloc ] initWithCTPath:p ] ;
				
				[ nextPath extendWithNode:nextChild ] ;
				
				ctPath *returnPath = [ self extendPath:nextPath ] ;
					
				if( [ returnPath lengthOfPath ] > [ longestPath lengthOfPath ]  )
					{
						ctPath *tempPath = longestPath ;
						
						longestPath = returnPath ;
						
						[ tempPath release ] ;
					
					}
				else
					{
						[ returnPath release ] ;
					}
			}
				
		return longestPath ;
	}
			

- (void) makeMaximalTree
	{
		// This function will associate paths with the tree. The first node not assigned to a path will be used 
		// to initiate the next path. All the nodes in the next path will be assigned an index. 
		
		
		int currentIndex = 0 ;
		
		if( ! maximalTreePaths ) maximalTreePaths = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		
		while( TRUE )
			{
				ctNode *firstUnassigned = nil ;
				
				int i ;
				
				NSArray *neighborNodes = nil ;
				
				for( i = 0 ; i < nNodes ; ++i )
					{
						if( nodes[i]->pathIndex >= 0 )
							{
								continue ;
							}
							
						// Don't include hydrogens in paths
						
						if( strcasecmp([ nodes[i] elementName ], "H") == 0 )
							{
								continue ;
							}
							
						// IF there are any existing paths, we insist that this be a neighbor of some 
						// path
						
						if( [ maximalTreePaths count ] > 0 )
							{
								if( ! ( neighborNodes = [ nodes[i] neighborsWithPathIndexOtherThan:(-1) ] ) ) continue ;
							}
						
						firstUnassigned = nodes[i] ;
						
						break ;
					}
					
				if( ! firstUnassigned ) break ;
				
				// Initiate path with unassigned node; use first neighbor node as root (should only be one!)
				
				 if( [ maximalTreePaths count ] > 0 && ! neighborNodes ) printf( "WARNING - IN MAXIMAL TREE GENERATION, UNASSIGNED NODE WITH NO ROOT!\n" ) ; 
				
				ctPath *newPath = [ [ ctPath alloc ] initEmptyCTPathWithRoot:[ neighborNodes objectAtIndex:0 ] andTree:self ] ;
				
				[ newPath extendWithNode:firstUnassigned ] ;
				
				newPath = [ self extendPath:newPath ] ; // Memory leak?
				
				[ newPath assignPathIndex:currentIndex ] ;
				
				[ maximalTreePaths addObject:newPath ] ;
				
				++currentIndex ;
				
			}
			
		return ;
				
	}
*/
- (void) makeRingClosures
	{
		// This is a way more intelligent approach then I first implemented. I will make a TRUE maximal tree using 
		// BOND objects. (My previous implementation used maximal paths, and lots of special tests.)
		
		NSAutoreleasePool *localPool = [ [ NSAutoreleasePool alloc ] init ] ;
		
		NSMutableSet *bondSet = [ NSMutableSet setWithArray:[ NSArray arrayWithObjects:bonds count:nBonds ] ] ;
		
		NSMutableSet *nodeTargetSet = [ NSMutableSet setWithCapacity:nNodes ] ;
		NSMutableSet *deadTargetSet = [ NSMutableSet setWithCapacity:nNodes ] ;
		
		NSMutableSet *nodeSourceSet = [ NSMutableSet setWithArray:[ NSArray arrayWithObjects:nodes count:nNodes ] ] ;
		
		// Transfer first heavy-atom node from source to target
		
		
		ctNode *nextNode  ;
		
		NSEnumerator *nodeEnumerator = [ nodeSourceSet objectEnumerator ] ;
		
		while( ( nextNode = [ nodeEnumerator nextObject ] ) )
			{
				if( nextNode->atomicNumber > 1 ) break ;
			}
		
		if( ! nextNode )
			{
				printf( "NO HEAVY ATOMS - CANNOT MAKE RINGS\n" ) ;
				[ localPool drain ] ;
				return ;
			}
			
		[ nodeTargetSet addObject:nextNode ] ;
		[ nodeSourceSet removeObject:nextNode ] ;
				
		BOOL hadAddition = YES ;
		
		while( hadAddition == YES )
			{
				hadAddition = NO ;
				
				NSEnumerator *targetNodeEnumerator = [ nodeTargetSet objectEnumerator ] ;
				
				//printf( "Process current target nodes\n" ) ;
				
				while( ( nextNode = [ targetNodeEnumerator nextObject ] ) )
					{
						//printf( "Node: %s ", [ [ nextNode returnPropertyForKey:@"atomName" ] cString ] ) ;
						
						if( [ deadTargetSet member:nextNode ] ) 
							{
								//printf( " (dead)\n" ) ;
								continue ;
							}
						//else 
						//	{
						//		printf( " (alive)\n" ) ;
						//	}

						
						// Check if any neighbors not in target set
						
						int iBond ;
						ctNode *nextNeighbor ;
												
						for( iBond = 0 ; iBond < nextNode->nBonds ; ++iBond )
							{
								//printf( "\tCheck # %d  of %d bonds \n", iBond, nextNode->nBonds ) ;
								
								
									   
							   if( nextNode->atBondStart[iBond] == YES )
									{
										nextNeighbor = nextNode->bonds[iBond]->node2 ;
									}
							   else
									{
										nextNeighbor = nextNode->bonds[iBond]->node1 ;
									}
									
								//printf( "\tcheck connect to atom : %s\n", 
								//   [ [ nextNeighbor returnPropertyForKey:@"atomName" ] cString ] ) ;
								   
								if( ! [ bondSet member:nextNode->bonds[iBond] ] )
									{
										//printf( "\tThis connection already removed\n" ) ;
										continue ;
									}
									   
								if( ! [ nodeTargetSet member:nextNeighbor ]  )
									{
										hadAddition = YES ;
										
										[ nodeTargetSet addObject:nextNeighbor ] ;
										[ nodeSourceSet removeObject:nextNeighbor ] ;
										
										[ bondSet removeObject:nextNode->bonds[iBond] ] ;
										//printf( "\tADD this node and remove the bond\n" ) ;
									}
							}
							
						// IF no live bond, kill this node
						
						if( hadAddition == NO )
							{
								[ deadTargetSet addObject:nextNode ] ;
							}
						else
							{
								break ;
							}
					}
			}
			
		// Any bonds left in bondSet are ring closures
		
		nOutputRingClosures = 0 ;
		
		NSEnumerator *bondEnumerator = [ bondSet objectEnumerator ] ;
		
		ctBond *nextBond ;
		
		while( ( nextBond = [ bondEnumerator nextObject ] ) )
			{
				outputRingClosure[nOutputRingClosures][0] = nextBond->node1 ;
				outputRingClosure[nOutputRingClosures][1] = nextBond->node2 ;
				
				++nOutputRingClosures ;
			}
			
		haveRingClosures = YES ;
	
		[ localPool drain ] ;
			
		return ;
				
		
	}
	
/*
- (void) makeRingClosures
	{
		// Enumerate all paths - any node that neighbors a node which is NOT the first node in another path forms a ring closure.
		// Also, if a node is the FIRST in path k, and has TWO neighbors in k, then a ring closure is formed with the node other
		// than the second in the path; 
		// Also, if a node is LAST in path k, and has TWO neighbors in k, then a ring closure is formed with the node with 
		// lower path index (i.e. not the next-to-last )
		// Also, if a node has THREE neighbors from its own path, then the node with index-of-path more than one removed from 
		// the index of the current node is a path closure. 
		
		// Take care not to generate ring closures multiple times. 
		
		// Sanity check - paths never include hydrogens, so we don't need to fret about that. 
		
		ctPath *nextPath ;
		
		int pathIndex ;
		
		for( pathIndex = 0 ; pathIndex < [ maximalTreePaths count ] ; ++pathIndex )
			{
				nextPath = [ maximalTreePaths objectAtIndex:pathIndex ] ;
				
				int k ;
				
				ctNode *nextNode, *nextNeighbor ;
				NSArray *neighbors ;
				
				for( k = 0 ; k < [ nextPath lengthOfPath ] ; ++k )
					{
						nextNode = [ nextPath->nodesInPath objectAtIndex:k ] ;
						
						// Get any neighbors in other paths
						
						neighbors = [ nextNode neighborsWithPathIndexOtherThan:pathIndex ] ;
						
						if( neighbors )
							{
								int j ;
								
								for( j = 0 ; j < [ neighbors count ] ; ++j )
									{
										nextNeighbor = [ neighbors objectAtIndex:j ] ;
										
										ctPath *neighborPath = [ maximalTreePaths objectAtIndex:nextNeighbor->pathIndex ] ;
										
										// Check if current node is the root node of the neighboring path, OR if the neighbor is the 
										// root node of the current path
										
										// Special situation - if the neigbor path begins and ends at nextNode, we have a ring
										// closure by default
										
										if( nextNode == neighborPath->rootNode && nextNeighbor == neighborPath->lastNode
												&& [neighborPath lengthOfPath ] > 1 )
											{
												// Special ring closure!
											}
										else
											{
												if( neighborPath->rootNode == nextNode ) continue ;
												if( nextPath->rootNode == nextNeighbor ) continue ;
											}
										
										// MAY have a new closure
										
										int closureIndex = [ self ringClosureIndexForNode:nextNode andNode:nextNeighbor ] ;
										
										if( closureIndex < 0 )
											{
												// Add a ring closure - note that we index from 1 to match SMILES
												// expectation
												
												++nOutputRingClosures ;
												
												outputRingClosure[nOutputRingClosures][0] = nextNode ;
												outputRingClosure[nOutputRingClosures][1] = nextNeighbor ;
											}
									}
									
								[ neighbors release ] ;
							}
							
						// Check if we have closure with current path
						
						neighbors = [ nextNode neighborsWithPathIndex:pathIndex ] ;
						
						if( ! neighbors ) continue ;
						
						//NSArray *nextPathNodes = nextPath->nodesInPath ;
						
						int nextIndex, closureIndex ;
						ctNode *closureNeighbor ;
						
						if( k == 0 )
							{
								if( [ neighbors count ] == 2 )
									{
										// Ring closure with neighbor with highest index
										
										closureNeighbor = nil ;
										
										int maxIndex = -1 ;
										
										if( ( nextIndex = [ nextPath->nodesInPath indexOfObject:[ neighbors objectAtIndex:0 ] ] ) > maxIndex )
											{ maxIndex = nextIndex ; closureNeighbor = [ neighbors objectAtIndex:0 ] ; }
											
										if( ( nextIndex = [ nextPath->nodesInPath indexOfObject:[ neighbors objectAtIndex:1 ] ] ) > maxIndex )
											{ maxIndex = nextIndex ; closureNeighbor = [ neighbors objectAtIndex:1 ] ; }
									
									
										closureIndex = [ self ringClosureIndexForNode:nextNode andNode:closureNeighbor ] ;
										
										if( closureIndex < 0 )
											{
												++nOutputRingClosures ;
																
												outputRingClosure[nOutputRingClosures][0] = nextNode ;
												outputRingClosure[nOutputRingClosures][1] = closureNeighbor ;
											}
									}
							}
						else if( k == [ nextPath lengthOfPath ] - 1 )
							{
								if( [ neighbors count ] == 2 )
									{
										// Ring closure with neighbor with lowest index
										
										int minIndex = 1e6 ;
										closureNeighbor = nil ;
										
										if( ( nextIndex = [ nextPath->nodesInPath indexOfObject:[ neighbors objectAtIndex:0 ] ] ) < minIndex )
											{ minIndex = nextIndex ; closureNeighbor = [ neighbors objectAtIndex:0 ] ; }
											
										if( ( nextIndex = [ nextPath->nodesInPath indexOfObject:[ neighbors objectAtIndex:1 ] ] ) < minIndex )
											{ minIndex = nextIndex ; closureNeighbor = [ neighbors objectAtIndex:1 ] ; }
									
									
										closureIndex = [ self ringClosureIndexForNode:nextNode andNode:closureNeighbor ] ;
										
										if( closureIndex < 0 )
											{
												++nOutputRingClosures ;
																
												outputRingClosure[nOutputRingClosures][0] = nextNode ;
												outputRingClosure[nOutputRingClosures][1] = closureNeighbor ;
											}
									}
							}
						else if( [ neighbors count ] >  2 )
							{
								// Ring closure with neighbors with index != k - 1 and != k + 1
								
								int j ;
								closureNeighbor = nil ;
								
								for( j = 0 ; j < [ neighbors count ] ; ++j )
									{
										nextIndex = [ nextPath->nodesInPath indexOfObject:[ neighbors objectAtIndex:j ] ] ;
										
										if( nextIndex != k - 1 && nextIndex != k + 1 )
											{
												closureNeighbor = [ neighbors objectAtIndex:j ] ;
												
												closureIndex = [ self ringClosureIndexForNode:nextNode andNode:closureNeighbor ] ;
								
												if( closureIndex < 0 )
													{
														++nOutputRingClosures ;
																		
														outputRingClosure[nOutputRingClosures][0] = nextNode ;
														outputRingClosure[nOutputRingClosures][1] = closureNeighbor ;
													}
												
											}
									}
									
								
							}
							
						[ neighbors release ] ;
						
					}
			}
			
		return ;
	}

	
- (int) ringClosureIndexForNode:(ctNode *)n1 andNode:(ctNode *)n2
	{
		int i ;
		
		for( i = 1 ; i <= nOutputRingClosures ; ++i )
			{
				if( ( outputRingClosure[i][0] == n1 && outputRingClosure[i][1] == n2 ) ||
					( outputRingClosure[i][0] == n2 && outputRingClosure[i][1] == n1 ) )
					{
						return i ;
					}
			}
			
		return -1 ;
	}
*/


- (void) assignNodesToFragmentsByMergingNeighborRings:(BOOL)merge forceOneFragment:(BOOL)oneFrag
	{
	
#define MAX_SUBST_SIZE 5

		if( ! treeFragments )
			{
				treeFragments = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
				fragmentToNeighborData = [ [ NSMutableDictionary alloc ] initWithCapacity:10 ] ;
			}
			
		nFragments = 0 ;
		
		NSAutoreleasePool *localPool = [ [ NSAutoreleasePool alloc ] init ] ;
		
		// We need to make sure we have maximal trees and rings
		
		if( haveRingClosures == NO && oneFrag == NO )
			{
				[ self makeRingClosures ] ;
			}
			
		if( nOutputRingClosures == 0 || oneFrag == YES )
			{	
			
				// The whole thing is one big fragment
				
				fragment *theFragment = [ [ fragment alloc ] initWithBonds:[ NSSet setWithObjects:bonds count:nBonds ] 
																   andType:SUBSTITUENT inTree:self ] ;
										
				[ treeFragments addObject:theFragment ] ;
				[ theFragment release ] ;
					
				
			}
		else
			{
				// Process rings
				
				int j, k ;
								
				NSMutableSet *remainingBonds = [ [ NSMutableSet alloc ] initWithObjects:bonds count:nBonds ] ;
				NSMutableSet *fragmentBonds = [ [ NSMutableSet alloc ] initWithCapacity:nBonds ] ;
				
				NSMutableArray *activePaths = [ [ NSMutableArray alloc ] initWithCapacity:nBonds ] ;
				NSMutableArray *fragmentPaths = [ [ NSMutableArray alloc ] initWithCapacity:nBonds ] ;
				NSMutableArray *removePaths = [ [ NSMutableArray alloc ] initWithCapacity:nBonds ] ;
				NSMutableArray *addPaths = [ [ NSMutableArray alloc ] initWithCapacity:nBonds ] ;

#ifdef FRAGMENT_DEBUG
				printf( "FIND FRAGMENTS ITERATIVELY:\n" ) ;
#endif
				
				for( j = 0 ; j < nOutputRingClosures ; ++j )
					{
#ifdef FRAGMENT_DEBUG
						printf( "RING CLOSURE:%d\n", j ) ;
#endif
						
						// I am going to implement an iterative approach here. I will seed an array with initial bond paths using 
						// the bonds at the ends of the ring closure. These paths will be extended until they 
						//	a) hit bonds already in fragments
						//  b) include the ring closure (i.e. we made a closed path)
						//	c) there are no bonds available to extend with
						
						[ activePaths removeAllObjects ] ;
						[ fragmentPaths removeAllObjects ] ;
						[ removePaths removeAllObjects ] ;
						[ addPaths removeAllObjects ] ;
						
						// New path with each bond at node2 of ring closure, not including the ring closure bond
						
						ctBond *ringClosureBond = [ outputRingClosure[j][0]  returnBondWithNode:outputRingClosure[j][1] ] ;
						
#ifdef FRAGMENT_DEBUG
						NSLog( @"CLOSURE BOND:%@\n", [ ringClosureBond description ] ) ;
#endif
						
						for( k = 0 ; k < ringClosureBond->node2->nBonds ; ++k )
							{
								ctBond *nextBond = ringClosureBond->node2->bonds[k] ;
								
								if( nextBond == ringClosureBond ) continue ;
								
								// If one of the atoms is hydrogen, skip
								
								if( nextBond->node1->atomicNumber == 1 ||
									nextBond->node2->atomicNumber == 1 ) continue ;
								
								if( [ fragmentBonds member:nextBond ] )
									{
										continue ;
									}
									
								// Start new path
								
								bondPath *newPath = [ [ bondPath alloc ] initWithTree:self ] ;
								
								[ newPath addBond:nextBond rootNode:ringClosureBond->node2 ] ;
								
								[ activePaths addObject:newPath ] ;
								[ newPath release ] ;
							}
							
#ifdef FRAGMENT_DEBUG
						NSLog( @"INITIAL PATHS:%@\n", [ activePaths description ] ) ;
#endif
							
						// Now extend paths
						
						BOOL hadExtend = YES ;
						
						while( hadExtend == YES )
							{
								hadExtend = NO ;
								
								NSEnumerator *pathEnumerator = [ activePaths objectEnumerator ] ;
								
								bondPath *nextPath ;
								
								while( ( nextPath = [ pathEnumerator nextObject ] ) )
									{
										NSArray *candidates = [ nextPath extendBonds ] ;
										
										NSEnumerator *candidateEnumerator = [ candidates objectEnumerator ] ;
										
										ctBond *nextCandidate ;
										
										NSMutableArray *keepCandidates = [ NSMutableArray arrayWithArray:candidates ] ;
																				
										while( ( nextCandidate = [ candidateEnumerator nextObject ] ) )
											{
												if( nextCandidate == ringClosureBond )
													{
														// Made a complete path!
														
														hadExtend = YES ;
														
														bondPath *fragmentPath = [ [ bondPath alloc ]
															initWithBondPath:nextPath ] ;
															
														[ fragmentPath addBond:nextCandidate rootNode:[ fragmentPath endNode ] ] ;
														[ fragmentPaths addObject:fragmentPath ] ;
														[ fragmentPath release ] ;
														
														[ keepCandidates removeObject:nextCandidate ] ;
														
													}
												else if( [ fragmentBonds member:nextCandidate ] )
													{
														[ keepCandidates removeObject:nextCandidate ] ;
													}
											}
											
										// Any candidates left?
										
										if( [ keepCandidates count ] > 0 )
											{
												// Create new paths based on candidates
												
												hadExtend = YES ;
												
												for( k = 0 ; k < [ keepCandidates count ] ; ++k )
													{
														bondPath *newPath = 
															[ [ bondPath alloc ] initWithBondPath:nextPath ] ;
															
														[ newPath addBond:[ keepCandidates objectAtIndex:k ]
															rootNode:[ nextPath endNode ] ] ;
															
														[ addPaths addObject:newPath ] ;
														[ newPath release ] ;
													}
																							
										
											}
											
										[ removePaths addObject:nextPath ] ;
									}
													
								// Update active paths
								
								[ activePaths removeObjectsInArray:removePaths ] ;
								[ activePaths addObjectsFromArray:addPaths ] ;
								
								[ removePaths removeAllObjects ] ;
								[ addPaths removeAllObjects ] ;
							}
							
#ifdef FRAGMENT_DEBUG
						NSLog( @"PATHS AFTER EXTENSION:%@\n", [ fragmentPaths description ] ) ;
#endif
							
						// Create new fragment based on bonds in fragmentPaths paths
						
						[ fragmentBonds removeAllObjects ] ;
						
						// It may happen that previous fragment addition removed all paths for
						// this ring closure
						
						if( [ fragmentPaths count ] == 0 ) continue ;
						
						NSEnumerator *pathEnumerator = [ fragmentPaths objectEnumerator ] ;
						
						bondPath *nextPath ;
						
						while( ( nextPath = [ pathEnumerator nextObject ] ) )
							{
								[ fragmentBonds unionSet:[ NSSet setWithArray:nextPath->bonds ] ] ;
							}
							
						fragment *theFragment = [ [ fragment alloc ] initWithBonds:fragmentBonds  
										andType:RING inTree:self ] ;
														
						[ treeFragments addObject:theFragment ] ;
						
						[ theFragment release ] ;
					
						
						[ remainingBonds minusSet:fragmentBonds ] ;
					}
					
				[ activePaths release ] ;
				[ fragmentPaths release ] ;
				[ removePaths release ] ;
				[ addPaths release ] ;
								
				fragment *removeFragment = nil ;
			
				// Check if rings share common atom - if yes, combine into one fragment
				
				BOOL haveJoin = YES ;
				
				while( haveJoin == YES )
					{
						haveJoin = NO ;
						
						removeFragment = nil ;
						
						NSEnumerator *ringEnumerator = [ treeFragments objectEnumerator ] ;
						
						fragment *nextRing ;
						
						while( ( nextRing = [ ringEnumerator nextObject ] ) )
							{
								NSArray *neighborRingData = [ self neighborDataForFragment:nextRing  ] ;
								
								if( [ neighborRingData count ] > 0 )
									{
										fragment *joinFragment = [ [ neighborRingData lastObject ] objectAtIndex:0 ] ;
										
										[ nextRing mergeFragment:joinFragment ] ;
										
										removeFragment = joinFragment ;
										
										haveJoin = YES ;
										
										break ;
									}
								
							}
							
						if( removeFragment ) [ treeFragments removeObject:removeFragment ] ;
						
						
					}
					
				// Have all the ring fragments - enumerate remaining bonds, and expand each into connected set. 
				// Those that are smaller than or equal in size to MAX_SUBST_SIZE and neighbor only one fragment will
				// be incorporated as substituents - otherwise add as non-ring fragment
				
				// Take additional care - two rings may be connected by a single bond, in which case that bond does 
				// not form a new fragment
				
				// Need set of all nodes currently assigned to fragments
				
				NSMutableSet *currentNodes = [ [ NSMutableSet alloc ] initWithCapacity:nNodes ] ;
				
				NSEnumerator *fragmentEnumerator = [ treeFragments objectEnumerator ] ;
				
				fragment *nextFragment ;
				
				while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
					{
						[ currentNodes unionSet:nextFragment->fragmentNodes ] ;
					}
				
				NSSet *initialRemainder = [ [ NSSet alloc ] initWithSet:remainingBonds ] ;
				
#ifdef FRAGMENT_DEBUG				
				NSLog( @"REMAINING BONDS: %@", [ remainingBonds description ] ) ;
#endif
				
				ctBond *nextBond ;
				
				NSEnumerator *bondEnumerator = [ initialRemainder objectEnumerator ] ;
				
				while( ( nextBond = [ bondEnumerator nextObject ] ) )
					{
						if( ! [ remainingBonds member:nextBond ] ) continue ;
						
#ifdef FRAGMENT_DEBUG
						NSLog( @"Process unassigned bond %@\n", [ nextBond description ] ) ;
#endif
												
													
						NSSet *nonRingSet = [ ctTree connectedSetFromBond:nextBond usingBondSet:remainingBonds
							excludeNodes:currentNodes ] ;
							
#ifdef FRAGMENT_DEBUG
						NSLog( @"Expand to form set %@", [ nonRingSet description ] ) ;
#endif
						
						if( [ nonRingSet count ] == 0 ) continue ;
								
						
						fragment *nextFragment = [ [ fragment alloc ] initWithBonds:nonRingSet 
													andType:NONRING inTree:self ] ;
					
						NSArray *neighborData = [ self neighborDataForFragment:nextFragment ] ;
						
													
						[ remainingBonds minusSet:nonRingSet ] ;
													
						if( [ nextFragment heavyAtomCount ] <= MAX_SUBST_SIZE )
							{
								// See if only one ring neighbor (if two substituents are connected to the ring, they can still
								// see each other, so we need to check specifically for a ring neighbor)
								
								int neighborRingCount = 0 ;
								fragment *lastNeighborRing ;
								
								NSEnumerator *neighborFragmentBundleEnumerator = [ neighborData objectEnumerator ] ;
								NSArray *nextNeighborFragmentBundle ;
								
								while( ( nextNeighborFragmentBundle = [ neighborFragmentBundleEnumerator nextObject ] ) )
									{
										fragment *nextNeighborFragment = [ nextNeighborFragmentBundle objectAtIndex:0 ] ;
										
										if( nextNeighborFragment->type == RING )
											{
												lastNeighborRing = nextNeighborFragment ;
												++neighborRingCount ;
											}
									}
#ifdef FRAGMENT_DEBUG
								printf( "Number of rings neighbors this set = %d",
									  neighborRingCount ) ;
#endif
																
								if( neighborRingCount == 1 )
									{
										[ lastNeighborRing mergeFragment:nextFragment ] ;
										[ nextFragment release ] ;
#ifdef FRAGMENT_DEBUG
										NSLog( @"Merge into fragment %@", [ lastNeighborRing description ] ) ;
#endif										
									}
								else
									{
										[ treeFragments addObject:nextFragment ] ;
										[ nextFragment release ] ;
#ifdef FRAGMENT_DEBUG										
										NSLog( @"Add new fragment %@", [ nextFragment description ] ) ;
#endif										
									}
							}
						else
							{
								[ treeFragments addObject:nextFragment ] ;
								[ nextFragment release ] ;
							}
								
								
						
					}
					
				// Now assign fragment neighbors
				
				
				// There is a choice here - merge rings that are connected by a 1-bond (empty) fragment, or 
				// just remove the empty fragment. 'merge' parameter controls this
				
				// If one-bond neighbor rings are NOT merged, we need a special operation to detect 
				// neighbors - this will be done using the one-bond fragments we removed
				
				NSMutableArray *oneBondFragments = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
				
				if( merge == YES )
					{
						haveJoin = YES ;
						
						while( haveJoin == YES )
							{
								haveJoin = NO ;
						
								fragmentEnumerator = [ treeFragments objectEnumerator ] ;
								
								fragment *mergeRing, *removeRing ;
						
								while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
									{
										if( [ nextFragment->fragmentBonds count ] == 1 )
											{
												haveJoin = YES ;
												
												NSArray *rings = [ self neighborDataForFragment:nextFragment ] ;
												
												// Must be two fragments
												
												mergeRing = [ [ rings objectAtIndex:0 ] objectAtIndex:0 ] ;
												removeRing = [ [ rings objectAtIndex:1 ] objectAtIndex:0 ] ;
																								
												break ;
											}
									}
									
								if( haveJoin == YES )
									{
										[ mergeRing mergeFragment:removeRing ] ;
										[ treeFragments removeObject:removeRing ] ;
										[ treeFragments removeObject:nextFragment ] ;
									}
							}
					}
				else
					{
						fragmentEnumerator = [ treeFragments objectEnumerator ] ;
						
						while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
							{
								if( [ nextFragment->fragmentBonds  count ] == 1 )
									{
										[ oneBondFragments addObject:nextFragment ] ;
									}
							}
							
						[ treeFragments removeObjectsInArray:oneBondFragments ] ;
					}
					
					
				// Now assign all neighbors
				
				fragmentEnumerator = [ treeFragments objectEnumerator ] ;
				
				while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
					{
						NSArray *neighborData = [ self neighborDataForFragment:nextFragment ] ;
						[ fragmentToNeighborData setObject:neighborData forKey:[ NSValue valueWithPointer:nextFragment ] ] ;
						[ nextFragment adjustNodesByNeighbors ] ;
					}
					
				// Use any entries of oneBondFragments to add neighbor relationships
				
				fragmentEnumerator = [ oneBondFragments objectEnumerator ] ;
				fragment *nextOneBondFragment ;

				
				while( ( nextOneBondFragment = [ fragmentEnumerator nextObject ] ) )
					{
						fragment *fOne = nil ;
						ctNode *nodeOne = nil ;
						fragment *fTwo = nil ;
						ctNode *nodeTwo = nil ;
						
						NSEnumerator *targetFragmentEnumerator = [ treeFragments objectEnumerator ] ;
						
						fragment *nextTargetFragment ;
						
						while( ( nextTargetFragment = [ targetFragmentEnumerator nextObject ] ) )
							{
								if( [ nextOneBondFragment->fragmentNodes 
									intersectsSet:nextTargetFragment->fragmentNodes ] == YES )
									{
										if( ! fOne ) 
											{
												fOne = nextTargetFragment ;
												NSMutableSet *testSet = [ NSMutableSet setWithSet:nextOneBondFragment->fragmentNodes ] ;
												[ testSet intersectSet:nextTargetFragment->fragmentNodes ] ;
												nodeOne = [ testSet anyObject ] ;
											}
										else if( ! fTwo )
											{
												fTwo = nextTargetFragment ;
												NSMutableSet *testSet = [ NSMutableSet setWithSet:nextOneBondFragment->fragmentNodes ] ;
												[ testSet intersectSet:nextTargetFragment->fragmentNodes ] ;
												nodeTwo = [ testSet anyObject ] ;
											}
										else
											{
												printf( "ERROR ASSIGNING NEIGHBOR FRAGMENT FROM ONE-BOND FRAGMENT!\n" ) ;
											}
									}
							}
									
						if( fOne && fTwo )
							{
								[ [ fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:fOne ] ]
									addObject:[ NSArray arrayWithObjects:fTwo,
											   [ NSSet setWithObjects:nodeOne,nil ] ,nil] ] ;
							
								 [ [ fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:fTwo ] ]
								 addObject:[ NSArray arrayWithObjects:fOne,
											[ NSSet setWithObjects:nodeTwo,nil ],nil ] ] ;
							}
					}
					
				[ oneBondFragments release ] ;
					
					
				// Adjust fragment types
				
				fragmentEnumerator = [ treeFragments objectEnumerator ] ;
				
				while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
					{
						[ nextFragment assignNonRingFragmentType ] ;
					}
				
				fragmentEnumerator = [ treeFragments objectEnumerator ] ;
				
				while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
					{
						[ nextFragment assignRingFragmentType ] ;
					}
					
					
				[ initialRemainder release ] ;
				[ remainingBonds release ] ;
				[ currentNodes release ] ;
				[ fragmentBonds release ] ;
			}
			
		
		
		
		// Assign the nodes/atoms to fragments
		
		NSEnumerator *fragmentEnumerator = [ treeFragments objectEnumerator ] ;
		fragment *nextFragment ;
		
		nFragments = 0 ;
		int nextFragmentIndex = 1 ;
		
		while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
			{
				[ nextFragment assignFragmentIndex:nextFragmentIndex ] ;
				++nextFragmentIndex ;
				++nFragments ;
			}
		
		// For later convenience, we set a set of all the neighbor fragment indices, saved as strings
 
		fragmentEnumerator = [ treeFragments objectEnumerator ] ;
 
		while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
			{
				[ nextFragment assignNeighborFragmentIndices ] ;
			}
 
		// For later generation of histogram groups, generate connection objects between fragments
 
		[ self makeFragmentConnections ] ;			
		
		[ localPool release ] ;
		
		return ;
		
	}

- (void) assignNodesToFragmentsUsingFile:(NSString *)frag 
	{
		// This will allow custom assignment of atoms to fragments. I am breaking with tradition, and assigning all 
		// atoms to "fragment 0" if not explictly assigned. Fragment 0 is ignored when generating ray traces (associate with 
		// "dead" molecular surface)
	
		NSAutoreleasePool *localPool = [ [ NSAutoreleasePool alloc ] init ] ;
	
		if( ! treeFragments )
			{
				treeFragments = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
				fragmentToNeighborData = [ [ NSMutableDictionary alloc ] initWithCapacity:10 ] ;
			}
		
		nFragments = 0 ;
		
		// Assign nodes to fragment index first
		
		int j, atomNum, fragNum ;
		
		for ( j = 0 ; j < nNodes ; ++j ) {
			
			nodes[j]->fragmentIndex = 0 ;
		}
		
		// Parse the file, assign nodes to fragments
		// (Simple format, 1-based atom index followed by fragment index)
		
		NSString *fragmentFile = [ NSString stringWithContentsOfFile:frag ] ;
		
		if( ! fragmentFile ) return ;
		
		NSScanner *fileScanner = [ NSScanner scannerWithString:fragmentFile ] ;
		
		[ fileScanner setCharactersToBeSkipped:[ NSCharacterSet whitespaceAndNewlineCharacterSet ] ] ;
		
		int maxFrag = 0 ;
		
		while( [ fileScanner scanInt:&atomNum ] == YES )
			{
				if( [ fileScanner scanInt:&fragNum ] == NO )
					{
						printf( "ERROR - Fragment file format messed up!\n" ) ;
                        [ localPool drain ] ;
						return nil ;
					}
			
				if ( fragNum > maxFrag ) {
					maxFrag = fragNum ;
				}
				
				nodes[ atomNum - 1 ]->fragmentIndex = fragNum ;
			}
		
		if( [ fileScanner isAtEnd ] == NO )
			{
				printf( "ERROR - Fragment file format messed up!\n" ) ;
                [ localPool drain ] ;
				return nil ;
			}
		
		NSMutableSet **fragNumToBonds = (NSMutableSet **) malloc(( maxFrag + 1) * sizeof( NSMutableSet * ) ) ;
		
		for( j = 1 ; j <= maxFrag ; ++j )
			{
				fragNumToBonds[j] = [ NSMutableSet setWithCapacity:nBonds ] ;
			}
		
		// Collect bonds for each fragment, make the trees
		
		NSMutableSet *remainingBonds = [ [ NSMutableSet alloc ] initWithObjects:bonds count:nBonds ] ;
		
		// Any bond that involves same fragment ID adds to that bond set
		
		for( j = 0 ; j < nBonds ; ++j ) {
			
			if ( bonds[j]->node1->fragmentIndex == bonds[j]->node2->fragmentIndex  )   {
				[ fragNumToBonds[bonds[j]->node1->fragmentIndex] addObject:bonds[j] ] ;
			}
		}
		
		// Remove the fragment bonds from the starting bond set - what is left over are bonds that connect different fragments
		
		for( j = 0 ; j <= maxFrag ; ++j ) {
			[ remainingBonds minusSet:fragNumToBonds[j] ] ;
		}
	
		// Add fragments to tree
	
		// Note we will ignore fragment 0
	
		for( j = 1 ; j <= maxFrag ; ++j ) {
			fragment *nextFragment = [ [ fragment alloc ] initWithBonds:fragNumToBonds[j] 
																andType:NONRING inTree:self ] ;
			nextFragment->index = j ;
			[ treeFragments addObject:nextFragment ] ;
			[ nextFragment release ] ;
		}
	
		// Fragment neighbors will be determined by remaining bonds. Note that it is possible for remaining
		// bonds to define the same fragment neighbor relationships multiple times. Build a fragment neighbor dictionary using the
		// fragment indices in sorted order, then add the neighbor information to the tree
	
		NSMutableDictionary *connectionDict = [ [ NSMutableDictionary alloc ] initWithCapacity:maxFrag ] ;
	
		for ( ctBond *nextBond in remainingBonds ) {
			int index1, index2 ;
			fragment *frag1, *frag2 ;
			ctNode *node1, *node2 ;
			
			if (nextBond->node1->fragmentIndex == 0 || nextBond->node2->fragmentIndex == 0) {
				continue ;
			}
			
			if (nextBond->node1->fragmentIndex < nextBond->node2->fragmentIndex) {
				index1 = nextBond->node1->fragmentIndex ;
				frag1 = [ treeFragments objectAtIndex:(index1 - 1) ] ; // No fragment 0
				node1 = nextBond->node1 ;
				index2 = nextBond->node2->fragmentIndex ;
				frag2 = [ treeFragments objectAtIndex:(index2 - 1) ] ; // No fragment 0
				node2 = nextBond->node2 ;
			}
			else {
				index1 = nextBond->node2->fragmentIndex ;
				frag1 = [ treeFragments objectAtIndex:(index1 - 1) ] ;	// No fragment 0
				node1 = nextBond->node2 ;
				index2 = nextBond->node1->fragmentIndex ;
				frag2 = [ treeFragments objectAtIndex:(index2 - 1) ] ;	// No fragment 0
				node2 = nextBond->node1 ;
			}
			
			NSString *key = [ NSString stringWithFormat:@"%d_%d",index1,index2 ] ;
			
			if (! [ connectionDict objectForKey:key ] ) {
				[ connectionDict setObject:[ NSArray arrayWithObjects:[ NSArray arrayWithObjects:frag2,frag1,node2,nil ],
											[ NSArray arrayWithObjects:frag1,frag2,node1,nil ],nil ]  forKey:key ] ;
			}
		}
	
		// Add the neighbor relationships
	
		for( NSArray *neighborArray in [ connectionDict allValues ] ) {
			for( NSArray *neighbor in neighborArray ) {
				fragment *fOne = [ neighbor objectAtIndex:0 ] ;
				fragment *fTwo = [ neighbor objectAtIndex:1 ] ;
				ctNode *nodeOne = [ neighbor objectAtIndex:2 ] ;
				
				if (! [ fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:fOne ] ] ) {
					[ fragmentToNeighborData setObject:[NSMutableArray arrayWithCapacity:maxFrag ] forKey:[ NSValue valueWithPointer:fOne ] ]  ;
				}
				
				[ [ fragmentToNeighborData objectForKey:[ NSValue valueWithPointer:fOne ] ]
				 addObject:[ NSArray arrayWithObjects:fTwo,
							[ NSSet setWithObjects:nodeOne,nil ] ,nil] ] ;
			}
			
			
		}
	
		nFragments = [ treeFragments count ] ;
		
		// Still need some additional stuff here
		
		// For later convenience, we set a set of all the neighbor fragment indices, saved as strings
		
		for( fragment *nextFragment in treeFragments  )
			{
				[ nextFragment assignNeighborFragmentIndices ] ;
			}
		
		// For later generation of histogram groups, generate connection objects between fragments
		
		[ self makeFragmentConnections ] ;		
	
		[ remainingBonds release ] ;
	
		[ connectionDict release ] ; // From static analyzer
	
		free( fragNumToBonds ) ;
		
        [ localPool drain ] ;
		
		return ;
		
		
	
	}
	
- (void) makeFragmentConnections
	{
 
		fragmentConnections = [ [ NSMutableArray alloc ] initWithCapacity:[ treeFragments count ] ] ;
 
		NSEnumerator *fragmentEnumerator = [ treeFragments objectEnumerator ] ;
 
		fragment *nextFragment ;
 
		while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
			{
				NSEnumerator *neighborIndexEnumerator = 
					[ nextFragment->neighborFragmentIndices objectEnumerator ] ;
 
				NSString *nextNeighborIndex ;
 
				while( ( nextNeighborIndex = [ neighborIndexEnumerator nextObject ] ) )
					{
						fragment *nextNeighborFragment = [ treeFragments 
								objectAtIndex:( [ nextNeighborIndex intValue ] - 1 ) ] ;
 
						// Connection already?
 
						BOOL foundConnect = NO ;
 
						NSEnumerator *connectionEnumerator = [ fragmentConnections objectEnumerator ] ;
 
						fragmentConnection *nextConnection ;
 
						while( ( nextConnection = [ connectionEnumerator nextObject ] ) )
							{
								NSSet *frags = [ nextConnection linkedFragments ] ;
 
								if( [ frags member:nextFragment ] && [ frags member:nextNeighborFragment ] )
									{
										foundConnect = YES ;
										break ;
									}
							}
 
						if( foundConnect == NO )
							{
								// Make new connection 
 
								fragmentConnection *newConnection = [ [ fragmentConnection alloc ]
									initWithFirst:nextFragment second:nextNeighborFragment ] ;
 
								[ fragmentConnections addObject:newConnection ] ;
								[ newConnection release ] ;
							}
					}
 
 
			}
 
 
		return ;
	}
				
+ (NSSet *) connectedSetFromBond:(ctBond *)seed usingBondSet:(NSMutableSet *)bSet excludeNodes:(NSSet *)excl
	{
		NSMutableSet *returnSet = [ NSMutableSet setWithCapacity:[ bSet count ] ] ;
		
		[ returnSet addObject:seed ] ;
		
		NSMutableSet *nodeSet = [ [ NSMutableSet alloc ] initWithCapacity:[ bSet count ]  ] ;
		
		if( ! [ excl member:seed->node1 ] )
			{
				[ nodeSet addObject:seed->node1 ] ;
			}
		
		if( ! [ excl member:seed->node2 ] )
			{
				[ nodeSet addObject:seed->node2 ] ;
			}
		
		
		
		NSMutableSet *addSet = [ [ NSMutableSet alloc ] initWithCapacity:[ bSet count ] ] ;
		
		BOOL hadAddition = YES ;
		
		while( hadAddition == YES )
			{
				hadAddition = NO ;
				
				[ addSet removeAllObjects ] ;
				
				NSEnumerator *nodeEnumerator = [ nodeSet objectEnumerator ] ;
				
				ctNode *nextNode ;
				
				while( ( nextNode = [ nodeEnumerator nextObject ] ) )
					{
						int k ;
						
						for( k = 0 ; k < nextNode->nBonds ; ++k )
							{
								if( [ bSet member:nextNode->bonds[k] ] )
									{
										if( ! [ returnSet member:nextNode->bonds[k] ] )
											{
												hadAddition = YES ;
												
												[ returnSet addObject:nextNode->bonds[k] ] ;
												
												if( ! [ excl member:nextNode->bonds[k]->node1 ] )
													{
														[ addSet addObject:nextNode->bonds[k]->node1 ] ;
													}
													
												if( ! [ excl member:nextNode->bonds[k]->node2 ] )
													{
														[ addSet addObject:nextNode->bonds[k]->node2 ] ;
													}
													
											}
									}
									
							}
					}
					
				
					[ nodeSet unionSet:addSet ] ;	
			}
			
		[ nodeSet release ] ;
		[ addSet release ] ;
		
		return returnSet ;
	}
				
		
		
- (NSMutableArray *) neighborDataForFragment:(fragment *)f
	{
		// Return all fragments in current tree list that neighbor argument 
		// For each neighbor return an array [ fragment *neighbor, NSSet *commonNodes ]
		
		// Note that it is possible for two non-ring fragments to share the same connection atom
		// to a ring fragment. We will NOT allow non-ring fragments to be neighbors of each other!
		
		NSEnumerator *fragmentEnumerator = [ treeFragments objectEnumerator ] ;
		
		fragment *nextFragment ;
		
		NSMutableArray *returnArray = [ NSMutableArray arrayWithCapacity:[ treeFragments count ] ] ;
		
		NSMutableSet *testSet = [ [ NSMutableSet alloc ] initWithCapacity:[ f->fragmentNodes count ] ] ;
		
		while( ( nextFragment = [ fragmentEnumerator nextObject ] ) )
			{	
				if( nextFragment == f ) continue ;
				
				if( f->type != RING && nextFragment->type != RING ) continue ;
				
				[ testSet removeAllObjects ] ;
				
				[ testSet unionSet:f->fragmentNodes ] ;
				
				[ testSet intersectSet:nextFragment->fragmentNodes ] ;
				
				if( [ testSet count ] > 0 )
					{
						[ returnArray addObject:[ NSArray arrayWithObjects:nextFragment,
													[ NSSet setWithSet:testSet ],nil ] ] ;
					}
			}
			
		[ testSet release ] ;
			
		return returnArray ;
	}
		

/*		
	
- (void) assignNodesToFragments 
	{
		// This method parititions a complex into fragments. This is aimed initially at the new implementation of 
		// Shape Signatures.
		
		
		
		if( ! treeFragments )
			{
				treeFragments = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
			}
			
		// What's the biggest thing attached to a ring we will call a "substituent"?
		


		// What's the criterion for merging neighboring ring systems?
		
#define COALESCE_DIHEDRAL_ANGLE 30. 

		int nextFragmentIndex = 1 ;
		
		// We need to make sure we have maximal trees and rings
		
		if( ! maximalTreePaths )
			{
				[ self makeMaximalTree ] ;
				[ self makeRingClosures ] ;
			}
			
		NSMutableSet *fragmentNodes  ;
			
		// If no ring closures we only have one fragment :-(
		
		int i ;
		
		if( nOutputRingClosures == 0 )
			{				
				[ self assignTreeToFragmentIndex:1 withFragmentType:"NR" ] ;
				
					
				nFragments = 1 ;
				nextFragmentIndex = 2 ;
				
				// Reproduce the whole complex as fragment
				
				fragmentNodes = [ NSSet setWithObjects:nodes count:nNodes ]  ;   
				
				[ treeFragments addObject:[ self subTreeWithNodes:fragmentNodes  ] ] ;
			}
		else
			{
				// For each ring closure, find all paths that connect from one side to the other - each atom collected will be assigned
				// to same fragment
				
				// Take care as processing a previous ring closure may have already assigned the current closure to a fragment
				
				NSMutableSet *collectNodes = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
				NSMutableSet *fragmentNodes = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
				
				NSMutableArray *tempTrees = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
				
				int iClosure ;
				
				for( iClosure = 1 ; iClosure <= nOutputRingClosures ; ++iClosure )
					{
						[ collectNodes removeAllObjects ] ;
						[ fragmentNodes removeAllObjects ] ;
						
						ctNode *startNode = outputRingClosure[iClosure][0] ;
						ctNode *endNode = outputRingClosure[iClosure][1] ;
						
						if( startNode->fragmentIndex >= 0 )
							{
								continue ;
							}
				
						NSArray *paths = [ self extendPathsFrom:startNode to:endNode excludeBond:[ startNode returnBondWithNode:endNode ] ] ;
						
						// Enumerate paths, add all nodes to set
						
						NSEnumerator *pathEnumerator = [ paths objectEnumerator ] ;
						
						ctPath *nextPath ;
						
						while( ( nextPath = [ pathEnumerator nextObject ] ) )
							{
								[ collectNodes unionSet:(nextPath->nodesAsSet) ] ;
							}
							
						// Have the next ring system 
						
						ctTree *ringTree = [ self subTreeWithNodes:collectNodes ] ;
						
						[ ringTree assignTreeToFragmentIndex:nextFragmentIndex withFragmentType:"R" ] ;
						
						[ ringTree addNormal ] ;
						
							
						
												
						[ tempTrees addObject:ringTree ] ;
						
						++nextFragmentIndex ;
					}
					
				// Any trees currently in treeFragments are rings - extend these to include terminal fragments
				
				NSEnumerator *treeEnumerator = [ tempTrees objectEnumerator ] ;
				
				ctTree *nextTree ;
				
				while( ( nextTree = [ treeEnumerator nextObject ] ) )
					{
						// Extend the subtree to include terminal fragments 
				
						ctTree *extendTree = [ self extendSubTree:nextTree toIncludeSubstituentsNoBiggerThan:MAX_SUBST_SIZE ] ;
						
						[ treeFragments addObject:extendTree ] ;
					}
					
				treeEnumerator = [ tempTrees objectEnumerator ] ;
				
				while( ( nextTree = [ treeEnumerator nextObject ] ) )
					{
						[ nextTree release ] ;
						// Note - nextTree will be released when tempTrees is released
					}
					
				// We have the rings - everything else is inter-ring fragments or big stuff attached to rings
				
				while( TRUE )
					{
						// See if we have any nodes not assigned to a fragment
						
						ctNode *rootNode = nil ;
						
						NSSet *newFragmentNodes ;
						
						for( i = 0 ; i < nNodes ; ++i )
							{
								if( nodes[i]->fragmentIndex < 0 )
									{
										rootNode = nodes[i] ;
										break ;
									}
							}
							
						if( ! rootNode )
							{
								break ;
							}
							
						// REMEMBER that I made the decision (why oh why?) to count fragments starting at 1 !!
						
						//int newFragmentIndex = [ treeFragments count ] + 1 ;
						
						BOOL ignore ;
						
						newFragmentNodes = [ self extendNewFragmentFromRoot:rootNode terminal:&ignore baseNode:nil ] ;
						
						nextTree = [ self subTreeWithNodes:newFragmentNodes  ] ;
						
						[ nextTree assignTreeToFragmentIndex:nextFragmentIndex withFragmentType:"NR" ] ;
						 
										
						[ treeFragments addObject:nextTree ] ;
						
						++nextFragmentIndex ;
					}
					
				[ collectNodes release ] ;
				[ fragmentNodes release ] ;
				
				nFragments = [ treeFragments count ] ;
			}
			
		int j ;
		
		// We may have rings connected by single bond - coalesce these if the torsional angle between rings is 
		// less than 30 degrees
		
		BOOL hadCoalesceEvent = YES ;
		
		while( hadCoalesceEvent == YES )
			{
				hadCoalesceEvent = NO ;
				
				for( j = 0 ; j < nBonds ; ++j )
					{
						ctTree *fragTree1 = bonds[j]->node1->fragmentTree ;
						ctTree *fragTree2 = bonds[j]->node2->fragmentTree ;
						
						if( fragTree1 != fragTree2 )
							{
								// Check to see if each are ring fragments
								// Check for normal
								
								if( (! fragTree1->normal) ||  (! fragTree2->normal) ) continue ;
								
								// Have candidates - create a new subtree if pass dihedral check
								
								if( [ self dihedralBetweenFragment:fragTree1 andFragment:fragTree2 ] < COALESCE_DIHEDRAL_ANGLE )
									{
										// Reassign as new fragment
										
										
										NSMutableSet *nodeSet = [ NSMutableSet 
											setWithObjects:fragTree1->nodes
											count:fragTree1->nNodes ] ;
											
										[ nodeSet unionSet:[ NSMutableSet 
											setWithObjects:fragTree2->nodes count:fragTree2->nNodes ] ] ;
											
										ctTree *coalesceTree = [ self subTreeWithNodes:nodeSet  ] ;
										
										// Make normals of fragments agree
										
										if( [ fragTree1->normal dotWith:fragTree2->normal ] < 0. )
											{
												[ fragTree2->normal scaleBy:-1. ] ;
											}
											
										coalesceTree->normal = [ [ MMVector3 alloc ] 
											initX:[ fragTree1->normal X ] 
											Y:[ fragTree1->normal Y ] 
											Z:[ fragTree1->normal Z ] ] ;
											
										[ coalesceTree->normal add:fragTree2->normal ] ;
										
										[ coalesceTree->normal normalize ] ;
										
										coalesceTree->center = [ [ MMVector3 alloc ] 
											initX:[ fragTree1->center X ]
											Y:[ fragTree1->center Y ]
											Z:[ fragTree1->center Z ] ] ;
										
										[ coalesceTree->center add:fragTree2->center ] ;
										[ coalesceTree->center scaleBy:0.5 ] ;
										
										[ coalesceTree adjustCoalescedTreeFragmentIndex:nextFragmentIndex ] ;
											
										[ treeFragments addObject:coalesceTree ] ;
										
										// Remove
										
										[ treeFragments removeObject:fragTree1 ] ;
										[ treeFragments removeObject:fragTree2 ] ;
						
										++nextFragmentIndex ;
										
										hadCoalesceEvent = YES ;
										
										break ;
									}
							}
							
						if( hadCoalesceEvent == YES ) break ;
					}
			}
												
		
		// We may have "bridging" clusters (which include a single heavy atom that connects two ring systems). 
		// Remove these by coalescing with adjacent fragments, making a new fragment, IF dihedral condition is satisfied
		
		hadCoalesceEvent = YES ;
		
		while( hadCoalesceEvent == YES )
			{
				hadCoalesceEvent = NO ;
				
				NSEnumerator *treeEnumerator = [ treeFragments objectEnumerator ] ;
				
				ctTree *nextTree ;
				
				while( ( nextTree = [ treeEnumerator nextObject ] ) )
					{
							
						NSArray *outNeighbors = nil ;
						BOOL haveCandidate = NO ;
						
						for( j = 0 ; j < nextTree->nNodes ; ++j )
							{
								outNeighbors = [ nextTree->nodes[j] neighborsWithDifferentFragmentIndex ] ;
								
								if( outNeighbors && [ outNeighbors count ] == 2 )
									{
										haveCandidate = YES ;
										break ;
									}
							}
						
						if( haveCandidate == NO ) continue ;
						
						// At this point I can only try to coalesce two neighboring rings - what if more?
						
						ctTree *fragTree1 = ((ctNode *)[ outNeighbors objectAtIndex:0 ])->fragmentTree ;
						ctTree *fragTree2 = ((ctNode *)[ outNeighbors objectAtIndex:1 ])->fragmentTree ;
						
						if( [ self dihedralBetweenFragment:fragTree1 andFragment:fragTree2 ] <= COALESCE_DIHEDRAL_ANGLE )
							{
								NSMutableSet *neighborNodes = [ NSMutableSet setWithObjects:nextTree->nodes count:nextTree->nNodes ] ;
								
								[ neighborNodes unionSet:[ NSMutableSet setWithObjects:fragTree1->nodes count:fragTree1->nNodes ] ] ;
								[ neighborNodes unionSet:[ NSMutableSet setWithObjects:fragTree2->nodes count:fragTree2->nNodes ] ] ;
						
								ctTree *coalesceTree = [ self subTreeWithNodes:neighborNodes  ] ;
										
								// Make normals of fragments agree
								
								if( [ fragTree1->normal dotWith:fragTree2->normal ] < 0. )
									{
										[ fragTree2->normal scaleBy:-1. ] ;
									}
									
								coalesceTree->normal = [ [ MMVector3 alloc ] 
									initX:[ fragTree1->normal X ] 
									Y:[ fragTree1->normal Y ] 
									Z:[ fragTree1->normal Z ] ] ;
									
								[ coalesceTree->normal add:fragTree2->normal ] ;
								
								[ coalesceTree->normal normalize ] ;
								
								coalesceTree->center = [ [ MMVector3 alloc ] 
									initX:[ fragTree1->center X ]
									Y:[ fragTree1->center Y ]
									Z:[ fragTree1->center Z ] ] ;
								
								[ coalesceTree->center add:fragTree2->center ] ;
								[ coalesceTree->center scaleBy:0.5 ] ;
								
								[ coalesceTree adjustCoalescedTreeFragmentIndex:nextFragmentIndex ] ;
									
								[ treeFragments addObject:coalesceTree ] ;
 								
									
								// Remove
								
								[ treeFragments removeObject:fragTree1 ] ;
								[ treeFragments removeObject:fragTree2 ] ;
								[ treeFragments removeObject:nextTree ] ;
				
								++nextFragmentIndex ;
								
								hadCoalesceEvent = YES ;
								
								[ outNeighbors release ] ;
								outNeighbors = nil ;
								
								break ;
							}
							
						if( outNeighbors ) [ outNeighbors release ] ;
					}
			}
						
						
			
		// Here is something I forgot to deal with - our fragment indices may be discontiguous (may skip an index) 
		// due to coalescing of ring systems. 
		
		int *mapFrags = (int *) malloc( nextFragmentIndex * sizeof( int ) ) ;
		
		
		for( j = 1 ; j < nextFragmentIndex ; ++j )
			{
				mapFrags[j] = 0 ;
			}
			
		// Scan all the nodes, enter a "1" in the array for each fragment encountered
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				mapFrags[ nodes[j]->fragmentIndex ] = 1 ;
			}
			
		// Accumulate index
		
		int accum = 0 ; 
		
		for( j = 1 ; j < nextFragmentIndex ; ++j )
			{
				accum += mapFrags[j] ;
				mapFrags[j] = accum ;
			}
			
		// Adjust indices
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				[ nodes[j] adjustFragmentIndex:(mapFrags[ nodes[j]->fragmentIndex ] ) ] ;
			}
		
		free( mapFrags ) ;
		
		nFragments = accum ;
		
		return ;
	}
*/

/*
- (ctTree *) subTreeWithNodes:(NSSet *)n
	{
		NSSet *nodesAsSet = n ;
		
		ctTree *returnTree = [ [ ctTree alloc ] initEmptyTree ] ;
		
		
		// Add all the nodes. Remember we have C arrays - sigh
		
		NSEnumerator *nodeEnumerator = [ n objectEnumerator ] ;
		
		// NOTE that a subtree depends on the existence of the parent tree - I am not copying or retaining nodes. 
		
		ctNode *nextNode ;
		
		while( ( nextNode = [ nodeEnumerator nextObject ] ) )
			{
				
				if( returnTree->nNodes == returnTree->nNodeAlloc )
					{
						returnTree->nNodeAlloc += 50 ;
						returnTree->nodes = (ctNode **) realloc( returnTree->nodes, returnTree->nNodeAlloc * sizeof( ctNode * ) ) ;
					}
				
				returnTree->nodes[returnTree->nNodes] = nextNode ;
				++returnTree->nNodes ;
			}
			
		// Process all bonds in source tree, add those that include nodes of subtree
		
		int iBond ;
		
		for( iBond = 0 ; iBond < nBonds ; ++iBond )
			{
				if( [ nodesAsSet member:(bonds[iBond]->node1) ] && [ nodesAsSet member:(bonds[iBond]->node2) ] )
					{
						if( returnTree->nBonds == returnTree->nBondAlloc )
							{
								returnTree->nBondAlloc += 50 ;
								returnTree->bonds = (ctBond **) realloc( returnTree->bonds, returnTree->nBondAlloc * sizeof( ctBond * ) ) ;
							}
						
						returnTree->bonds[returnTree->nBonds] = bonds[iBond] ;
						++returnTree->nBonds ;
					}
			}
			
			
		// I think that is all I need to do
		
		return returnTree ;
	}
*/
		
/*
- (NSArray *) extendPathsFrom:(ctNode *)nS to:(ctNode *)nE excludeBond:(ctBond *)exclB
	{
		// This seems a little lame - I am going to initiate a new path using each child of nS that does not 
		// involve the excluded bond - then I am going to invoke the recursive function that does the dirty work. 
		
		int iChild ;
		ctNode *nextChildOfStart ;
		ctBond *nextBond ;
		
		NSMutableArray *returnArray = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		
		for( iChild = 0 ; iChild < nS->nBonds ; ++iChild )
			{
				nextBond = nS->bonds[iChild] ;
				
				if( nextBond == exclB ) continue ;
				
				if( nS->atBondStart[iChild] == YES )
					{
						nextChildOfStart = nextBond->node2 ;
					}
				else
					{
						nextChildOfStart = nextBond->node1 ;
					}

				if( strcasecmp( [ nextChildOfStart elementName ], "H" ) == 0 ) continue ;
				
				ctPath *initPath = [ [ ctPath alloc ] initEmptyCTPathWithRoot:nil andTree:self ] ;
				
				[ initPath extendWithNode:nS ] ;
				[ initPath extendWithNode:nextChildOfStart ] ;
				
				NSArray *paths = [ self extendPath:initPath to:nE ] ;
				
				[ returnArray addObjectsFromArray:paths ] ;
				
				[ paths release ] ;
				
			}
			
		return returnArray ;
	}


- (NSArray *) extendPath:(ctPath *)p to:(ctNode *)e
	{
		ctNode *lastNode = [ p lastNodeInPath ] ;
		
		NSMutableArray *returnArray = [ [ NSMutableArray alloc ] initWithCapacity:10 ] ;
		
		int i ;
		
		for( i = 0 ; i < lastNode->nBonds ; ++i )
			{
				ctNode *nextChild ;
				ctBond *nextBond ;
				
				nextBond = lastNode->bonds[i] ;
				
				if( lastNode->atBondStart[i] == YES )
					{
						nextChild = nextBond->node2 ;
					}
				else
					{
						nextChild = nextBond->node1 ;
					}
					
				// Do not include hydrogen in path 
				
				if( strcasecmp( [ nextChild elementName ], "H" ) == 0 ) continue ;

				if( [ p pathIncludesNode:nextChild ] == YES ) continue ;
				
				// Try to extend ----
				
				ctPath *nextPath = [ [ ctPath alloc ] initWithCTPath:p ] ;
				
				[ nextPath extendWithNode:nextChild ] ;
				
				// Terminate recursion?
				
				if( nextChild == e )
					{
						[ returnArray addObject:nextPath ] ;
						
						//return returnArray ;
						
						continue ;
					}
				
				NSArray *returnPaths = [ self extendPath:nextPath to:e ] ;
				
				[ returnArray addObjectsFromArray:returnPaths ] ;
				
				[ returnPaths release ] ;
			}
				
				
		return returnArray ;
	}
				
- (ctTree *) extendSubTree:(ctTree *)t toIncludeSubstituentsNoBiggerThan:(int)max 
	{
		// Simply extend by adding child nodes that are unassigned - all children of current collection
		
		// Enumerate nodes - each node can be the root of new substituent
		
		int iNode ;
		
		// Start with all the nodes currently in subtree
		
		NSMutableSet *collectSet = [ [ NSMutableSet alloc ] initWithObjects:t->nodes count:t->nNodes ] ;
		
		for( iNode = 0 ; iNode < t->nNodes ; ++iNode )
			{
				ctNode *base = t->nodes[iNode] ;
				
				ctNode *neighbor ;
				
				// Have to rework this logic form the original form - need to check for multiple substituents (rings are
				// not always aromatic, remember?)
				
				int jNeighbor ;
				
				for( jNeighbor = 0 ; jNeighbor < base->nBonds ; ++jNeighbor )
					{
						if( base->atBondStart[jNeighbor] == YES )
							{
								neighbor = [ base->bonds[jNeighbor] endNode ] ;
							}
						else
							{
								neighbor = [ base->bonds[jNeighbor] startNode ] ;
							}
							
						if( neighbor->fragmentIndex < 0 )
							{
								BOOL term = YES ;
								
								NSSet *fragNodes = [ self 
									extendNewFragmentFromRoot:neighbor terminal:&term baseNode:base ] ;
				
								if( [ fragNodes count ] > max || term == NO ) 
									{
										[ fragNodes release ] ;
										continue ;
									}
					
								// Assign all the members of fragNodes to the subtree and (thus to the associated fragment)
								
								[ collectSet unionSet:fragNodes ] ;
								
								[ fragNodes release ] ;
							}
					}
			}
			
		// Add all the nodes we have collected to the existing subtree and assign the fragment index 
		
		ctTree *returnTree = [ self subTreeWithNodes:collectSet ] ;
		
		int fragIndex = t->nodes[0]->fragmentIndex ;
		
		NSEnumerator *nodeEnumerator = [ collectSet objectEnumerator ] ;
		ctNode *nextNode ; 
		
		while( ( nextNode = [ nodeEnumerator nextObject ] ) )
			{
				if( ! [ nextNode returnPropertyForKey:@"fragmentID" ] )
					{
						[ nextNode assignToFragmentIndex:fragIndex withFragmentType:"S" ] ;
					}
					
				nextNode->fragmentTree = returnTree ;
			}
			
				// If parent tree has normal and center, copy the references
		
		if( t->normal )
			{
				returnTree->normal = t->normal ;
				returnTree->center = t->center ;
			}

		
		[ collectSet release ] ;
		
		return returnTree ;
	}
		
		
		
- (NSSet *) extendNewFragmentFromRoot:(ctNode *)r terminal:(BOOL *)term baseNode:(ctNode *)b
	{
		// term is assumed initially set to YES - if we encounter a node that neighbors one already assigned,
		// we touch term and set to NO. 
		
		// We will not do this recursively
		
		NSMutableSet *collectFragment = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
		NSMutableSet *currentChildren = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
		NSMutableSet *nextChildren = [ [ NSMutableSet alloc ] initWithCapacity:10 ] ;
		
		// First, add root
		
		[ collectFragment addObject:r ] ;
		
		int baseFragmentIndex ;
		
		if( b )
			{
				baseFragmentIndex = b->fragmentIndex ;
			}
		else
			{
				baseFragmentIndex = -2 ; // Never used
			}
		
		// Initialize currentChildren with unassigned children of root - if empty we return
				
		int i ; ctNode *neighbor ;
		
		for( i = 0 ; i < r->nBonds ; ++i )
			{
				if( r->atBondStart[i] == YES )
					{
						neighbor = r->bonds[i]->node2 ;
					}
				else
					{
						neighbor = r->bonds[i]->node1 ;
					}
					
				if( neighbor->fragmentIndex == baseFragmentIndex ) continue ;
				
				if( neighbor->fragmentIndex >= 0 && neighbor->fragmentIndex != baseFragmentIndex )
					{
						*term = NO ;
						continue ;
					}
					
				[ currentChildren addObject:neighbor ] ;
				
			}
			
		if( [ currentChildren count ] == 0 )
			{
				[ currentChildren release ] ;
				[ nextChildren release ] ;
				
				return collectFragment ;
			}
		
		
		while( TRUE )
			{
				// Assume nextChildren is empty
				
				NSEnumerator *currentChildrenEnumerator = [ currentChildren objectEnumerator ] ;
				
				// OK, treat the current child as the parent of the next group of nodes (nextChildren)
				
				ctNode *parent ;
				
				while( ( parent = [ currentChildrenEnumerator nextObject ] ) )
					{
						
						for( i = 0 ; i < parent->nBonds ; ++i )
							{
								if( parent->atBondStart[i] == YES )
									{
										neighbor = parent->bonds[i]->node2 ;
									}
								else
									{
										neighbor = parent->bonds[i]->node1 ;
									}
									
								if( [ currentChildren member:neighbor ] ) continue ;
								if( [ collectFragment member:neighbor ] ) continue ;
								
								if( neighbor->fragmentIndex == baseFragmentIndex ) continue ;
								
								if( neighbor->fragmentIndex >= 0 &&  neighbor->fragmentIndex != baseFragmentIndex )
									{
										*term = NO ;
										continue ;
									}
									
								[ nextChildren addObject:neighbor ] ;
								
							}
					}
					
				// If not more descendants, break 
				
				if( [ nextChildren count ] == 0 )
					{
						[ nextChildren release ] ;
						[ collectFragment unionSet:currentChildren ] ;
						[ currentChildren release ] ;
			
						break ;
					}
					
				// Fold current children into collectFragment, move nextChildren into currentChildren
				
				[ collectFragment unionSet:currentChildren ] ;
				
				[ currentChildren setSet:nextChildren ] ;
				
				[ nextChildren removeAllObjects ] ;
			}
			
		
		return collectFragment ;
	}
				
*/
			
- (void) printComplex 
	{
		// For the moment, print out element, import type, fragment assignments, bonds
		
		int i ;
		
		char *bondTypeText[] = { "SINGLE", "DOUBLE", "TRIPLE", "AROMATIC", "AMIDE", "COORDINATION", "ANY", "UNDEFINED" } ;
		
		printf( "Atoms (aka tree nodes) ---\n" ) ;
		printf( "index : element : imported atom type : path index : fragment index \n" ) ;
		
		for( i = 0 ; i < nNodes ; ++i )
			{
				printf( "%d\t%s\t%s\t%d\t%d\n", i+1, [ nodes[i] elementName ], 
					[ [ nodes[i]->properties objectForKey:@"importType" ] cString ], nodes[i]->pathIndex, nodes[i]->fragmentIndex ) ;
			}
			
		printf( "Bonds (aka tree edges) ---\n" ) ;
		for( i = 0 ; i < nBonds ; ++i )
			{
				ctBond *nextBond = bonds[i] ;
				ctNode *node1 = bonds[i]->node1 ;
				ctNode *node2 = bonds[i]->node2 ;
				
				
				printf( "%d\t%d\t%d\t%s\n", i+1, [ self indexOfNode:node1 ] + 1, [ self indexOfNode:node2 ] + 1, bondTypeText[ (int) nextBond->type ] ) ;
			}
			
		printf( "Ring Closures (atom index - atom index) ---\n" ) ;
		
		for( i = 1 ; i <= nOutputRingClosures ; ++i )
			{
				printf( "%d - %d\n", [ self indexOfNode:outputRingClosure[i][0] ] + 1, [ self indexOfNode:outputRingClosure[i][1] ] + 1 ) ;
			}
			
		return ;
	}
		
- (void) assignTreeToFragmentIndex:(int)idx withFragmentType:(char *)t
	{
		int j ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				[ nodes[j] assignToFragmentIndex:idx withFragmentType:t ] ;
				nodes[j]->fragmentTree = self ;
			}
			
		return ;
	}
	
/*
- (double) dihedralBetweenFragment:(ctTree *)f1 andFragment:(ctTree *)f2
	{
		// Compute angle between two ring systems - only use "R" type atoms
		
		int nR1 = 0 ;
		int nR2 = 0 ;
		int j, k ;
		
		double coordCM1[3], coordCM2[3] ;
		
		coordCM1[0] = coordCM1[1] = coordCM1[2] = 0. ;
		coordCM2[0] = coordCM2[1] = coordCM2[2] = 0. ;
		
		NSMutableArray *ring1Vectors = [ [ NSMutableArray alloc ] initWithCapacity:f1->nNodes ] ;
		NSMutableArray *ring2Vectors = [ [ NSMutableArray alloc ] initWithCapacity:f2->nNodes ] ;
		
		for( j = 0 ; j < f1->nNodes ; ++j )
			{
				ctNode *n = f1->nodes[j] ;
				
				if( [ n isRingNode ] == NO ) continue ;
				
				++nR1 ;
				
				MMVector3 *r1Vector = [ [ MMVector3 alloc ] initX:f1->nodes[j]->coord[0] 
					Y:f1->nodes[j]->coord[1] Z:f1->nodes[j]->coord[2] ] ;
				
				[ ring1Vectors addObject:r1Vector ] ;
				[ r1Vector release ] ;
				
				for( k = 0 ; k < 3 ; ++k )
					{
						coordCM1[k] += n->coord[k] ;
					}
			}

		for( j = 0 ; j < f2->nNodes ; ++j )
			{
				ctNode *n = f2->nodes[j] ;
				
				if( [ n isRingNode ] == NO ) continue ;
				
				++nR2 ;
				
				MMVector3 *r2Vector = [ [ MMVector3 alloc ] initX:f2->nodes[j]->coord[0] 
					Y:f2->nodes[j]->coord[1] Z:f2->nodes[j]->coord[2] ] ;
				
				[ ring2Vectors addObject:r2Vector ] ;
				[ r2Vector release ] ;
				
				for( k = 0 ; k < 3 ; ++k )
					{
						coordCM2[k] += n->coord[k] ;
					}
			}
			
		for( k = 0 ; k < 3 ; ++k )
			{
				coordCM1[k] /= nR1 ;
				coordCM2[k] /= nR2 ;
			}
			
		// Make relative vectors
		
		NSEnumerator *vectorEnumerator = [ ring1Vectors objectEnumerator ] ;
		MMVector3 *nextVector ;
		
		while( ( nextVector = [ vectorEnumerator nextObject ] ) )
			{
				[ nextVector setX:( [ nextVector X ] - coordCM1[0] ) ] ;
				[ nextVector setY:( [ nextVector Y ] - coordCM1[1] ) ] ;
				[ nextVector setZ:( [ nextVector Z ] - coordCM1[2] ) ] ;
			}
				
		vectorEnumerator = [ ring2Vectors objectEnumerator ] ;
		
		while( ( nextVector = [ vectorEnumerator nextObject ] ) )
			{
				[ nextVector setX:( [ nextVector X ] - coordCM2[0] ) ] ;
				[ nextVector setY:( [ nextVector Y ] - coordCM2[1] ) ] ;
				[ nextVector setZ:( [ nextVector Z ] - coordCM2[2] ) ] ;
			}
			
		MMVector3 *ring1Normal = [ [ MMVector3 alloc ] initX:0. Y:0. Z:0. ] ;
		MMVector3 *ring2Normal = [ [ MMVector3 alloc ] initX:0. Y:0. Z:0. ] ;
		
		double l ;
		
		for( j = 0 ; j < nR1 - 1 ; ++j )
			{
				for( k = j + 1 ; k < nR1 ; ++k )
					{
						MMVector3 *pdct = [ [ MMVector3 alloc ] initByCrossing:[ ring1Vectors objectAtIndex:j ]
							and:[ ring1Vectors objectAtIndex:k ] ] ;
					
						l = [ pdct length ] ;
						
						if( l < 0.01 ) continue ;
						
						if( [ ring1Normal dotWith:pdct ] < 0. )
							{
								[ pdct scaleBy:-1. ] ;
							}
							
						[ pdct normalize ] ;
						
						[ ring1Normal add:pdct ] ;
						
						[ pdct release ] ;
					}
			}
			
		[ ring1Normal normalize ] ;
		
		
		for( j = 0 ; j < nR2 - 1 ; ++j )
			{
				for( k = j + 1 ; k < nR2 ; ++k )
					{
						MMVector3 *pdct = [ [ MMVector3 alloc ] initByCrossing:[ ring2Vectors objectAtIndex:j ]
							and:[ ring2Vectors objectAtIndex:k ] ] ;
					
						l = [ pdct length ] ;
						
						if( l < 0.01 ) continue ;
						
						if( [ ring2Normal dotWith:pdct ] < 0. )
							{
								[ pdct scaleBy:-1. ] ;
							}
							
						[ pdct normalize ] ;
						
						[ ring2Normal add:pdct ] ;
						
						[ pdct release ] ;
					}
			}
			
		[ ring2Normal normalize ] ;
		
		MMVector3 *disp = [ [ MMVector3 alloc ] initX:( coordCM2[0] - coordCM1[0] )
			Y:( coordCM2[1] - coordCM1[1] ) 
			Z:( coordCM2[2] - coordCM1[2] ) ] ;
			
		[ disp normalize ] ;
		
		double dot = [ ring1Normal dotWith:disp ] ;
		
		MMVector3 *ring1NormalMod = [ [ MMVector3 alloc ] 
			initX:( [ ring1Normal X ] - dot * [ disp X ] )
			Y:( [ ring1Normal Y ] - dot * [ disp Y ] )
			Z:( [ ring1Normal Z ] - dot * [ disp Z ] ) ] ;
			
		[ ring1NormalMod normalize ] ;
		
		[ ring1Normal release ] ;
						
		dot = [ ring2Normal dotWith:disp ] ;
		
		MMVector3 *ring2NormalMod = [ [ MMVector3 alloc ] 
			initX:( [ ring2Normal X ] - dot * [ disp X ] )
			Y:( [ ring2Normal Y ] - dot * [ disp Y ] )
			Z:( [ ring2Normal Z ] - dot * [ disp Z ] ) ] ;
			
		[ ring2NormalMod normalize ] ;
		
		[ ring2Normal release ] ;
		
		double ang = acos( fabs( [ ring1NormalMod dotWith:ring2NormalMod ] ) ) * (180. / acos(-1.)) ;
		
		[ ring1NormalMod release ] ;
		[ ring2NormalMod release ] ;
		
		[ disp release ] ;
		
		[ ring1Vectors release ] ;
		[ ring2Vectors release ] ;
		
		return ang ;
	}
*/
/*
- (double) dihedralBetweenFragment:(ctTree *)f1 andFragment:(ctTree *)f2
	{
	
		// Both must have a normal defined
		
		MMVector3 *disp = [ [ MMVector3 alloc ] 
			initX:( [ f2->center X ] - [ f1->center X ] ) 
			Y:( [ f2->center Y ] - [ f1->center Y ] ) 
			Z:( [ f2->center Z ] - [ f1->center Z ] ) ] ;
			
		[ disp normalize ] ;
		
		double dot = [ f1->normal dotWith:disp ] ;
		
		MMVector3 *ring1NormalMod = [ [ MMVector3 alloc ] 
			initX:( [ f1->normal X ] - dot * [ disp X ] )
			Y:( [ f1->normal Y ] - dot * [ disp Y ] )
			Z:( [ f1->normal Z ] - dot * [ disp Z ] ) ] ;
			
		dot = [ f2->normal dotWith:disp ] ;
		
		MMVector3 *ring2NormalMod = [ [ MMVector3 alloc ] 
			initX:( [ f2->normal X ] - dot * [ disp X ] )
			Y:( [ f2->normal Y ] - dot * [ disp Y ] )
			Z:( [ f2->normal Z ] - dot * [ disp Z ] ) ] ;
		
		[ ring1NormalMod normalize ] ;
		[ ring2NormalMod normalize ] ;
		
		double ang = acos( fabs( [ ring1NormalMod dotWith:ring2NormalMod ] ) ) * (180. / acos(-1.)) ;
		
		[ ring1NormalMod release ] ;
		[ ring2NormalMod release ] ;
		
		[ disp release ] ;
		
		return ang ;
		
	}
	
*/

- (int) heavyAtomCount
	{
		int j ;
		
		int hCount = 0 ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				if( nodes[j]->atomicNumber > 1 )
					{
						++hCount ;
					}
			}
			
		return hCount ;
	}
/*
- (void) addNormal
	{
		// Try to add normal vector for this fragment - use all ring atoms
		
		int nR = 0 ;
		int j, k ;
		
		double coordCM[3] ;
		
		coordCM[0] = coordCM[1] = coordCM[2] = 0. ;
		
		NSMutableArray *ringVectors = [ [ NSMutableArray alloc ] initWithCapacity:nNodes ] ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				ctNode *n = nodes[j] ;
				
				if( [ n isRingNode ] == NO ) continue ;
				
				++nR ;

				for( k = 0 ; k < 3 ; ++k )
					{
						coordCM[k] += n->coord[k] ;
					}
			}
			
		if( nR == 0 ) return ;	// Do nothing
			
		coordCM[0] /= nR ;
		coordCM[1] /= nR ;
		coordCM[2] /= nR ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				ctNode *n = nodes[j] ;
				
				if( [ n isRingNode ] == NO ) continue ;
				
				MMVector3 *rVector = [ [ MMVector3 alloc ] initX:(n->coord[0] - coordCM[0]) 
					Y:(n->coord[1] - coordCM[1]) Z:(n->coord[2] - coordCM[2]) ] ;
				
				[ ringVectors addObject:rVector ] ;
				[ rVector release ] ;
				
			}
			
				
		MMVector3 *ringNormal = [ [ MMVector3 alloc ] initX:0. Y:0. Z:0. ] ;
		
		double l ;
		
		for( j = 0 ; j < nR - 1 ; ++j )
			{
				for( k = j + 1 ; k < nR ; ++k )
					{
						MMVector3 *pdct = [ [ MMVector3 alloc ] initByCrossing:[ ringVectors objectAtIndex:j ]
							and:[ ringVectors objectAtIndex:k ] ] ;
					
						l = [ pdct length ] ;
						
						if( l < 0.01 ) continue ;
						
						if( [ ringNormal dotWith:pdct ] < 0. )
							{
								[ pdct scaleBy:-1. ] ;
							}
							
						[ pdct normalize ] ;
						
						[ ringNormal add:pdct ] ;
						
						[ pdct release ] ;
					}
			}
			
		[ ringNormal normalize ] ;
		
		normal = ringNormal ;
		
		center = [ [ MMVector3 alloc ] initX:coordCM[0] Y:coordCM[1] Z:coordCM[2] ] ;
		
		[ ringVectors release ] ;
		
		return ;
	}
		
- (void) adjustCoalescedTreeFragmentIndex:(int) idx
	{
		// This is an obscure method - 
		
		// If two ring systems have been coalesced, they may include atoms with the following
		// fragment types - NR (the bridging part), S, and of course R. 
		
		// The plan here is to assign all nodes to the argument fragment index. Nodes of type "R" or "S"
		// stay as such, nodes of type "NR" become "S" .
		
		int j ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				NSString *myID = [ [ nodes[j] properties ] objectForKey:@"fragmentID" ] ;
				
				NSRange rng = [ myID rangeOfString:@"NR" ] ;
				
				if( rng.location == 0 )
					{
						[ nodes[j] assignToFragmentIndex:idx withFragmentType:"S" ] ;
					}
				else
					{
						[ nodes[j] adjustFragmentIndex:idx ] ;
					}
					
				nodes[j]->fragmentTree = self ;
			}
			
		return ;
	}
	*/
	
		
		
	
- (int) indexOfNode:(ctNode *) n 
	{
		int i ;
		
		for( i = 0 ; i < nNodes ; ++i )
			{
				if( nodes[i] == n )
					{
						return i ;
					}
			}
			
		return -1 ;
	}
				
				
- (NSDictionary *) propertyListDict 
	{
		NSMutableDictionary *returnDictionary = [ NSMutableDictionary dictionaryWithCapacity:10 ] ;
		
		[ returnDictionary setObject:[ NSData dataWithBytes:&nNodes length:sizeof(int) ] forKey:@"nNodes" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&nBonds length:sizeof(int) ] forKey:@"nBonds" ]  ;
		[ returnDictionary setObject:[ NSData dataWithBytes:&nFragments length:sizeof(int) ] forKey:@"nFragments" ]  ;
		
		NSData *originalNodePtrs = [ NSData dataWithBytes:nodes length:(nNodes * sizeof( ctNode * ) ) ] ;
		NSData *originalBondPtrs = [ NSData dataWithBytes:bonds length:(nBonds * sizeof( ctBond * ) ) ] ;
		
		[ returnDictionary setObject:originalNodePtrs forKey:@"orginalNodePtrs" ]  ;
		[ returnDictionary setObject:originalBondPtrs forKey:@"originalBondPtrs" ]  ;
		
		// Array of current nodes as propertylists
		
		NSMutableArray *nodesAsPLists = [ NSMutableArray arrayWithCapacity:nNodes ] ;
		
		int j ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				[ nodesAsPLists addObject:[ nodes[j] propertyListDict ] ] ;
			}
			
		
		[ returnDictionary setObject:nodesAsPLists forKey:@"nodesAsPLists" ]  ;
		
		// Array of current bonds as propertylists
		
		NSMutableArray *bondsAsPLists = [ NSMutableArray arrayWithCapacity:nBonds ] ;
		
		for( j = 0 ; j < nBonds ; ++j )
			{
				[ bondsAsPLists addObject:[ bonds[j] propertyListDict ] ] ;
			}
			
		
		[ returnDictionary setObject:bondsAsPLists forKey:@"bondsAsPLists" ]  ;
		
		fragment **originalTreeFragmentPtrs = (fragment **) malloc( [ treeFragments count ] * sizeof( fragment *) ) ;
				
		
		for( j = 0 ; j < [ treeFragments count ] ; ++j )
			{
				originalTreeFragmentPtrs[j] = [ treeFragments objectAtIndex:j ] ;
			}
		
		NSData *originalTreeFragPtrs = [ NSData dataWithBytes:originalTreeFragmentPtrs length:([ treeFragments count ] * sizeof( fragment * ) ) ] ;
		[ returnDictionary setObject:originalTreeFragPtrs forKey:@"originalTreeFragmentPtrs" ]  ;	
		
		// Tree Fragments as property lists 
		
		NSMutableArray *treeFragmentsAsPLists = [ NSMutableArray arrayWithCapacity:nFragments ] ;
		
		for( j = 0 ; j < nFragments ; ++j )
			{
				[ treeFragmentsAsPLists addObject:[ [ treeFragments objectAtIndex:j ] propertyListDict ] ] ;
			}
			
		[ returnDictionary setObject:treeFragmentsAsPLists forKey:@"treeFragmentsAsPLists" ]  ;
		
		[ returnDictionary setObject:treeName forKey:@"treeName" ]  ;
		
		
		
		free( originalTreeFragmentPtrs ) ;
		
		return returnDictionary ;
		//return theData ;
		
		
		
	}
	
- (id) initWithPropertyListDict:(NSDictionary *)pListDict
	{
		self = [ super init ] ;
		
		NSData *theData ;
		
		theData = [ pListDict objectForKey:@"nNodes" ] ;
		[ theData getBytes:&nNodes length:sizeof(int) ] ;
		theData = [ pListDict objectForKey:@"nBonds" ] ;
		[ theData getBytes:&nBonds length:sizeof(int) ] ;
		theData = [ pListDict objectForKey:@"nFragments" ] ;
		[ theData getBytes:&nFragments length:sizeof(int) ] ;
		
		nodes = (ctNode **) malloc( nNodes * sizeof( ctNode * ) ) ;
		ctNode **originalNodes = (ctNode **) malloc( nNodes * sizeof( ctNode * ) ) ;
		
		// Need to handle possibility of 64 bit pointers, if data came from 
		// supercomputer (say).
		
		// We expect the most significant bytes to hold useful data.
		
		// This is a kludge motivted in part by my distaste at (probably) needing
		// to link against 64 bit libraries should I attempt to comnpile thia 64-bit
		
		theData = [ pListDict objectForKey:@"orginalNodePtrs" ] ;
		
		if( [ theData length ] == 8 * nNodes )
		{
			// Uh oh
			
			int j ;
			
			for( j= 0 ; j < nNodes ; ++j )
			{
				[ theData getBytes:(originalNodes + j) range:NSMakeRange(8*j, sizeof( ctNode * ))  ] ;
				
			}
		}
		else
		{
			[ theData getBytes:originalNodes length:(nNodes * sizeof( ctNode * ) ) ] ;
		}
		
		
		bonds = (ctBond **) malloc( nBonds * sizeof( ctBond * ) ) ;
		ctBond **originalBonds = (ctBond **) malloc( nBonds * sizeof( ctBond * ) ) ;
		
		theData = [ pListDict objectForKey:@"originalBondPtrs" ] ;
		
		if( [ theData length ] == 8 * nBonds )
		{
			// Uh oh
			
			int j ;
			
			for( j= 0 ; j < nBonds ; ++j )
			{
				[ theData getBytes:(originalBonds + j) range:NSMakeRange(8*j, sizeof( ctBond * ))  ] ;
				
			}
		}
		else
		{
			[ theData getBytes:originalBonds length:(nBonds * sizeof( ctBond * ) ) ] ;
		}
		
		
		
		// Array of current nodes as propertylists
		
		NSMutableArray *nodesAsPLists = [ pListDict objectForKey:@"nodesAsPLists" ] ;
		
		int j, k ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				nodes[j] = [ [ ctNode alloc ] initWithPropertyListDict:[ nodesAsPLists objectAtIndex:j ] ] ;
			}
			
		// Make dictionary to relate old node pointers to new
		
		NSMutableDictionary *nodePointerTranslator = [ [ NSMutableDictionary alloc ] initWithCapacity:nNodes ] ;
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				[ nodePointerTranslator setObject:nodes[j] 
					forKey:[ NSData  dataWithBytes:&(originalNodes[j]) length:sizeof(ctNode *)  ] ] ;
			}
			
		
		// Array of current bonds as propertylists
		
		NSMutableArray *bondsAsPLists = [ pListDict objectForKey:@"bondsAsPLists" ] ;
		
		for( j = 0 ; j < nBonds ; ++j )
			{
				bonds[j] = [ [ ctBond alloc ] initWithPropertyListDict:[ bondsAsPLists objectAtIndex:j ]
					andNodeTranslator:nodePointerTranslator ] ;
			}
			
		// Make dictionary to relate old bond pointers to new
		
		NSMutableDictionary *bondPointerTranslator = [ [ NSMutableDictionary alloc ] initWithCapacity:nBonds ] ;
		
		for( j = 0 ; j < nBonds ; ++j )
			{
				[ bondPointerTranslator setObject:bonds[j] 
					forKey:[ NSData  dataWithBytes:&(originalBonds[j]) length:sizeof(ctBond *)  ] ] ;
			}
			
		// Need to repair bond references in node objects
		
		for( j = 0 ; j < nNodes ; ++j )
			{
				for( k = 0 ; k < nodes[j]->nBonds ; ++k )
					{
						ctBond *newBondPtr = [ bondPointerTranslator 
							objectForKey:[ NSData  dataWithBytes:&(nodes[j]->bonds[k]) length:sizeof(ctBond *)  ] ] ;
							
						nodes[j]->bonds[k] = newBondPtr ;
					}
			}
		
		

		fragment **originalTreeFragmentPtrs = (fragment **) malloc( nFragments * sizeof( fragment *) ) ;
		
		theData = [ pListDict objectForKey:@"originalTreeFragmentPtrs" ] ;
		[ theData getBytes:originalTreeFragmentPtrs length:( nFragments * sizeof( fragment *) ) ] ;
				
		// Init tree fragments
		
		NSMutableArray *treeFragmentsAsPLists = [ pListDict objectForKey:@"treeFragmentsAsPLists" ] ;
		
		treeFragments = [ [ NSMutableArray alloc ] initWithCapacity:nFragments ] ;
		
		for( j = 0 ; j < nFragments ; ++j )
			{
				fragment *theFragment = [ [ fragment alloc ] initWithPropertyListDict:[ treeFragmentsAsPLists objectAtIndex:j ]
					andNodeTranslator:nodePointerTranslator
					andBondTranslator:bondPointerTranslator ] ;
					
				[ treeFragments addObject:theFragment ] ;
			
				[ theFragment release ] ;
			
				theFragment->sourceTree = self ;
			}
		
		treeName = [ [ NSString alloc ] initWithString:[ pListDict objectForKey:@"treeName" ] ] ;
		
		free( originalTreeFragmentPtrs ) ;
		free( originalNodes ) ;
		free( originalBonds ) ;
		
		[ nodePointerTranslator release ] ;
		[ bondPointerTranslator release ] ;
		
		return self ;
	}
		
	
	
- (void) encodeWithCoder:( NSCoder *)coder
	{
		[ coder encodeValueOfObjCType:@encode(int) at:&nNodes ] ;
		
		// I don't think there is a way around this
		NSArray *nodeArray = [ NSArray arrayWithObjects:nodes count:nNodes ] ;
		[ coder encodeObject:nodeArray ] ;
		
		[ coder encodeValueOfObjCType:@encode(int) at:&nBonds ] ;
		
		NSArray *bondArray = [ NSArray arrayWithObjects:bonds count:nBonds ] ;
		[ coder encodeObject:bondArray ] ;
		
		// I will skip encoding maximalTreePaths
		
		[ coder encodeValueOfObjCType:@encode(int) at:&nFragments ] ;
		
		// I will encoding ring closure information (should not be needed downstream)
		// We should always have tree fragments, so I will not worry about a nil value
		
		[ coder encodeObject:treeFragments ] ;
					
		[ coder encodeObject:treeName ] ;
		
		return ;
		
	}
	
- (id) initWithCoder:(NSCoder *)coder 
	{
		self = [ super init ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&nNodes ] ;
		
		nNodeAlloc = nNodes ;
		
		nodes = (ctNode **) malloc( nNodes * sizeof( ctNode *) ) ;
		
		NSArray *nodeArray = [ coder decodeObject ] ; // Static analyzer (remove retain)
		
		NSRange rng = NSMakeRange(0, nNodes ) ;
		
		[ nodeArray getObjects:nodes range:rng ] ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&nBonds ] ;
		
		nBondAlloc = nBonds ;
		
		bonds = (ctBond **) malloc( nBonds * sizeof( ctBond *) ) ;
		
		NSArray *bondArray = [ coder decodeObject ]  ;  // Static analyzer (remove retain)
		
		rng = NSMakeRange(0, nBonds ) ;
		
		[ bondArray getObjects:bonds range:rng ] ;
		
		maximalTreePaths = nil ;
		
		[ coder decodeValueOfObjCType:@encode(int) at:&nFragments ] ;
		
		treeFragments = [ [ coder decodeObject ] retain ] ;
			
		treeName = [ [ coder decodeObject ] retain ] ;
		
		[ self makeFragmentConnections ] ;
		
		return self ;
	}
		
- (void) exportAsMOL2File:(NSString *)f 
	{
		// Pull everything out of the tree structure. I could save fragment data as sets ...
	
		FILE *outFile = fopen([ f cString ], "w" ) ;
	
		if( ! outFile ) {
			printf( "COULD NOT OPEN MOL2 OUTPUT FILE - Export failed!\n" ) ;
			return ;
		}
	
		fprintf( outFile, "@<TRIPOS>MOLECULE\n" ) ;
		fprintf( outFile, "%s\n", [ treeName cString ] ) ;
		fprintf( outFile, "%5d%5d%5d%5d%5d\n", nNodes, nBonds, 0, 0, nFragments  ) ;
		fprintf( outFile, "SMALL\n" ) ;
		fprintf( outFile, "USER_CHARGES\n" ) ;
		fprintf( outFile, "@<TRIPOS>ATOM\n" ) ;
		
		int jNode, jBond ;
	
		for( jNode = 0 ; jNode < nNodes ; ++jNode ) {
			fprintf( outFile, "%7d %-8s%10.4f%10.4f%10.4f %-4s      1 <0>       %7.4f\n",
				   (jNode + 1), [ [ nodes[jNode]->properties objectForKey:@"atomName" ] cString ],
					nodes[jNode]->coord[0], nodes[jNode]->coord[1], nodes[jNode]->coord[2],
					[ [ nodes[jNode]->properties objectForKey:@"importType" ] cString ],
					nodes[jNode]->charge ) ;
					
		}
	
		fprintf( outFile, "@<TRIPOS>BOND\n" ) ;
	
		for( jBond = 0 ; jBond < nBonds ; ++jBond ) {
			fprintf( outFile, "%6d%5d%5d", (jBond + 1), bonds[jBond]->node1->index,  bonds[jBond]->node2->index ) ;
			
			switch( bonds[jBond]->type ) {
				case SINGLE :
					fprintf( outFile, " 1\n" ) ;
					break ;
				case DOUBLE :
					fprintf( outFile, " 2\n" ) ;
					break ;
				case TRIPLE :
					fprintf( outFile, " 3\n" ) ;
					break ;
				case AROMATIC :
					fprintf( outFile, " ar\n" ) ;
					break ;
				case AMIDE :
					fprintf( outFile, " am\n" ) ;
					break ;
				default :
					fprintf( outFile, " un\n" ) ;
			}
		}
	
		for( fragment *nextFrag in treeFragments ) {
			fprintf( outFile, "@<TRIPOS>SET\nSTATIC fragment%d ATOMS\n", nextFrag->index ) ;
			fprintf( outFile, "%d", [ nextFrag->fragmentNodes count ] ) ;
			
			int count = 0 ;
			
			// Max of 20 atoms per line
			
			for( ctNode *nextNode in nextFrag->fragmentNodes ) {
				fprintf( outFile, " %d", nextNode->index ) ;
				++count ;
				
				if( count % 20 == 0 ) {
					fprintf( outFile, "\n") ;
				}
			}
			
			fprintf( outFile, "\n" ) ;
			
		}
	
		
		fclose(outFile) ;
	
		
	}
		

@end
