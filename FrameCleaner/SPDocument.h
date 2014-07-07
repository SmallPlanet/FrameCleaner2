//
//  SPDocument.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SPDocument : NSDocument

@property (nonatomic, retain) NSString *directoryPath;
//@property

@property (nonatomic, retain) NSMutableArray *allFiles;


@end
